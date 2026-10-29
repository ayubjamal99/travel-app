#!/usr/bin/env bash
# Runs next to the PM in the tmux session (window "watchdog"). Costs no Claude tokens.
#
# Every AGENTLOOP_POLL_SECONDS while STATE=RUNNING it:
#   1. Watches GitHub for HUMAN actions: a new `approved` label, a merged PR, or a new
#      comment/review that does not start with the agents' "🤖" marker. If the PM is idle,
#      it types a nudge into the PM's terminal so the loop continues. Agent activity never
#      triggers a nudge, so an idle PM costs nothing.
#   2. Unsticks usage-limit waits ("press enter to continue", "Automatic continue stopped").
#   3. Restarts the PM if its process died (max 3 times per hour), resuming from the handoff.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
SESSION=${AGENTLOOP_SESSION:-agentloop}
RT=ops/.runtime; mkdir -p "$RT"
LOG="$RT/watchdog.log"
envval() { [ -f .env ] && grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }
POLL=${AGENTLOOP_POLL_SECONDS:-$(envval AGENTLOOP_POLL_SECONDS)}; POLL=${POLL:-120}

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
state() { tr -d '[:space:]' < ops/STATE 2>/dev/null || echo STOPPED; }
pm_target="$SESSION:pm"
send() { tmux send-keys -t "$pm_target" -l "$1"; sleep 0.5; tmux send-keys -t "$pm_target" Enter; }
throttle() {  # $1 key $2 seconds -> returns 0 if allowed now
  local f="$RT/wd-$1" now; now=$(date +%s)
  if [ -f "$f" ] && [ $((now - $(cat "$f"))) -lt "$2" ]; then return 1; fi
  echo "$now" > "$f"; return 0
}

snapshot() {  # JSON of human-originated signals only
  local approved merged issues prs
  approved=$(gh issue list --state all --label approved --limit 300 --json number 2>/dev/null) || return 1
  merged=$(gh pr list --state merged --limit 30 --json number 2>/dev/null) || return 1
  issues=$(gh issue list --state open --limit 100 --json number,comments 2>/dev/null) || return 1
  prs=$(gh pr list --state open --limit 50 --json number,comments,reviews 2>/dev/null) || return 1
  jq -n --argjson a "$approved" --argjson m "$merged" --argjson i "$issues" --argjson p "$prs" '
    def human(xs): [xs[]? | select(((.body // "") | startswith("🤖")) | not)] | length;
    { approved: ([$a[].number] | sort),
      merged:   ([$m[].number] | sort),
      talk:     ( ([$i[] | {key: ("#"+(.number|tostring)), value: human(.comments)}])
                + ([$p[] | {key: ("PR#"+(.number|tostring)), value: (human(.comments) + human(.reviews))}])
                | from_entries ) }'
}

diff_summary() {  # $1 old json, $2 new json
  jq -rn --argjson o "$1" --argjson n "$2" '
    [ ( ($n.approved - $o.approved) | if length>0 then "approved: " + (map("#"+tostring)|join(", ")) else empty end ),
      ( ($n.merged   - $o.merged)   | if length>0 then "merged PR: " + (map("#"+tostring)|join(", ")) else empty end ),
      ( [ $n.talk | to_entries[] | select(.value > ($o.talk[.key] // 0)) | .key ]
        | if length>0 then "new human comment on: " + join(", ") else empty end ) ] | join("; ")'
}

log "watchdog started (poll ${POLL}s, session $SESSION)"
prev=""
restarts=()

while tmux has-session -t "$SESSION" 2>/dev/null; do
  st=$(state)

  if [ "$st" = "RUNNING" ]; then
    # --- 3. PM process died?
    dead=$(tmux display-message -p -t "$pm_target" '#{pane_dead}' 2>/dev/null || echo 1)
    if [ "$dead" = "1" ]; then
      now=$(date +%s); recent=()
      for t in "${restarts[@]:-}"; do [ -n "$t" ] && [ $((now - t)) -lt 3600 ] && recent+=("$t"); done
      restarts=("${recent[@]:-}")
      if [ "${#recent[@]}" -lt 3 ]; then
        log "PM process exited; respawning"
        scripts/notify.sh warn "PM process exited; restarting it from the handoff file."
        tmux respawn-pane -k -t "$pm_target"
        restarts+=("$now")
      elif throttle respawn-giveup 3600; then
        log "PM keeps dying; giving up"
        scripts/notify.sh action "PM crashed 3 times within an hour. Loop needs you: agentctl attach / agentctl status"
      fi
      sleep "$POLL"; continue
    fi

    # --- 2. usage-limit prompts
    pane=$(tmux capture-pane -p -t "$pm_target" 2>/dev/null | tail -30)
    if grep -qi 'press enter to continue' <<<"$pane" && throttle enter 300; then
      log "limit reset prompt seen; pressing Enter"; tmux send-keys -t "$pm_target" Enter
    elif grep -qi 'automatic continue stopped' <<<"$pane" && throttle autostop 1800; then
      log "auto-continue gave up; sending 'continue'"
      send "continue"
      scripts/notify.sh info "Auto-continue stopped after repeated limit hits; watchdog nudged the PM to continue."
    fi

    # --- 1. human actions on GitHub
    if snap=$(snapshot); then
      if [ -z "$prev" ] && [ -f "$RT/watch.json" ]; then prev=$(cat "$RT/watch.json"); fi
      if [ -n "$prev" ]; then
        changes=$(diff_summary "$prev" "$snap")
        [ -n "$changes" ] && { echo "$changes" >> "$RT/pending-nudge"; log "human change: $changes"; }
      fi
      prev="$snap"; echo "$snap" > "$RT/watch.json"
    fi
    if [ -s "$RT/pending-nudge" ] && [ -f "$RT/pm-idle" ]; then
      what=$(paste -sd ';' "$RT/pending-nudge")
      log "nudging PM: $what"
      send "[watchdog] Human action on GitHub: ${what}. Re-check the board and continue the loop."
      rm -f "$RT/pending-nudge" "$RT/pm-idle"
    fi
  fi
  sleep "$POLL"
done
log "tmux session gone; watchdog exiting"
