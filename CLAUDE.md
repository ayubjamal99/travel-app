# AI Travel Planner — team conventions

Loaded by every agent (PM, BA, UX, Dev, QA) and by any interactive Claude session in this repo.

## Product
An AI travel planner. Vision, strategy and roadmap live in `docs/product/` (owned by the BA,
approved by the human). Screen specs live in `docs/ux/` (owned by UX). If something here
contradicts `docs/product/`, the product docs win for *what*, this file wins for *how*.

## Stack and layout
- `backend/` — Spring Boot (latest stable 3.x/4.x line chosen at scaffold time), **Java 21**, Maven,
  REST under `/api/**`, PostgreSQL by default (Testcontainers in tests) unless
  `docs/product/architecture-notes.md` says otherwise.
- `frontend/` — Angular (latest stable), standalone components, signals, strict TypeScript.
  Dev server proxies `/api` to `localhost:8080`.
- `docs/product/` BA · `docs/ux/` UX · `docs/qa/` QA notes
- `ops/` loop control — STATE and handoff. Not product code; don't touch STATE or board.json.
- `scripts/` loop tooling — `board.sh` and `notify.sh` are for agents; `agentctl` is human-only.

Required npm scripts in `frontend/package.json` (CI calls them): `build`, `test:ci` (unit tests,
headless, single run), `e2e:ci` (Playwright, starts the app itself via `webServer`).

## Workflow
- One GitHub issue per story/bug. The board columns: Backlog → Ready → In Progress → QA → BA Review → Done.
- Move tickets only with `scripts/board.sh move <n> "<Column>"` (normally the PM does this).
- **Branches:** `feat/<issue>-<short-slug>`, `fix/<issue>-<short-slug>`, `docs/<slug>`. Never commit to main.
- **Commits:** Conventional Commits with the issue: `feat(trips): add itinerary endpoint (#12)`.
- **PRs:** base `main`, body has `Closes #<n>` and one line per acceptance criterion. Only the human merges.
- Keep main green. Update your branch with `git merge origin/main`; never rebase a pushed branch, never force-push.
- **GitHub comments by agents start with `🤖 **<role>**:`** (pm, ba, ux, dev, qa). Humans' comments don't.
  The watchdog relies on this to tell human actions from agent actions.

## Gates (human-only)
1. Roadmap issue gets the `approved` label. 2. Each story gets `approved` before Dev starts.
3. The human merges the PR. Agents never add `approved`, never merge, never push to main.

## Credentials and config
Secrets live only in `.env` (gitignored). Agents cannot read it (blocked by deny rules + guard hook),
but the running app and tests can: the backend loads it with
`spring.config.import=optional:file:../.env[.properties],optional:file:.env[.properties]`.
Reference config by environment-variable name, add the name (empty value) to `.env.example`, and if a
value is missing, report `NEEDS-HUMAN: set <VAR> in .env` so the PM asks the human via Slack.
Never put a secret in code, tests, issues, PR text or commit messages. The pre-commit hook runs gitleaks.

## Definition of Done (a ticket can go to the human for merge only when all hold)
- [ ] Every acceptance criterion is met and covered by at least one automated test named after it
- [ ] `mvn -B verify` passes (unit + Testcontainers integration tests)
- [ ] `npm run build` and `npm run test:ci` pass; `npm run e2e:ci` passes for UI stories
- [ ] CI is green on the PR (backend, frontend, secret-scan)
- [ ] UI matches the `docs/ux/` spec, including `data-testid`s and empty/loading/error states
- [ ] No secrets, no hardcoded environment-specific URLs; new config documented in `.env.example`
- [ ] Errors handled at the boundary (backend returns RFC 9457 problem details; UI shows the error state)
- [ ] QA verdict PASS and BA verdict ACCEPT posted on the PR
- [ ] PR description lists ACs and how each is tested

## Cost discipline (Claude Pro)
Read only what you need (`gh ... --json <fields>`, `head`, targeted `grep`), don't dump whole logs or
diffs into context, run the narrowest test first, and return short summaries to the PM.
