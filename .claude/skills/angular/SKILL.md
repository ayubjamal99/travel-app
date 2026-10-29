---
name: angular
description: Frontend conventions for the travel planner's Angular app in frontend/ — scaffold, structure, components, state, HTTP, styling, test scripts. Use when creating or changing frontend code.
---

# Angular conventions

## Scaffold (first frontend story only)
```bash
ng new frontend --directory frontend --routing --style=scss --ssr=false --skip-git --defaults
```
Then add to `frontend/package.json`:
```json
"scripts": {
  "test:ci": "ng test --watch=false",
  "e2e:ci": "playwright test"
}
```
(If the generated test runner needs different flags for a single headless run, adjust `test:ci`
so that `npm run test:ci` runs once, headless, and exits non-zero on failure.)
Add `proxy.conf.json` mapping `/api` → `http://localhost:8080` and wire it in `angular.json` serve options.
Commit `package-lock.json`; CI uses `npm ci`.

## Structure — by feature
```
src/app/
├── core/            http interceptors, error handling, app-wide services
├── shared/ui/       dumb reusable components (button, card, empty-state, spinner)
├── features/
│   ├── trips/       trips.routes.ts, trip-list.component.ts, trip.service.ts, trip.model.ts
│   └── itinerary/
└── app.routes.ts    lazy-loads feature routes
```

## Components
- Standalone components only, `ChangeDetectionStrategy.OnPush`.
- Signals for state (`signal`, `computed`, `input()`, `output()`); built-in control flow (`@if`, `@for`, `@switch`).
- Use `inject()`; no constructor-parameter DI in new code.
- Smart (route/feature) components fetch data; `shared/ui` components only take inputs and emit outputs.
- Every screen implements the spec's empty, loading, error and success states.
- Put the spec's `data-testid` attributes on the elements QA targets.

## Data
- One service per feature wrapping `HttpClient`; typed models matching backend DTOs.
- Convert to signals at the component edge (`toSignal`) or use `resource`/`httpResource` where it fits.
- Show backend problem-details `title`/`detail` in the error state; never raw JSON.

## Styling
- Follow the design-language skill tokens (CSS custom properties in `src/styles/tokens.scss`).
- SCSS per component, no inline styles, no new colors outside tokens.
- Mobile-first; breakpoints from the design language.
- Accessibility: semantic elements, labels on inputs, visible focus, keyboard reachable, color contrast AA.

## Tests (see the testing skill)
- Unit-test services and components with logic; mock HTTP with `provideHttpClientTesting()`.
- E2E (Playwright) lives in `frontend/e2e/`; QA owns most of it.
