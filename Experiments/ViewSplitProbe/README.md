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

Conclusions, in the spec's terms:

1. A `@ViewBuilder func` cannot be skipped — it is part of the parent's body.
2. A separate `struct View` is skipped when its props are unchanged.
3. **Where the property is read decides whether the parent re-runs.** Passing the model down (rather than reading it and passing values) keeps the parent's body out of the update entirely.

Point 3 is why `mvvmc-view` §2's "precise injection" rule is justified by **decoupling, not performance** — passing the whole object is actually cheaper to redraw.

4. **`AnyView` did not stop the skip.** The unchanged section still had its body skipped. The common claim "AnyView breaks diffing" does not hold at this level on this toolchain. What `AnyView` actually costs is *structural identity* — view identity becomes unstable across type erasure, which shows up as interrupted animations and reset `@State`, plus the loss of compile-time type information. This probe does not measure those; it only rules out the "body runs more often" explanation.

## Running it

```bash
cd Experiments/ViewSplitProbe
xcodegen generate
xcodebuild -project ViewSplitProbe.xcodeproj -scheme ViewSplitProbe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep PROBE_RESULT
```

The test asserts only that the experiment is valid (section A did re-render). The B and parent counts are printed as observations — read them, don't assert them, because the whole point is to detect if SwiftUI's behaviour ever changes.
