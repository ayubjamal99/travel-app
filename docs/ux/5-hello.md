# Hello page — #5
**Story:** Show the greeting from the backend so we know the stack works end to end.   **Route:** /   **Entry points:** Opening the app root URL.

## Layout
### sm
```
+--------------------------+
| (gutter 16px)            |
|  Travel Planner  (h1)    |
|  +--------------------+  |
|  | Card               |  |
|  | <greeting text>    |  |
|  +--------------------+  |
+--------------------------+
```
### lg
```
+----------------------------------------------+
|        (centered, max 1120px, gutter 24px)    |
|        Travel Planner (h1)                    |
|        +--------------------------+           |
|        | Card (max 480px)         |           |
|        | <greeting text>          |           |
|        +--------------------------+           |
+----------------------------------------------+
```
Card sits on `--color-bg`, uses `--color-surface`, `--radius-m`, `--shadow-card`, padding `--space-5`.

## Components
| Element | Component | data-testid | Notes |
|---|---|---|---|
| Page title | h1, 32px | `hello-title` | Static text |
| Card | Card | `hello-card` | Container for all states |
| Greeting | Body text 20px, `--color-text` | `hello-message` | Shows `message` from `GET /api/v1/hello`; success only |
| Loading placeholder | Skeleton loader (one text line) | `hello-loading` | Loading only |
| Error block | Inline error | `hello-error` | Error only; contains title, detail, Retry |
| Retry | Button, secondary, size m | `hello-retry` | Inside `hello-error`; label "Retry" |

## States
- Empty: not applicable (greeting is always a non-empty string). If `message` is empty or missing, treat as Error.
- Loading: card shows one skeleton line (`hello-loading`), `aria-busy="true"` on the card. No spinner. Retry and message are not in the DOM.
- Error: request fails (network, backend down, non-2xx, invalid body). Skeleton replaced by `hello-error` with title, one-line explanation, and Retry button. `hello-message` is not in the DOM. Icon plus text, uses `--color-danger`, never color alone.
- Success: `hello-message` shows the greeting text exactly as received (plain text, not HTML). Loading and error elements are not in the DOM.
- Partial: not applicable (single request).

## Interactions & validation
1. On load of `/`, call `GET /api/v1/hello` immediately; show Loading.
2. 200 with non-empty string `message`: show Success. Anything else: show Error.
3. Retry click or Enter/Space: return to Loading, repeat the request. On success show Success; on failure show Error again with focus returned to Retry.
4. Retry is disabled while a request is in flight (the Loading state already hides it).
5. No inputs, so no field validation.
6. Request timeout: 10 s, then Error.

## Copy
| Key | Text |
|---|---|
| Page title | Travel Planner |
| Error title | Can't reach the server |
| Error detail | Something went wrong while loading your greeting. Check your connection and try again. |
| Retry button | Retry |
| Loading (screen reader) | Loading greeting |

The greeting itself comes from the backend (`HELLO_GREETING`); no fallback text is shown.

## Accessibility notes
- One `h1`. Card has `role="region"` with `aria-labelledby` pointing at the h1.
- Loading: `aria-busy="true"`; visually hidden text "Loading greeting".
- Error block has `role="alert"` so it is announced when it appears. After Retry fails, move focus to the Retry button.
- Success greeting announced via `aria-live="polite"` container wrapping the content area.
- Retry: touch target at least 44px high, visible 2px `--color-primary` focus outline, keyboard operable.
- Error text `--color-danger` (#C2410C) on `--color-surface` meets AA at 16px; also pair with an icon.
- Skeleton shimmer disabled under `prefers-reduced-motion`.

## AC mapping
| AC | Satisfied by |
|---|---|
| AC1 | Backend only, no UI |
| AC2 | Backend; UI consumes it in Success state |
| AC3 | Backend only, no UI |
| AC4 | `hello-message` in Success state at `/` |
| AC5 | `hello-error` plus `hello-retry` (button labelled "Retry") in Error state when backend is down |

## Test hooks
`hello-title`, `hello-card`, `hello-loading`, `hello-message`, `hello-error`, `hello-retry`.
QA: simulate backend down by stubbing `/api/v1/hello` to abort; assert `hello-error` visible and `hello-message` absent; then restore the stub, click `hello-retry`, assert `hello-message` visible.

## Open questions
- `--space-5` is 24px in the scale (`--space-1..8`: 4, 8, 12, 16, 24, 32, 48, 64). No flags for new colors or fonts.
