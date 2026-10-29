---
name: design-language
description: The travel planner's design language — tokens (color, type, spacing), layout, core components, states, accessibility — and the screen-spec template UX uses in docs/ux/. Use when specifying or building any UI.
---

# Design language — v0 (starter; the human and UX refine it)

Mood: calm, trustworthy, a little adventurous. Content (places, days, times) is the hero; chrome stays quiet.

## Tokens (implement as CSS custom properties in frontend/src/styles/tokens.scss)
| Token | Value | Use |
|---|---|---|
| `--color-bg` | #F7F7F4 | page background |
| `--color-surface` | #FFFFFF | cards, sheets |
| `--color-text` | #1D2433 | body text |
| `--color-text-muted` | #5B6475 | secondary text |
| `--color-primary` | #0F6E6E | primary actions, links (deep teal) |
| `--color-primary-contrast` | #FFFFFF | text on primary |
| `--color-accent` | #E8833A | highlights, "AI suggested" badges (warm sunset) |
| `--color-border` | #E2E4E9 | dividers, inputs |
| `--color-success` / `--color-warning` / `--color-danger` | #2E7D4F / #B7791F / #C2410C | status |
| `--radius-s/m/l` | 6px / 10px / 16px | inputs / cards / sheets |
| `--space-1..8` | 4, 8, 12, 16, 24, 32, 48, 64px | spacing scale only |
| `--font-sans` | "Inter", system-ui, sans-serif | everything |
| type scale | 12 / 14 / 16 (body) / 20 / 24 / 32 px, line-height 1.5 body, 1.25 headings | |
| `--shadow-card` | 0 1px 2px rgba(16,24,40,.06), 0 1px 3px rgba(16,24,40,.10) | cards |
Dark mode: later; don't hardcode colors so it stays possible.

## Layout
- Mobile-first. Breakpoints: `sm` 0–599, `md` 600–1023, `lg` ≥1024.
- Max content width 1120px, page gutters `--space-4` (mobile) / `--space-6` (md+).
- App shell: top bar (logo, primary nav, account) on md+; bottom nav with ≤4 items on sm.

## Core components (reuse before inventing)
Button (primary / secondary / ghost / danger; sizes m, s) · Text field · Select · Date range picker ·
Card · Trip card (cover image, destination, dates, travellers) · Day timeline (itinerary days with
time-slotted items) · Chip/Tag · Badge ("AI suggested" uses accent) · Empty state (icon, title, one
line, one action) · Skeleton loader · Inline error (problem title + retry) · Toast · Dialog/Sheet.

## States every screen specifies
Empty · Loading (skeletons, not spinners, for lists) · Error (what happened + retry) · Success ·
Partial (some data failed). AI-generated content is labelled and editable; show progress while generating.

## Accessibility (non-negotiable)
WCAG 2.2 AA contrast, visible focus ring (2px `--color-primary` outline), every input labelled, full
keyboard path, touch targets ≥ 44px, don't convey meaning by color alone, `prefers-reduced-motion` respected.

## Copy
Plain, friendly, short. Sentence case. Verbs on buttons ("Plan my trip", not "Submit"). Dates like "Tue 3 Mar".

## Screen spec template (docs/ux/<issue>-<slug>.md)
```markdown
# <Screen name> — #<issue>
**Story:** <one line>   **Route:** /<path>   **Entry points:** <where users come from>

## Layout
### sm
<ASCII wireframe>
### lg
<ASCII wireframe>

## Components
| Element | Component | data-testid | Notes |
|---|---|---|---|

## States
- Empty: ...
- Loading: ...
- Error: ...
- Success: ...

## Interactions & validation
1. ...

## Copy
| Key | Text |
|---|---|

## Accessibility notes

## AC mapping
| AC | Satisfied by |
|---|---|

## Open questions
```
