#!/usr/bin/env bash
# Stop / UserPromptSubmit / SubagentStart / SubagentStop bookkeeping for the loop session.
#  - ops/.runtime/pm-idle exists while the PM is waiting (the watchdog only nudges an idle PM)
#  - ops/.runtime/activity.log is what `agentctl status` shows
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
[ "${AGENTLOOP_LOOP:-}" = "1" ] || exit 0
RT="$ROOT/ops/.runtime"; mkdir -p "$RT"
input=$(cat)
ev=$(jq -r '.hook_event_name // ""' <<<"$input")
agent=$(jq -r '.agent_type // ""' <<<"$input")
ts=$(date '+%F %T')
case "$ev" in
  Stop)             date +%s > "$RT/pm-idle"; echo "$ts pm idle" >> "$RT/activity.log" ;;
  UserPromptSubmit) rm -f "$RT/pm-idle";      echo "$ts pm busy" >> "$RT/activity.log" ;;
  SubagentStart)    echo "$agent" > "$RT/current-agent"; echo "$ts -> $agent started" >> "$RT/activity.log" ;;
  SubagentStop)     rm -f "$RT/current-agent"; echo "$ts <- $agent finished" >> "$RT/activity.log" ;;
esac
# keep the log short
if [ -f "$RT/activity.log" ] && [ "$(wc -l < "$RT/activity.log")" -gt 500 ]; then
  tail -200 "$RT/activity.log" > "$RT/activity.log.tmp" && mv "$RT/activity.log.tmp" "$RT/activity.log"
fi
exit 0
