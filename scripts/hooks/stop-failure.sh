#!/usr/bin/env bash
# StopFailure: a turn ended on an API error. On Pro this is usually the 5-hour or weekly limit.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
input=$(cat)
etype=$(jq -r '.error_type // "unknown"' <<<"$input")
emsg=$(jq -r '.error_message // .error // ""' <<<"$input" | head -c 300)
echo "$(date '+%F %T') $etype $emsg" >> "$ROOT/ops/.runtime/errors.log" 2>/dev/null
[ "${AGENTLOOP_LOOP:-}" = "1" ] || exit 0
case "$etype" in
  rate_limit)
    "$ROOT/scripts/notify.sh" warn "Hit the usage limit. Resuming automatically at the reset. ($emsg)" ;;
  authentication_failed|oauth_org_not_allowed|billing_error|account_on_hold)
    "$ROOT/scripts/notify.sh" action "Claude login/billing problem ($etype): $emsg — run: agentctl attach, then /login" ;;
  *)
    "$ROOT/scripts/notify.sh" warn "Turn ended on API error $etype: $emsg" ;;
esac
exit 0
