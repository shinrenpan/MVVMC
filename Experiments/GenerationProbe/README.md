# GenerationProbe

Tests whether the skills can **guide creation**, not just catch violations. `ReviewProbe` asks "does the AI notice a broken rule?"; this asks "with no rule to copy, what does the AI do?" — which is where a spec's *gaps* show up, as opposed to its errors.

## Method

A fresh agent was given a product-level requirement and told to implement it in MVVMC. Two constraints made it a test of the spec rather than a test of imitation:

- It could read `.claude/skills/` freely
- It was **forbidden to read `Sources/`** — no existing feature to pattern-match against

The requirement was chosen to hit several rules that the demo does *not* demonstrate (see `SPEC-COVERAGE.md`): a search field (`@Bindable` + `TextField`), two independently-loading APIs, a reusable card container (Slot pattern), and a stock status that renders as colour (display helper).

The most important deliverable was not the code — it was a **"spec gap list"**: every decision the agent had to make that the rules did not cover, and every place two rules pulled in different directions.

## Result (2026-08, Claude Opus 5 subagent)

The generated feature (`GeneratedFeature/`) came out largely compliant, including the parts that need judgement rather than copying:

- L3 Actions named from the child's own viewpoint (`chipDidTap`, `rowDidTap`), with the L2 doing real mapping into business semantics — this is the rule most likely to be misapplied, and it was applied correctly
- `Section` suffix on L2, prefix inheritance on L3/L4, same-prefix families sharing one `private extension`
- `@Bindable` declared once inside `body`, subviews receiving only slices
- Pure-display components (`ListStockBadge`, `SearchSection`) correctly declaring no `enum Action`
- Display helpers at file top, extending the Model rather than the View

**Six real gaps were found**, all since fixed in the skills:

| Gap | Fix |
|---|---|
| §12's Preview template used `.mocks` shorthand, which doesn't compile (`mocks` lives on the Domain Model, not on `[Item]`) — and the compiler misreports it as a ViewBuilder `return` error | Spelled out the full name plus the reason |
| §10's Slot container example (`RoundedRectangle().overlay(content)`) produces a card with no height | Rewritten as `content.background(...)` |
| "View never touches State" (VM skill) contradicted "`TextField` binds to state via `@Binding`" (V skill) | Reworded to "View doesn't read State to make flow decisions"; binding vs. flow control separated |
| No guidance for the four-state block (loading / error / empty / content), so the agent wrote the same skeleton twice | Added a suggested skeleton, including why `.loading where items.isEmpty` matters |
| Nothing said where display *text* belongs (only colour was covered) | Text follows colour into the V-layer display helper |
| §4 gave two different thresholds for promoting a shared component ("multiple Sections" vs "two or more View files") | Replaced with an explicit three-tier ladder; the middle tier was missing entirely |

Two further observations were judged **not** to need spec changes: the agent flagged that `Category` as a Domain Model name shadows `ObjectiveC.Category` (real, but scoped access makes it harmless), and that endpoint naming can collide with the `API` state container (different scopes, no actual collision).

## Why this code is not in the demo

It is deliberately kept out of `Sources/`. The demo's six features already cover every structural rule; adding a seventh to tick boxes on `SPEC-COVERAGE.md` would contradict the reasoning behind the 🚫 markers there — a demo that shows everything stops showing anything clearly. This directory keeps the artefact as evidence without growing the demo's maintenance surface.

The code was typechecked by the agent against stubs (Swift 6, strict concurrency complete) but is **not** part of any build target here, so it carries no compile guarantee in this repo.

## Re-running

Give a fresh agent a product requirement plus these two rules: read `.claude/skills/`, do not read `Sources/`. Ask for the gap list as the primary deliverable — and make it explicit that "no gaps found" is an acceptable answer, otherwise you get invented ones.
