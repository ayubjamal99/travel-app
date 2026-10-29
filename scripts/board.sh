#!/usr/bin/env bash
# Small wrapper so agents move tickets with one cheap command instead of raw GraphQL.
#
#   scripts/board.sh add  <issue#>               add issue to the board (column: Backlog)
#   scripts/board.sh move <issue#> "<Column>"    Backlog | Ready | In Progress | QA | BA Review | Done
#   scripts/board.sh list [Column]               "#12  In Progress  [Story] Search flights"
#   scripts/board.sh where <issue#>              print the issue's column
set -euo pipefail
cd "$(dirname "$0")/.."
CFG=ops/board.json
[ -f "$CFG" ] || { echo "ops/board.json missing: run scripts/bootstrap-github.sh" >&2; exit 1; }

OWNER=$(jq -r .owner "$CFG"); NUM=$(jq -r .number "$CFG"); REPO=$(jq -r .repo "$CFG")
PID=$(jq -r .projectId "$CFG"); FID=$(jq -r .fieldId "$CFG"); FNAME=$(jq -r .fieldName "$CFG")
FKEY=$(tr '[:upper:]' '[:lower:]' <<<"$FNAME")   # gh item-list exposes fields by lowercased name

items() { gh project item-list "$NUM" --owner "$OWNER" --format json --limit 500; }

item_id() {  # issue number -> project item id (empty if not on board)
  items | jq -r --argjson n "$1" --arg r "$REPO" \
    '.items[] | select(.content.number==$n and ((.content.repository // $r)==$r)) | .id' | head -1
}

opt_id() {
  local id; id=$(jq -r --arg c "$1" '.options[$c] // empty' "$CFG")
  [ -n "$id" ] || { echo "unknown column '$1'. Use: $(jq -r '.options|keys_unsorted|join(", ")' "$CFG")" >&2; exit 1; }
  echo "$id"
}

set_col() {
  local o; o=$(opt_id "$2") || exit 1
  gh project item-edit --id "$1" --project-id "$PID" --field-id "$FID" --single-select-option-id "$o" >/dev/null
}

cmd=${1:-}; shift || true
case "$cmd" in
  add)
    n=${1:?issue number}
    id=$(item_id "$n")
    if [ -z "$id" ]; then
      id=$(gh project item-add "$NUM" --owner "$OWNER" --url "https://github.com/$REPO/issues/$n" --format json | jq -r .id)
      set_col "$id" "Backlog"
    fi
    echo "#$n on board"
    ;;
  move)
    n=${1:?issue number}; col=${2:?column}
    opt_id "$col" >/dev/null || exit 1
    id=$(item_id "$n")
    [ -n "$id" ] || { "$0" add "$n" >/dev/null; id=$(item_id "$n"); }
    set_col "$id" "$col"
    echo "#$n -> $col"
    ;;
  list)
    filter=${1:-}
    items | jq -r --arg k "$FKEY" --arg f "$filter" \
      '.items[] | select(.content.number != null) | select($f=="" or .[$k]==$f)
       | "#\(.content.number)\t\(.[$k] // "-")\t\(.content.title)"' | sort -t'#' -k2 -n
    ;;
  where)
    n=${1:?issue number}
    items | jq -r --argjson n "$n" --arg k "$FKEY" '.items[] | select(.content.number==$n) | .[$k] // "-"' | head -1
    ;;
  *)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
