#!/usr/bin/env bash
# Post to Slack (#agents) through the incoming webhook in .env.
#
#   scripts/notify.sh <level> "<message>" [link]
#   level: info | action | warn | done
#     action = you need to do something (approve, merge, give a credential, decide)
#
# Never fails the caller: if Slack is unreachable or not configured, the message
# is still written to ops/.runtime/notify.log.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/ops/.runtime"

level=${1:-info}; msg=${2:-}; link=${3:-}
[ -n "$msg" ] || { echo "usage: notify.sh <info|action|warn|done> \"message\" [link]" >&2; exit 0; }

# Read only the two keys we need; never source the whole .env.
envval() { [ -f "$ROOT/.env" ] && grep -E "^$1=" "$ROOT/.env" | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }
WEBHOOK="${SLACK_WEBHOOK_URL:-$(envval SLACK_WEBHOOK_URL)}"
NAME="${AGENTLOOP_NAME:-$(envval AGENTLOOP_NAME)}"; NAME=${NAME:-agent-loop}

case "$level" in
  action) icon=":raising_hand:"; tag="*ACTION NEEDED*" ;;
  warn)   icon=":warning:";      tag="*warning*" ;;
  done)   icon=":white_check_mark:"; tag="*done*" ;;
  *)      icon=":robot_face:";   tag="info" ;;
esac

text="$icon [$NAME] $tag — $msg"
[ -n "$link" ] && text="$text
<$link>"

printf '%s\t%s\t%s\n' "$(date '+%F %T %Z')" "$level" "$msg${link:+ $link}" >> "$ROOT/ops/.runtime/notify.log"

if [ -z "$WEBHOOK" ]; then
  echo "notify: SLACK_WEBHOOK_URL not set; logged only" >&2
  exit 0
fi

payload=$(jq -n --arg t "$text" '{text:$t}')
if curl -fsS -m 10 -X POST -H 'Content-type: application/json' --data "$payload" "$WEBHOOK" >/dev/null 2>&1; then
  echo "notified ($level)"
else
  echo "notify: Slack post failed; logged to ops/.runtime/notify.log" >&2
fi
exit 0
