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

- **Never restate a skill's rules in this file.** Duplicated rules drift: that is exactly how the `send` closure type ended up with two conflicting definitions living in two files for months. When a rule changes, change it in the owning skill only.
- This file may hold only what belongs to no single layer: the layer table, creation order, file structure, layer boundaries, and data flow.
- `Sources/` and `Tests/` are the spec's compile-time test. After changing a rule, check whether the demo still demonstrates it — and if the demo cannot compile the new rule, the rule is wrong. `SPEC-COVERAGE.md` maps each rule to the demo file that proves it; update it in the same pass.
