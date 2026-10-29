#!/usr/bin/env bash
# One-time GitHub setup: labels, Projects board with the 6 columns, linked to this repo.
# Writes the IDs agents need to ops/board.json (commit that file).
#
#   scripts/bootstrap-github.sh            # labels + board
#   scripts/bootstrap-github.sh --test     # ...and create/move/close a test issue
#
# Needs: gh auth login, then `gh auth refresh -s project`.
set -euo pipefail
cd "$(dirname "$0")/.."

TITLE="${BOARD_TITLE:-Travel Planner}"
STAGES=("Backlog" "Ready" "In Progress" "QA" "BA Review" "Done")
COLORS=("GRAY" "BLUE" "YELLOW" "ORANGE" "PURPLE" "GREEN")
DESCS=("Written, not yet approved or not yet scheduled" "Approved, next up" "UX spec / Dev at work" "QA testing the PR" "BA checking acceptance criteria; then waiting for your merge" "Merged to main")

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "$1 not installed"; }
need gh; need jq

gh auth status >/dev/null 2>&1 || die "run: gh auth login"
gh auth status 2>&1 | grep -q "'project'" \
  || die "token lacks the project scope. Run: gh auth refresh -s project"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner) || die "no GitHub remote. git remote add origin <url> first"
OWNER=${REPO%%/*}
echo "repo:  $REPO"

# ---------------------------------------------------------------- labels
echo "== labels"
label() { gh label create "$1" --color "$2" --description "$3" --force >/dev/null && echo "  $1"; }
label story        "1D76DB" "User story"
label bug          "D73A4A" "Defect"
label roadmap      "5319E7" "Roadmap / product strategy (gate 1)"
label approved     "0E8A16" "HUMAN ONLY: gate passed. Agents never add this."
label needs-human  "B60205" "Waiting on a human decision, credential or answer"
label blocked      "000000" "Blocked by something outside the loop"
label "role:ba"    "C5DEF5" "Business analyst owns the next step"
label "role:ux"    "BFD4F2" "UX owns the next step"
label "role:dev"   "FBCA04" "Dev owns the next step"
label "role:qa"    "F9D0C4" "QA owns the next step"
label "qa-round:1" "FEF2C0" "QA failed once"
label "qa-round:2" "FAD8A0" "QA failed twice"
label "qa-round:3" "F5B041" "QA failed 3 times: loop breaker"
label dry-run      "EDEDED" "Phase 6 test ticket"

# ---------------------------------------------------------------- project
echo "== project board"
NUM=$(gh project list --owner "$OWNER" --format json --limit 100 \
  | jq -r --arg t "$TITLE" '.projects[] | select(.title==$t and (.closed|not)) | .number' | head -1)
if [ -z "$NUM" ]; then
  NUM=$(gh project create --owner "$OWNER" --title "$TITLE" --format json | jq -r .number)
  echo "  created project #$NUM"
else
  echo "  using existing project #$NUM"
fi
PROJECT_ID=$(gh project view "$NUM" --owner "$OWNER" --format json | jq -r .id)
PROJECT_URL=$(gh project view "$NUM" --owner "$OWNER" --format json | jq -r .url)
gh project link "$NUM" --owner "$OWNER" --repo "$REPO" >/dev/null 2>&1 || true

fields_json() { gh project field-list "$NUM" --owner "$OWNER" --format json --limit 50; }
STATUS_ID=$(fields_json | jq -r '.fields[] | select(.name=="Status") | .id')
[ -n "$STATUS_ID" ] || die "project has no Status field"

# Replace the Status options (Todo/In Progress/Done) with our six columns.
# GitHub keeps option IDs for options whose names match, so re-running is safe.
opts=$(for i in "${!STAGES[@]}"; do
  printf '{name:"%s",color:%s,description:"%s"}' "${STAGES[$i]}" "${COLORS[$i]}" "${DESCS[$i]}"
  [ "$i" -lt $((${#STAGES[@]}-1)) ] && printf ',' || true
done)
FIELD_NAME="Status"
if ! gh api graphql -f query="mutation { updateProjectV2Field(input:{fieldId:\"$STATUS_ID\", singleSelectOptions:[$opts]}) { projectV2Field { ... on ProjectV2SingleSelectField { id } } } }" >/dev/null 2>&1; then
  echo "  could not edit Status options via API; creating a 'Stage' field instead"
  FIELD_NAME="Stage"
  if ! fields_json | jq -e '.fields[] | select(.name=="Stage")' >/dev/null; then
    gh project field-create "$NUM" --owner "$OWNER" --name Stage --data-type SINGLE_SELECT \
      --single-select-options "$(IFS=,; echo "${STAGES[*]}")" >/dev/null
  fi
fi

FIELD=$(fields_json | jq --arg n "$FIELD_NAME" '.fields[] | select(.name==$n)')
FIELD_ID=$(jq -r .id <<<"$FIELD")
OPTIONS=$(jq '[.options[] | {key:.name, value:.id}] | from_entries' <<<"$FIELD")
for c in "${STAGES[@]}"; do
  jq -e --arg c "$c" 'has($c)' <<<"$OPTIONS" >/dev/null || die "column '$c' missing on field $FIELD_NAME"
done

jq -n --arg repo "$REPO" --arg owner "$OWNER" --argjson number "$NUM" --arg projectId "$PROJECT_ID" \
  --arg url "$PROJECT_URL" --arg fieldName "$FIELD_NAME" --arg fieldId "$FIELD_ID" --argjson options "$OPTIONS" \
  '{repo:$repo, owner:$owner, number:$number, projectId:$projectId, url:$url, fieldName:$fieldName, fieldId:$fieldId, options:$options}' \
  > ops/board.json
echo "  wrote ops/board.json  ($PROJECT_URL)"
echo "  NOTE: open the project once and set the default view to 'Board' grouped by $FIELD_NAME (the API can't set layouts)."

# ---------------------------------------------------------------- optional test
if [ "${1:-}" = "--test" ]; then
  echo "== test issue"
  url=$(gh issue create --title "[Bootstrap] board test" --label dry-run \
        --body "🤖 **bootstrap**: created by scripts/bootstrap-github.sh --test. Safe to ignore." )
  n=${url##*/}
  scripts/board.sh add "$n"
  scripts/board.sh move "$n" "Ready"
  scripts/board.sh list | grep -q "#$n" && echo "  issue #$n is on the board in Ready"
  gh issue close "$n" --reason "not planned" >/dev/null
  scripts/board.sh move "$n" "Done"
  echo "  closed #$n and moved to Done. Board works."
fi
echo "done."
