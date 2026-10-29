#!/usr/bin/env bash
# SessionStart: whatever prints here is added to the new/resumed session's context.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 0
input=$(cat || true)
source=$(jq -r '.source // "startup"' <<<"$input" 2>/dev/null || echo startup)

state=$(tr -d '[:space:]' < ops/STATE 2>/dev/null || echo STOPPED)
branch=$(git branch --show-current 2>/dev/null || echo "?")
dirty=$(git status --porcelain 2>/dev/null | head -20)

echo "## Agent loop context (session ${source}, $(date '+%F %H:%M %Z'))"
echo "- Loop STATE: ${state}$( [ "${AGENTLOOP_LOOP:-}" = 1 ] && echo ' (this is the loop session)' || echo ' (interactive session, not the loop)')"
echo "- Git branch: ${branch}"
if [ -n "$dirty" ]; then echo "- Uncommitted changes:"; sed 's/^/    /' <<<"$dirty"; fi
[ -f ops/board.json ] && echo "- Board: $(jq -r .url ops/board.json) (use scripts/board.sh)"
echo
if [ -s ops/handoff/CURRENT.md ]; then
  echo "## Handoff (ops/handoff/CURRENT.md)"
  cat ops/handoff/CURRENT.md
else
  echo "## Handoff: none yet (fresh project)."
fi
exit 0
