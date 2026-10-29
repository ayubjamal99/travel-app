#!/usr/bin/env bash
# PreToolUse guard. Runs before EVERY tool call, in the PM and inside every subagent.
#
#  1. Loop control: in loop sessions (AGENTLOOP_LOOP=1, set by agentctl), if ops/STATE is
#     PAUSED or STOPPED, every action is denied except writing the handoff and notifying.
#  2. Safety policy for the agent roles (pm, ba, ux, dev, qa): no pushes to main, no force
#     push, no merging, no self-approval, no .env access, no tampering with guardrails.
#  3. Role write scopes: PM writes only ops/, BA only docs/product/, UX only docs/ux/,
#     QA only tests. Dev may write code.
#
# Denies via JSON permissionDecision; exit 0 otherwise. Deny rules in .claude/settings.json
# and branch protection on GitHub are the other two layers.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
input=$(cat)

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { echo "guard: jq missing, failing closed" >&2; exit 2; }

tool=$(jq -r '.tool_name // ""' <<<"$input")
agent_type=$(jq -r '.agent_type // ""' <<<"$input")
agent_id=$(jq -r '.agent_id // ""' <<<"$input")
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // ""' <<<"$input")

rel="$path"
case "$path" in "$ROOT"/*) rel="${path#"$ROOT"/}" ;; esac

is_role=false
case "$agent_type" in pm|ba|ux|dev|qa) is_role=true ;; esac

# ------------------------------------------------------------------ 1. pause / stop
if [ "${AGENTLOOP_LOOP:-}" = "1" ]; then
  state=$(tr -d '[:space:]' < "$ROOT/ops/STATE" 2>/dev/null || echo STOPPED)
  if [ "$state" != "RUNNING" ]; then
    allowed=false
    case "$tool" in
      Read|Glob|Grep|TodoWrite) allowed=true ;;
      Write|Edit|MultiEdit) case "$rel" in ops/handoff/*) allowed=true ;; esac ;;
      Bash) [[ "$cmd" =~ ^[[:space:]]*(\./)?scripts/notify\.sh[[:space:]] ]] && allowed=true ;;
    esac
    if ! $allowed; then
      if [ -n "$agent_id" ]; then
        deny "LOOP $state by the human. Do not continue the task. Stop now and return to the PM a short summary: what you finished, what is half-done (files/branch), and the exact next step."
      else
        deny "LOOP $state by the human. Halt: update ops/handoff/CURRENT.md (Write/Edit there is allowed) with where the work stands and the exact next step, then end your turn. Do nothing else."
      fi
    fi
  fi
fi

$is_role || exit 0

# ------------------------------------------------------------------ 2. policy
PROTECTED_PATHS='ops/STATE|\.claude/settings[^/]*\.json|\.claude/agents/|scripts/hooks/|scripts/agentctl|scripts/watchdog\.sh|\.githooks/|\.github/workflows/|ops/board\.json'
PROTECTED="(^|/)(${PROTECTED_PATHS})"                     # for file-tool paths
PROTECTED_IN_CMD="(^|[^A-Za-z0-9_.-])(${PROTECTED_PATHS})"  # anywhere in a shell command
is_env_file() { local b; b=$(basename -- "$1"); [[ "$b" =~ ^\.env(\..+)?$ && "$b" != ".env.example" ]]; }

if [ "$tool" = "Bash" ]; then
  c="$cmd"
  if [[ "$c" =~ git[[:space:]].*push ]]; then
    [[ "$c" =~ (^|[[:space:]:])(refs/heads/)?(main|master)([[:space:]]|$|[\;\&\|\)]) ]] \
      && deny "Pushing to main is not allowed. Push your feature branch and open a PR; the human merges."
    [[ "$c" =~ (^|[[:space:]])(-f|--force|--force-with-lease)([[:space:]=]|$) || "$c" =~ [[:space:]]\+[A-Za-z] ]] \
      && deny "Force pushes are not allowed. Merge main into your branch instead of rebasing."
    cur=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
    [ "$cur" = "main" ] && deny "You are on main. Switch to the ticket branch (feat/<issue>-<slug>) before pushing."
  fi
  [[ "$c" =~ gh[[:space:]]+pr[[:space:]]+merge || "$c" =~ gh[[:space:]]+api.*pulls/[0-9]+/merge ]] \
    && deny "Merging is a human gate. Notify the human that the PR is ready instead."
  [[ "$c" =~ --add-label[=[:space:]]*[\"\']?[^[:space:]]*approved || "$c" =~ gh[[:space:]]+api.*labels.*approved ]] \
    && deny "The 'approved' label is human-only. Ask for approval via scripts/notify.sh action ..."
  [[ "$c" =~ gh[[:space:]]+label[[:space:]]+(delete|edit) ]] && deny "Editing or deleting labels is not allowed."
  [[ "$c" =~ gh[[:space:]]+repo[[:space:]]+(delete|edit|rename|archive) ]] && deny "Repository settings are human-only."
  [[ "$c" =~ (^|[^A-Za-z0-9_.-])\.env($|[^A-Za-z0-9_.-]) ]] \
    && deny ".env is off-limits to agents. Reference variables by name; if one is missing, ask the PM to request it from the human."
  [[ "$c" =~ --no-verify || "$c" =~ git[[:space:]]+commit.*[[:space:]]-n([[:space:]]|$) || "$c" =~ core\.hooksPath ]] \
    && deny "Skipping or changing git hooks is not allowed."
  [[ "$c" =~ (^|[\;\&\|[:space:]])(\./)?(scripts/)?agentctl([[:space:]]|$) ]] && deny "agentctl is for the human only."
  [[ "$c" =~ (^|[\;\&\|\(][[:space:]]*)claude([[:space:]]|$) ]] && deny "Agents may not launch Claude Code sessions."
  if [[ "$c" =~ $PROTECTED_IN_CMD ]] && [[ "$c" =~ (\>|tee[[:space:]]|sed[[:space:]]+-i|perl[[:space:]]+-[a-z]*i|(^|[[:space:]])(cp|mv|rm|chmod|truncate|install|ln)[[:space:]]) ]]; then
    deny "That path is a guardrail (state, settings, hooks, CI, agent definitions, board config). Only the human changes it."
  fi
  exit 0
fi

# File tools
if [ -n "$path" ]; then
  is_env_file "$path" && deny ".env files are off-limits to agents."
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit)
      [[ "$rel" =~ $PROTECTED ]] && deny "That path is a guardrail. Only the human changes it."
      case "$agent_type" in
        pm)  [[ "$rel" == ops/* ]] || deny "PM writes no code or docs. Only ops/ (handoff). Delegate this to the right agent." ;;
        ba)  [[ "$rel" == docs/product/* ]] || deny "BA is read-only on code. Write only under docs/product/ (stories go to GitHub issues)." ;;
        ux)  [[ "$rel" == docs/ux/* ]] || deny "UX writes only screen specs under docs/ux/." ;;
        qa)  [[ "$rel" == */src/test/* || "$rel" == *.spec.ts || "$rel" == *.e2e.ts || "$rel" == frontend/e2e/* \
                || "$rel" == */playwright.config.* || "$rel" == docs/qa/* ]] \
               || deny "QA writes only tests (src/test, *.spec.ts, frontend/e2e/, playwright config) and docs/qa/. Report product bugs to Dev instead of fixing them." ;;
      esac
      ;;
  esac
fi
exit 0
