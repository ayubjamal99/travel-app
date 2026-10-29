# Setting up the agent loop

Everything in this repo is already written: devcontainer, guardrails, CI, board bootstrap, the five
agents, skills, hooks, `agentctl` and the watchdog. What's left are the steps only you can do
(accounts, logins, approvals). Plan on about 1–2 hours, most of it waiting for the container build.

## 0. Prerequisites (you, ~30 min)

- **Docker Desktop** running, **VS Code** with the **Dev Containers** extension.
- **An empty GitHub repo** for the travel planner.
  Make it **public**, or have GitHub Pro/Team: free private repos can't use branch protection,
  and protection is the server-side backstop for "agents never push to main".
- **Slack**: create a free workspace and an `#agents` channel → https://api.slack.com/apps →
  *Create New App* → *From scratch* → *Incoming Webhooks* → On → *Add New Webhook to Workspace* →
  pick `#agents` → copy the URL (`https://hooks.slack.com/services/...`).
- Your **Claude Pro** login.

## 1. Put the files in your repo and open the container (~10 min, mostly waiting)

```bash
git clone https://github.com/<you>/<repo>.git && cd <repo>
unzip ~/Downloads/travel-planner-agent-env.zip -d .     # the files from this package
code .
```
VS Code → **Reopen in Container**. `post-create.sh` installs Java 21, Maven, Node 22, Angular CLI,
gh, Docker-in-Docker, Claude Code, tmux, jq, gitleaks and Playwright deps, and wires the git hook.

## 2. One-time logins (inside the container terminal)

```bash
claude                      # log in with Claude Pro. Accept "trust this folder".
                            # Then /config → turn ON "Continue automatically at usage limit". Exit (Ctrl-D twice).
gh auth login               # GitHub.com, HTTPS, browser
gh auth refresh -s project  # boards need the project scope
nano .env                   # paste SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
scripts/notify.sh info "hello from the devcontainer"    # should appear in #agents
```
Logins live on Docker volumes, so they survive container rebuilds.

## 3. First commit, board, branch protection (~15 min)

The pre-commit hook refuses commits on `main`; the two setup commits below use the one-off override.

```bash
git add -A
ALLOW_MAIN_COMMIT=1 git commit -m "chore: agent loop environment"
git push -u origin main

scripts/bootstrap-github.sh --test     # labels, board with 6 columns, test issue moved around
git add ops/board.json && ALLOW_MAIN_COMMIT=1 git commit -m "chore: board config" && git push

scripts/protect-main.sh                # PR required, CI must pass, no direct/force push
```
Open the board URL it printed and switch the view layout to **Board** (the API can't set layouts).

**Check protection works:**
```bash
ALLOW_MAIN_COMMIT=1 git commit --allow-empty -m "should be rejected" && git push   # → rejected
git reset --hard origin/main
```

## 4. Check everything

```bash
agentctl doctor
```
All ✓ means the environment is done. (Branch protection shows ✗ on a free private repo; everything
else still works.)

## 5. Talk the product through with the BA (this is where you start)

```bash
agentctl ba
```
This is an interactive session with the BA, not the loop. It interviews you, writes
`docs/product/` (vision, strategy, roadmap, decisions), and when you say the roadmap is ready it opens a
`docs/roadmap` PR plus a `[Roadmap] v1` issue. **Gate 1:** add `approved` to that issue and merge the PR.
You can also ask it to write the MVP stories right there; each lands in Backlog.

## 6. Dry run the loop (Phase 6, 1–2 hours, recommended before real stories)

```bash
scripts/dry-run-seed.sh        # creates "[Story] Health endpoint + hello page (dry run)"
```
Add `approved` to that issue on GitHub (**gate 2**), keep `HELLO_GREETING` **unset** in `.env`, then:
```bash
agentctl start
agentctl attach                # first time only: accept any one-time prompt, then Ctrl-b d to detach
```
Exercise each case and confirm Slack gets the message:

| Test | How | Expect in Slack |
|---|---|---|
| Credential request | happens by itself: AC3 requires `HELLO_GREETING` | "set HELLO_GREETING in .env". Add it to `.env`, reply on the issue (any comment) |
| Pause mid-dev | `agentctl pause` while Dev is coding | "paused". `agentctl status` shows the handoff; `agentctl resume` continues |
| Stop, then start | `agentctl stop`, then `agentctl start` | fresh PM picks up from `ops/handoff/CURRENT.md` |
| QA → Dev loop | after Dev opens the PR, add to the issue: `AC6 — GET /api/v1/hello?name=Ali returns "<greeting>, Ali"` | QA FAIL, back to Dev, then PASS |
| Approval via label | already done (gate 2) | — |
| Merge gate | BA accepts → "PR #x ready to merge" | you merge → ticket moves to Done |

## 7. Real kickoff

`agentctl start`. The PM drives: roadmap gate → MVP stories (you approve each) → one ticket at a
time through UX → Dev → QA → BA → your merge. You get Slack pings only when it needs you.

---

## Daily use

| Command | What it does |
|---|---|
| `agentctl start` | start (or resume a paused) loop in tmux; `--resume` continues the last PM conversation |
| `agentctl pause` / `resume` | every agent halts at its next action; PM writes the handoff |
| `agentctl stop [--now]` | halt, let the PM write the handoff, end the session |
| `agentctl status` | state, who's working, current ticket, what it's waiting on, recent Slack |
| `agentctl attach` | watch the PM live (Ctrl-b d to detach without stopping it) |
| `agentctl nudge "…"` | type a message to the PM, e.g. answer a question |
| `agentctl ba` | talk to the BA directly (pause the loop first) |
| `agentctl logs` | watchdog, Slack and API-error logs |

**Your gates, all on GitHub:** add `approved` to the roadmap issue and to each story; merge PRs.
**Answering a question:** reply on the issue (any comment without 🤖); the watchdog wakes the PM.
**Credentials:** put them in `.env` only (never in GitHub or Slack), then reply on the issue.

## How the pieces fit

- **The PM** (`claude --agent pm`) runs in tmux so it survives closing the terminal and gets Claude
  Code's built-in auto-continue at the usage-limit reset (headless `-p` doesn't).
- **The watchdog** (second tmux window, no tokens) polls GitHub every 2 min for *human* actions only
  (approved label, merged PR, comment without 🤖) and types a nudge into the PM when it's idle. Waiting
  for you costs nothing. It also presses Enter on "limit reset" prompts and restarts a crashed PM.
- **Pause/stop** works through `ops/STATE` + the guard hook (PreToolUse, fires inside subagents too).
- **Handoff:** `ops/handoff/CURRENT.md`, loaded into every new session by the SessionStart hook.

**What enforces the rules (three layers):**
1. Branch protection on GitHub (no push to main, CI required).
2. Deny rules in `.claude/settings.json` (push to main, force push, `rm -rf`, reading `.env`, merging).
3. `scripts/hooks/guard.sh`: pause/stop, no self-approval, no merging, no `.env`, no `--no-verify`,
   no edits to guardrail files, and per-role write scopes (PM: `ops/` · BA: `docs/product/` ·
   UX: `docs/ux/` · QA: tests only · Dev: code).

## Limits to know about

- **Throughput on Pro:** roughly 1–3 tickets per 5-hour window; the weekly cap is the real ceiling.
  Moving to Max later needs no change here. Opus is not used anywhere (all agents are Sonnet).
- **Same GitHub identity:** agents use your `gh` token, so GitHub can't tell their actions from yours.
  The guard blocks the known ways of adding `approved` or merging, but it is pattern-based. For a hard
  boundary, give the container a fine-grained token without "Administration" and merge from your own browser.
- **Write scopes** are enforced on Claude's file tools. Shell commands are checked only for the
  guardrail paths, so they're best-effort for the role scopes.
- `onFailure: "block"` on the guard (fail closed if the hook breaks) needs Claude Code v2.1.295+;
  older versions ignore the field.
- Subagents run in the foreground, one at a time (`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`), and
  can't spawn their own subagents (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`).

## Troubleshooting

- **Nothing happens after `agentctl start`:** `agentctl attach`; a first-run prompt (bypass-permissions
  warning, trust dialog) may be waiting.
- **No Slack messages:** `scripts/notify.sh info test`; check `ops/.runtime/notify.log`.
- **PM idle but you approved something:** wait one poll (2 min), or `agentctl nudge "re-check the board"`.
- **Board move fails:** `gh auth refresh -s project`, then re-run `scripts/bootstrap-github.sh`.
- **Want to tweak an agent:** edit `.claude/agents/<role>.md` yourself (agents can't); changes apply on the next delegation.
