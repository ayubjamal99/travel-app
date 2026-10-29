---
name: testing
description: Test strategy and tooling for the travel planner — JUnit 5, Spring test slices, Testcontainers, Angular unit tests, Playwright e2e — plus how to map acceptance criteria to tests and report results. Use when writing or running tests.
---

# Testing

## Map ACs to tests first
For a story with AC1..ACn, list which test proves each AC before writing anything.
Name tests after the AC so the mapping is visible in reports:
- Java: `void ac1_createsTripWithDestinationAndDates()`
- Playwright: `test('AC1: user sees their trips', ...)`

## Pyramid
| Layer | Tool | For |
|---|---|---|
| Unit | JUnit 5 + AssertJ (+ Mockito sparingly) | service logic, mappers, validation |
| Slice | `@WebMvcTest`, `@DataJpaTest` | controller contract (status, JSON, problem details), queries |
| Integration | `@SpringBootTest` + Testcontainers | one happy path per feature through real DB |
| Frontend unit | Angular CLI test runner | services, components with logic |
| E2E | Playwright (Chromium) | each UI acceptance criterion |

## Testcontainers (backend)
Docker runs inside the devcontainer (docker-in-docker) and on GitHub runners.
```java
@Testcontainers
@SpringBootTest
class TripFlowIT {
  @Container @ServiceConnection
  static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:16-alpine");
}
```
Fake external APIs (LLM, travel data) with an in-test implementation of the feature's interface
or WireMock; never call real paid APIs in tests.

## Playwright (frontend/e2e)
- `playwright.config.ts`: Chromium only, `webServer` starts backend + frontend (or frontend with a
  mocked API via `page.route` when the story is UI-only), `retries: 1` in CI, traces on first retry.
- Select by `data-testid` from the UX spec, then by role/label. No CSS-path selectors, no fixed sleeps.
- One spec file per story: `frontend/e2e/<issue>-<slug>.spec.ts`.

## Commands
```bash
mvn -B -ntp -f backend/pom.xml verify                 # all backend tests
mvn -B -ntp -f backend/pom.xml -Dtest=TripServiceTest test   # one class while iterating
cd frontend && npm run test:ci                         # unit
cd frontend && npx playwright install chromium && npm run e2e:ci   # e2e
```

## Reporting (QA → PR comment)
```
🤖 **qa**: VERDICT FAIL — 2/3 ACs pass

| AC | Test | Result |
|----|------|--------|
| AC1 | TripControllerTest.ac1_... | ✅ |
| AC2 | e2e 12-trip-list.spec.ts "AC2 ..." | ❌ |

**AC2** expected empty state `trip-list-empty`, got spinner forever.
  Repro: no trips in DB → open /trips. Excerpt: (≤15 lines)
```
Keep excerpts short: the assertion, expected vs actual, and the first relevant stack frame.
