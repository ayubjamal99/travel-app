`CURRENT.md` is where the work stands. The PM rewrites it at every ticket transition and when it
pauses or stops. The SessionStart hook loads it into every new or resumed session, so a killed
session picks up exactly where it left off.

It is gitignored on purpose: it changes constantly and must not ride along on feature branches.
GitHub (issues, PRs, labels, board) stays the source of truth; this file is the PM's short-term memory.
