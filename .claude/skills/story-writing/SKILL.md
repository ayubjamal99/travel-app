---
name: story-writing
description: How the BA writes user stories and acceptance criteria as GitHub issues for the travel planner — format, slicing, INVEST checks, Gherkin ACs, labels, board placement. Use when creating or refining stories.
---

# Story writing

## Shape
Thin vertical slices: each story delivers something a user can see or an API consumer can call,
end to end (UI → API → DB as needed), shippable in ≤ 1 day of agent work. Split anything bigger.
First story of a fresh repo = **walking skeleton**: backend health endpoint, Angular shell page calling
it, CI green. Everything after builds on it.

INVEST check before filing: Independent, Negotiable, Valuable, Estimable, Small, Testable.

## Acceptance criteria
- Numbered `AC1..ACn`, 2–6 per story, Given/When/Then, each independently testable.
- Observable behaviour only (what the user sees / API returns), not implementation.
- Include the unhappy path that matters (validation error, empty state, dependency down).
- Exact values where they matter: status codes, messages, limits, formats.
- For AI behaviour, specify the contract, not the wording: structure, limits, fallbacks, that it's
  labelled as AI-suggested and editable.

## Issue body (CLI — issue forms don't apply to `gh issue create`)
Write the body to a temp file and run
`gh issue create --title "[Story] <title>" --label story --body-file /tmp/story-<slug>.md`:
```markdown
### Story
As a <persona>, I want <capability>, so that <outcome>.

### Context
Roadmap: <item from docs/product/roadmap.md>. Priority: P1|P2|P3. Depends on: #<n> | none.
<why now, constraints, links>

### Acceptance criteria
AC1 — Given <state>, when <action>, then <observable result>.
AC2 — ...

### Has UI?
Yes | No

### Out of scope
- ...

### Size
S | M
```
Then `scripts/board.sh add <n>` (lands in Backlog). Never add `approved`; the human does.

## Personas (refine in docs/product/vision.md)
Use the personas defined there by name. If none exist yet, ask (Mode A) or flag the assumption (Mode B).

## Bugs
Title `[Bug] <symptom>`, label `bug`, body: related story/PR, steps, expected (cite AC), actual (short
excerpt), severity. First line `🤖 **<role>**:` when filed by an agent.
