#!/usr/bin/env bash
# Branch protection on main: PR required, CI (backend, frontend, secret-scan) must pass,
# no direct or force pushes, applies to admins too (agents push with your token).
#
# Note: GitHub only allows branch protection on PUBLIC repos for free accounts.
# On a free PRIVATE repo this returns 403; the loop then relies on the local deny rules,
# the guard hook and the pre-commit hook (all still active), and you lose the server-side backstop.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

git ls-remote --exit-code --heads origin main >/dev/null 2>&1 \
  || { echo "origin has no main branch yet. Push the initial commit first (see SETUP.md)." >&2; exit 1; }

cat > /tmp/protection.json <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["backend", "frontend", "secret-scan"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0, "dismiss_stale_reviews": false },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": false
}
JSON

if gh api -X PUT "repos/$REPO/branches/main/protection" --input /tmp/protection.json >/dev/null; then
  echo "main is protected on $REPO"
else
  echo "Branch protection failed (free private repo?). See the note at the top of this script." >&2
  exit 1
fi
rm -f /tmp/protection.json
