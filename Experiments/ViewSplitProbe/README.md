# ViewSplitProbe

Measures how SwiftUI's diffing actually behaves when a view is split three different ways. It exists so the performance claims in `mvvmc-view` §7 are **measured, not asserted** — and so they can be re-measured when SwiftUI's behaviour changes.

## What it measures

One `@Observable` model with two properties, `a` and `b`. Section A reads only `a`, section B reads only `b`. The view is hosted in a real `UIWindow` via `UIHostingController`, then **only `a` is mutated**. Each `body` bumps a counter.

Three variants:

| Variant | Split style |
|---|---|
| `FuncSplitView` | both sections are `@ViewBuilder private func` |
| `StructSplitView` | both sections are separate `struct View`, receiving only the value they need |
| `StructWholeModelView` | both sections are separate `struct View`, receiving the whole `@Observable` model |

## Result (Xcode 26.4.1, iOS Simulator, Swift 6.3.1 — 2026-08)

| Variant | parent body | A body | B body |
|---|---|---|---|
| `@ViewBuilder func` | 1 | 1 | **1** |
| separate `struct`, value injected | 1 | 1 | **0** |
| separate `struct`, whole model passed | **0** | 1 | **0** |
| separate `struct` wrapped in `AnyView` | 1 | 1 | **0** |
| **MVVMC shape** (single `var state: State`, values injected) | 1 | 1 | **0** |

Conclusions, in the spec's terms:

1. A `@ViewBuilder func` cannot be skipped — it is part of the parent's body.
2. A separate `struct View` is skipped when its props are unchanged.
3. **Where the property is read decides whether the parent re-runs.** Passing the model down (rather than reading it and passing values) keeps the parent's body out of the update entirely.

Point 3 is why `mvvmc-view` §2's "precise injection" rule is justified by **decoupling, not performance** — passing the whole object is actually cheaper to redraw.

4. **The MVVMC shape behaves like the value-injected case, but cannot reach row 3.** MVVMC forces a single `var state: State` on the ViewModel, so the first three rows — written with two independent properties — did not obviously transfer. Re-measured with the real shape: the child struct is still skipped, so the core claim holds. What is *not* reachable is `parent = 0`: an L1 in MVVMC must read `viewModel.state.x` to pass values down, and the only way to avoid that is to hand the whole `@Observable` object to the child — which the spec forbids for decoupling reasons. **In MVVMC, the L1 body always re-runs on any state change; the child struct's prop comparison is the only isolation gate you get.**

5. **`AnyView` did not stop the skip.** The unchanged section still had its body skipped. The common claim "AnyView breaks diffing" does not hold at this level on this toolchain. What `AnyView` actually costs is *structural identity* — view identity becomes unstable across type erasure, which shows up as interrupted animations and reset `@State`, plus the loss of compile-time type information. This probe does not measure those; it only rules out the "body runs more often" explanation.

## Running it

```bash
cd Experiments/ViewSplitProbe
xcodegen generate
xcodebuild -project ViewSplitProbe.xcodeproj -scheme ViewSplitProbe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep PROBE_RESULT
```

The test asserts only that the experiment is valid (section A did re-render). The B and parent counts are printed as observations — read them, don't assert them, because the whole point is to detect if SwiftUI's behaviour ever changes.

---

## Reorder / `@State` identity (added 2026-09-08)

`mvvmc-view` §8 made two assertions, neither of which reproduced:

```
PROBE_RESULT reorder withID  @State survived=true  child bodies=3
PROBE_RESULT reorder noID    @State survived=true  child bodies=3
```

| §8's assertion | Measured |
|---|---|
| `ForEach` identifies children structurally (by position), so reordering misplaces their `@State` | ❌ not reproduced — `@State` followed the **data** in both variants |
| Adding `.id(item.id)` rebuilds the child on reorder, resetting its `@State` | ❌ not reproduced — state survived |

**Setup**: `ForEach` over `Identifiable` elements, child holds `@State private var instanceID = UUID()`, array permuted programmatically, identity recorded per `item.id`. A reset would change the UUID for a given id; a misplacement would swap UUIDs between ids. Neither happened.

**What this does not cover**, and why the section was annotated rather than deleted: `id: \.self`, index-based `ForEach`, nested `ForEach`, animated reorder. The original assertion may still hold in those shapes — it was simply never measured in any of them.

**Consequence for the spec**: the rule "if the reset is acceptable, `.id()` alone is the complete fix" was resting on a side effect that does not occur. Lifting state into the ViewModel *to survive reordering* is a cost paid for nothing in the common shape. The rule now reads "lift it to survive **leaving the screen**", which is a different and real requirement.

**Meta**: this measurement also retired a fix made earlier the same day. A field report had identified a bug-level scenario (a polling list collapsing an expanded row every N seconds) built on §8's stated side effect, and a warning was written into the spec for it. The scenario cannot occur. *Both the report and the fix were reasoning correctly from an assertion nobody had checked* — which is the whole argument for this directory existing.

---

## Pending: one open question left

**§7's table still assumes stable order.** Every row measures "does the child's body get skipped when its props are unchanged", and none of them reorders the array. The reorder probe above shows all three children re-ran their bodies (`child bodies=3`) even though only their position changed — so row 2 (independent struct, values passed in) does **not** hold under reorder, and the table should say so. Measuring the exact boundary (which props-unchanged children are skipped when the array is permuted) is the remaining work here.
