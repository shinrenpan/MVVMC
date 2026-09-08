# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A personal MVVMC architecture guideline, continuously evolved through discussion, refinement, and demo validation. MVVMC is a custom iOS architecture pattern designed for personal and team use.

---

## Repository Layout

| Path | Role |
|---|---|
| `.claude/skills/` | **The specification.** One skill per layer / concern; each is the single source of truth for its own rules |
| `Sources/` | Demo app — the compile-time test for the spec |
| `Tests/` | ViewModel unit tests |
| `README.md` / `README.en.md` | Human-facing overview |

---

## Architecture: MVVMC

Four strictly separated layers. SwiftUI + UIKit hybrid. iOS 17+.

| Layer | File | Responsibility | Rules live in |
|---|---|---|---|
| M | `FeatureViewModel+Models.swift` | State / Domain Models / DTOs | `mvvmc-model` |
| VM | `FeatureViewModel.swift` | `@Observable @MainActor`, single `doAction` entry point | `mvvmc-viewmodel` |
| V | `FeatureView.swift` | Pure SwiftUI, zero navigation logic | `mvvmc-view` |
| C | `FeatureHostController.swift` | UIKit bridge, sole owner of routing | `mvvmc-hostcontroller` |

Cross-cutting concerns:

| Concern | Rules live in |
|---|---|
| Where a type or component lives; feature boundaries | `mvvmc-structure` |
| AppRouter / Deeplink / SceneDelegate | `mvvmc-navigation` |
| ViewModel unit tests | `mvvmc-testing` |
| async / Task / actor / Sendable | `swift-concurrency` |
| Feature review · single-file deep review | `mvvmc-review` · `mvvmc-deep-review` |
| Skip.tools → Android | `mvvmc-skip` |

### Creation Order

M → VM → V → C

### File Structure

```
Pages/FeatureName/
├── FeatureNameViewModel+Models.swift   ← M
├── FeatureNameViewModel.swift          ← VM
├── FeatureNameViewModel+APIs.swift     ← VM (endpoint definitions — one possible layout, not a spec requirement)
├── FeatureNameView.swift               ← V
├── FeatureNameMocks.swift              ← Mock (#if DEBUG, optional)
└── FeatureNameHostController.swift     ← C
```

### Layer Boundaries

These four lines define what the layers *are*. Every concrete rule, template, and ✅/❌ list lives in the skills above — not here.

- **M** — DTOs never leave this layer; `toDomain()` is the only path from API data into State.
- **VM** — `doAction(_:)` is the only entry point. The ViewModel never navigates: it emits `onRoute` / `onCallback` and lets C act.
- **V** — no navigation logic, no business logic, never creates its own ViewModel.
- **C** — the only layer that routes, and it routes exclusively through `AppRouter.shared`.

### Data Flow

```
User interaction  → V:  Task { await viewModel.doAction(.view(.xxx)) }
                  → VM: handleViewAction   → doAction(.apiRequest(...))
                  → VM: handleAPIRequest   → call API → doAction(.apiResponse(...))
                  → VM: handleAPIResponse  → update state → View refreshes automatically

Navigation        → VM: onRoute?(.toXxx) → C → AppRouter.shared.to(vc, from: self)
Cross-VC result   → child VM: await onCallback?(.xxx) → parent C → AppRouter.shared.back(from: self)
```

---

## Maintaining the Spec

- **Never restate a rule anywhere but in the skill that owns it.** Duplicated rules drift, and this repo has now produced the failure in **four** directions — the rule is not just about this file:
  - `CLAUDE.md` ↔ skill — the `send` closure type had two conflicting definitions for months
  - **skill ↔ skill** — `swift-concurrency` said "undecided" while `mvvmc-viewmodel` said "settled" about the same question; a project that had enabled the setting could legitimately pick either
  - **`TODO.md` ↔ skill** — the settlement was written into one skill and not the other, and `TODO.md` recorded the contradiction on 2026-07-11 without anyone acting on it for two months
  - **skill ↔ its consumer** — `mvvmc-review` restates each layer's rules as check items. When a rule gains an exemption, nothing checks whether the enforcement end learned about it. A 2026-09 audit found **14 "do not file this" exemptions upstream and 0 carried into the review skill.** This one is the worst, because review is the spec's only enforcement path: a stale enforcer means the rule changed but did not take effect.

  Test for whether a check item will drift: **delete the upstream section it names — does the item still read as an instruction?** If yes it carries its own criteria and will drift; if it degrades into an empty pointer, it will not.

  **These four are not a spec-specific disease.** The same round that catalogued them also changed an API and left `README.md` describing the removed one, and changed twenty rules without rebuilding the demo — neither of which is a *restated rule*. The actual shape is **"something changed and its consumers did not"**, and the spec is merely its most visible host. So the question to ask after any change is not "did I restate this somewhere" but **"what reads this?"** — skills, the review skill, `TODO.md`, `SPEC-COVERAGE.md`, both READMEs, the demo, and the probes each consume something here.
- This file may hold only what belongs to no single layer: the layer table, creation order, file structure, layer boundaries, and data flow.
- **A new skill needs a symlink in `~/.claude/skills/`**, or it only exists while working inside this repo — which is precisely when you least need it. The skills are meant to travel to whatever project you are actually writing MVVMC code in.

  ```bash
  ln -s "$PWD/.claude/skills/<name>/" ~/.claude/skills/<name>
  ```

  This is the step most easily forgotten, and the cost is not hypothetical: `mvvmc-structure` went a whole session without one, and **`mvvmc-navigation` went 33 days** — during which two shipped apps wrote their entire Router layer with no access to it. One of them cited the skill *by name* in its planning document, a file it could not open. **Verify delivery, do not assume it**: `ls ~/.claude/skills/` after adding a skill, and treat a skill named in a plan but absent from that listing as a hard stop.

- **Before another round of spec work, read `Experiments/README.md`** — it records which kind of check finds which kind of problem, and the pitfalls that cost the most to learn (a perfect enforcement score is not evidence of a good spec; every round of fixes creates the next round's bugs).
- `Sources/` and `Tests/` play **two roles with opposite evidential weight**, and collapsing them is a mistake this file made once already:
  - **As a source of rules** — mirroring the demo's API surface into the spec — it is worth **nothing**. The demo is written to match the spec, so it agrees by construction. `mvvmc-navigation`'s six-method list came from here (commit `df7ebbb` says so) and matched **0 of 3** shipped projects.
  - **As a consumer forced to compile** — it is the strongest check there is for one specific class of defect: **a rule that describes a shape which should not exist.** In 2026-09, "the Router must not inject a Close button" turned out to be unimplementable alone, because the demo's detail page is reached by both push and deeplink and would have had to know which. Adversarial reading could not find that (nothing on paper says one VC has two entry paths) and neither could the field reports (none of the three apps had that shape). **That is a design defect, not a wording one**, and only the demo surfaces those.

  So "compile-time test, not validation" is too strong: it does not verify a rule is **right**, but it does verify a rule is **implementable** — and this round showed the second catches things the first would never reach.
- After changing a rule, **build and test the demo, and update `SPEC-COVERAGE.md` in the same pass.** Both are easy to skip when the change looks documentation-only — a 2026-09 round changed twenty-odd rules and did neither until asked. Any doc that describes the demo's API (`README.md`, `README.en.md`) counts as a consumer and drifts the same way.
