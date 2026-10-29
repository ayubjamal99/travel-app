#!/usr/bin/env bash
# Phase 6: creates the fake "health endpoint + hello page" story on the board.
# It is designed to exercise the credential path: the greeting must come from HELLO_GREETING,
# which you deliberately leave unset in .env until the PM asks for it on Slack.
set -euo pipefail
cd "$(dirname "$0")/.."
body=$(mktemp)
cat > "$body" <<'MD'
### Story
As a developer of the travel planner, I want a health endpoint and a hello page, so that we know the
whole stack (backend, frontend, CI, the agent loop) works end to end.

### Context
Dry run of the agent loop (Phase 6). Also serves as the walking skeleton. Priority: P1. Depends on: none.
The greeting text is configuration: it must be read from the environment variable `HELLO_GREETING`
(provided by the human in `.env`). The app must refuse to start if it is missing.

### Acceptance criteria
AC1 — Given the backend is running, when I call `GET /api/v1/health`, then I get `200` with JSON `{"status":"UP"}`.
AC2 — Given `HELLO_GREETING` is set, when I call `GET /api/v1/hello`, then I get `200` with JSON `{"message": <value of HELLO_GREETING>}`.
AC3 — Given `HELLO_GREETING` is not set, when the backend starts, then startup fails with a clear message naming the variable.
AC4 — Given the frontend is running, when I open `/`, then I see the greeting from AC2 in an element with `data-testid="hello-message"`.
AC5 — Given the backend is down, when I open `/`, then I see an error state with `data-testid="hello-error"` and a Retry button.

### Has UI?
Yes

### Out of scope
- Styling beyond the design-language tokens
- Authentication

### Size
M
MD
url=$(gh issue create --title "[Story] Health endpoint + hello page (dry run)" --label story --label dry-run --body-file "$body")
rm -f "$body"
n=${url##*/}
scripts/board.sh add "$n"
echo "created #$n: $url"
echo "Now add the 'approved' label to #$n on GitHub. Leave HELLO_GREETING unset until the PM asks."
