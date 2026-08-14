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

## Second run: a requirement with *flow* (`GeneratedFeature2/`)

The first requirement was display-shaped — load things, show things. The second deliberately had process and intermediate state: a paginated order list (load more, "no more", first-page vs Nth-page failure), an order creation form (validation, disabled while submitting, preserve input on failure), and the list needing to reflect a newly created order.

This run dug deeper than the first, and the very first finding landed on a rule added *during this same review cycle*:

| Finding | Severity |
|---|---|
| **The four-state skeleton actively leads to wrong code.** It guarded `.loading` with `items.isEmpty` but not `.error` — so "pull-to-refresh failed" and "page 2 failed" both replace the user's existing list with an error screen. Invisible when reading the code; only shows up in that specific scenario | 🔴 rewritten: check content first, *then* status |
| Mock rules are unsatisfiable on a form screen: mocks must hang off a Domain Model, but a pure form has none (a draft isn't a business entity) — while §12 requires Previews to use M-layer mocks | 🔴 exception added |
| `Router`/`Callback` declared without `Equatable` in templates, while the testing skill asserts `received == .toDetail(post)` | 🔴 templates fixed, rule stated |
| Pagination absent entirely — which of the two loads owns the status field, who decides to fetch the next page, what happens after a failed page | 🟡 new section |
| Forms absent entirely — where validation lives, how "submitting" is expressed, preserving input on failure | 🟡 new section |
| Nav bar title/buttons: unassigned. Putting a button in `navigationItem` forces a C-layer `Task`, which the C rules forbid — so the answer was derivable but never stated | 🟡 stated |
| `back(from:)` — is `from:` "who is leaving" or "whose nav stack"? | 🟡 clarified |
| Callback payload: `mvvmc-structure` says primitives cross feature boundaries, but the templates and the demo both passed a Domain Model | 🔴 settled — primitives both ways; demo updated |

Notably the agent **deviated from the spec on purpose** for the four-state skeleton, and said so in a code comment — it could tell the rule would break the stated requirement. A spec that produces a visible conflict is better than one that quietly produces bad code, but this one should not have had the conflict.

## Third run: multi-level navigation and polling (`GeneratedFeature3/`)

Third requirement: an order detail screen with a **5-second polling status bar** (only that bar may redraw), plus a **three-step return wizard** whose final submission must land back on the detail screen — skipping the intermediate pages — and update it.

This run hit the architecture's edges rather than its details:

| Finding | Outcome |
|---|---|
| **The §7 performance measurements used the wrong shape.** The probe modelled two independent properties; MVVMC forces a single `var state: State`. Re-measured — the core claim survives (child structs still skip), but row 3 (`parent = 0`) is **unreachable in MVVMC**: an L1 must read `state.x` to pass values down, and handing the whole `@Observable` object to a child is forbidden by §2 | 🔴 spec corrected; "the L1 body always re-runs" is now stated as the architecture's cost |
| Deep return across intermediate pages — `onCallback` only ever defined one level | 🔴 new section: relay upward, only the endpoint pops, and a warning that a three-level relay means the pages should probably be one feature |
| Alert / confirmation dialog never mentioned anywhere. Applying the "anything that presents goes to C" rule literally forces `UIAlertController`, which then forces C to hold interaction logic and start a `Task` — both explicitly banned | 🔴 new section; the rule's intent restated as "do you have to obtain a VC yourself?" |
| Polling: C can't start Tasks, View can't make flow decisions, a VM-held Task has no one to cancel it | 🔴 new section — `.task` starts it, the loop lives in the VM. Plus the honest limitation: UIKit push doesn't remove the lower view, so polling continues underneath |
| Wizard: one feature or three? `mvvmc-structure`'s split signals said "split", its other line said "don't" | 🔴 exception added: wizards default to **one** feature; the test is whether the pages share one unsubmitted draft |
| Optimistic update — is a VM allowed to construct a Domain Model that never came from a DTO? | 🟡 yes; the rule constrains the data *source*, not authorship |
| Callback results are stuffed into `ViewAction` despite not being "what the user did here" | 🟡 stated explicitly, rather than adding a fourth Action category |
| Edge-swipe can't be disabled per page — gesture policy is welded to `TransitionStyle` | 🟡 recorded as an unresolved design limitation |

The agent also **deliberately deviated** from the four-state skeleton and said so in a code comment — it could see the rule would break the stated requirement. It wrote what this review cycle later concluded was correct, before the spec said so.

## Fourth run: the same requirement, the corrected spec (`GeneratedFeature4/`)

A **regression test** rather than a new probe: identical requirement to run 3, handed to a fresh agent after this cycle's fixes landed. The question was not "what else is missing" but "did the fixes work".

**Three and a half of the four named problems were answered outright**, with the agent citing the section it followed:

- *Wizard: one feature or three?* — answered, including the test to apply ("do these pages share one unsubmitted draft")
- *Deep return across pages* — answered, **and then not needed**: once the wizard collapsed into one feature there was only a single callback level left. An upstream rule dissolved a downstream problem
- *Confirmation dialog* — answered; the agent noted the example was nearly the requirement verbatim
- *High-frequency redraw* — the V-layer half was answered; the M-layer half was still missing (below)

The agent also singled out the swipe-back limitation as useful precisely *because* it says no solution exists: **"明講沒解比沒寫更有用"**.

Eight gaps remained, and their character had shifted — from "this scenario is missing entirely" to "these two rules interact badly":

| Gap | Outcome |
|---|---|
| **Splitting Views isn't enough.** A high-frequency field living inside a low-frequency Model makes that Model `!=` itself every tick, so every child holding it redraws — no amount of View splitting helps. The real gate is in M | 🔴 new rule: high-frequency fields become parallel State fields; §7 now says the first gate is in M, not V |
| **§11's `@Bindable` example doesn't compile** — the `$` is on the wrong side. Verified: `cannot convert value of type 'VM' to expected argument type 'Bindable<VM>'` | 🔴 fixed: `$bVM` at the call site, `bVM.state.x` inside |
| **Optimistic update races the silent poll** — both rules were added in this same cycle, and an in-flight poll response overwrites the optimistic value | 🔴 race documented with its two common resolutions; the point is knowing it exists, since it only appears on slow networks |
| `.task` can only live on the L1 — a child's `send` is synchronous, so `.task { send(...) }` cancels the moment it returns. Two rules multiplied into a third that neither states | 🔴 stated |
| Bool flags guarding poll re-entry can latch permanently (fail-closed: polling never restarts) | 🔴 stated as a prohibition |
| Passing "a whole set" across features when primitives can't carry it | 🟡 three-step fallback added |
| A state-driven wizard must hide the system back button, or it pops the whole feature | 🟡 stated |
| Where a `Step` enum lives; whether "layout decided from state" counts as a flow decision | 🟡 both given a test: "does it appear in the API contract" / "does this branch change the screen or the next step" |

## Why this code is not in the demo

It is deliberately kept out of `Sources/`. The demo's six features already cover every structural rule; adding a seventh to tick boxes on `SPEC-COVERAGE.md` would contradict the reasoning behind the 🚫 markers there — a demo that shows everything stops showing anything clearly. This directory keeps the artefact as evidence without growing the demo's maintenance surface.

The code was typechecked by the agent against stubs (Swift 6, strict concurrency complete) but is **not** part of any build target here, so it carries no compile guarantee in this repo.

## Re-running

Give a fresh agent a product requirement plus these two rules: read `.claude/skills/`, do not read `Sources/`. Ask for the gap list as the primary deliverable — and make it explicit that "no gaps found" is an acceptable answer, otherwise you get invented ones.
