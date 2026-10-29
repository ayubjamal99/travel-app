#!/usr/bin/env bash
# Notification hook: forward "waiting for input / idle / usage-limit auto-resume" to Slack.
# Only for the loop session, and de-duplicated so an idle PM doesn't spam the channel.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
[ "${AGENTLOOP_LOOP:-}" = "1" ] || exit 0
input=$(cat)
type=$(jq -r '.notification_type // "unknown"' <<<"$input")
msg=$(jq -r '.message // ""' <<<"$input")
agent=$(jq -r '.agent_type // "pm"' <<<"$input")
state=$(tr -d '[:space:]' < "$ROOT/ops/STATE" 2>/dev/null || echo STOPPED)

RT="$ROOT/ops/.runtime"; mkdir -p "$RT"
dedupe() {  # $1 key, $2 seconds
  local f="$RT/notified-$1" now; now=$(date +%s)
  if [ -f "$f" ] && [ $((now - $(cat "$f"))) -lt "$2" ]; then exit 0; fi
  echo "$now" > "$f"
}

waiting_on() { grep -m1 -i '^\*\*waiting on' "$ROOT/ops/handoff/CURRENT.md" 2>/dev/null | sed 's/\*//g'; }

case "$type" in
  idle_prompt)
    [ "$state" = "RUNNING" ] || exit 0
    dedupe idle 7200
    "$ROOT/scripts/notify.sh" info "PM is idle. $(waiting_on)" ;;
  permission_prompt|agent_needs_input|elicitation_dialog)
    dedupe "input-$type" 900
    "$ROOT/scripts/notify.sh" action "$agent is waiting for terminal input ($type): $msg — run: agentctl attach" ;;
  quota_auto_resume_fired)
    "$ROOT/scripts/notify.sh" info "Usage limit reset; the loop resumed automatically." ;;
  quota_auto_resume_stale|quota_auto_resume_disabled)
    dedupe quota 1800
    "$ROOT/scripts/notify.sh" warn "Usage-limit auto-resume did not fire ($type). The watchdog will retry; or run: agentctl attach" ;;
esac
exit 0
