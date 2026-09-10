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

## Result (re-measured 2026-09-10 on Xcode 27 / Swift 6.4; unchanged from Xcode 26.4.1)

Every row below is identical under Xcode 26.4.1 and Xcode 27, on both iOS 26.4 and iOS 27.0 simulators. The reorder section further down is the part that **did** change — see it for the SDK matrix.

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

See **Re-running against two toolchains** at the end of this file — the SDK is now a variable that has to be controlled for, and the device must be addressed by UDID rather than by name.

The test asserts only that the experiment is valid (section A did re-render). The B and parent counts are printed as observations — read them, don't assert them, because the whole point is to detect if SwiftUI's behaviour ever changes.

---

## Reorder / `@State` identity (added 2026-09-08)

`mvvmc-view` §8 asserted a problem, a fix, and a side effect. **None of the three reproduced.**

```
PROBE_RESULT reorder withID  @State survived=true  child bodies=3
PROBE_RESULT reorder noID    @State survived=true  child bodies=3
PROBE_RESULT skip identical  A=0 B=0 C=0
PROBE_RESULT skip oneChanged A=0 B2=1 C=0
PROBE_RESULT skip reordered  A=0 B2=0 C=0
```

| §8's claim | Measured |
|---|---|
| `ForEach` identifies children structurally, so reordering misplaces their `@State` | ❌ state followed the **data** |
| `.id(item.id)` fixes that | ⚠️ **withID and noID are identical** — in this shape it does nothing measurable |
| Adding it rebuilds the child and resets `@State` | ❌ state survived |

**Setup**: `ForEach` over `Identifiable` elements; child holds `@State private var instanceID = UUID()`; array permuted programmatically; identity recorded per `item.id`. A reset changes the UUID for an id; a misplacement swaps UUIDs between ids. Neither occurred.

**Not covered**, which is why §8 was annotated rather than deleted: `id: \.self`, index-based `ForEach`, nested `ForEach`, animated reorder.

### The mechanism behind `bodies=3` — and its expiry on 2026-09-10

The first read of this was wrong — "§7's row 2 fails under reorder". The skip rows say otherwise: a **pure value child** is fully skipped when only the order changes (`skip reordered A=0 B2=0 C=0`), and only the one whose value actually changed re-runs (`oneChanged … B2=1`).

**Under Xcode 26 the difference was not reordering — it was whether the child holds `@State`.** A child with `@State` re-ran all three times; a plain value child re-ran zero times under the same permutation.

**Under Xcode 27 that distinction is gone.** The `@State` child is skipped too:

| Built with | `@State` child, pure reorder | value child, pure reorder |
|---|---|---|
| Xcode 26.4.1 / Swift 6.3.1 | `bodies=3` | `0` |
| Xcode 27.0 / Swift 6.4 | **`bodies=0`** | `0` |

`@State survived=true` in every cell — that never changed.

**The variable is the linked SDK, not the OS.** Both rows above were measured on the **same machine against the same iOS 26.4 simulator**, swapping only `DEVELOPER_DIR`; two runs per cell, deterministic. So an app rebuilt with Xcode 27 gets the new behaviour **even on iOS 26**, and an app still built with Xcode 26 keeps the old one on iOS 27.

> **How close this came to being recorded as an OS change.** The first re-measurement was on the iOS 27 simulator and showed `3 → 0`, which reads exactly like "iOS 27 changed SwiftUI's diffing". The iOS 26.4 simulator control **also** gave `0`, which killed that story; only swapping the toolchain located the real variable. **An OS-version control does not control for the SDK.** They move together on an upgrade and are trivially separable afterwards — one `DEVELOPER_DIR` — but only if you think to.

*Not concluding until the cause was known was the right call, and it came from the field reporter who had raised the original finding.*

### ⚠️ The probe was measuring itself wrong first

The first run of this produced `withID bodies=3`; a second run of the same code produced `withID bodies=0`. **Swift Testing runs suites in parallel by default**, and the three suites here share `BodyCounter.shared` / `StateIdentityLog.shared` — one test's `reset()` was clearing another's in-flight counts.

**A spec change had already been written from the contaminated numbers** before the discrepancy showed up. Everything is now a single `@Suite(.serialized)`; two consecutive runs give identical output. **Add new tests to that suite — a second top-level suite would run in parallel with it again and the corruption is silent.**

*This is the probe committing the exact failure this directory exists to catch: an unverified number, taken as measurement, written into a rule.*

---

## Resolved 2026-09-10: §7 under reorder

**§7's table assumes stable order** — every row measures "does the child's body get skipped when its props are unchanged", and none reorders the array. That gap is now measured on both toolchains:

- **Value children**: skipped under pure reorder on both SDKs (`skip reordered A=0 B2=0 C=0`). §7 row 2 holds. Never actually in doubt — the earlier wording conflated the `@State` child with row 2's value child.
- **`@State` children**: `bodies=3` on Xcode 26, `bodies=0` on Xcode 27. Only this case ever broke, and only when built with the older SDK.

So the qualifier §7 needs is **"…and the child is a pure value, if you build with Xcode 26"**, which is what `mvvmc-view`〈拆與不拆的決策準則〉now states as an SDK matrix rather than a flat rule.

**Still not covered** (unchanged): `id: \.self`, index-based `ForEach`, nested `ForEach`, animated reorder — the four shapes §8 is annotated, not deleted, for.

## Re-running against two toolchains

The SDK is a variable this probe now has to control for. Keep both Xcodes installed and swap with `DEVELOPER_DIR` rather than `xcode-select` (no sudo, no global side effect):

```bash
cd Experiments/ViewSplitProbe && xcodegen generate
SIM=<a booted simulator UDID>   # xcrun simctl list devices booted

# current toolchain
xcodebuild -project ViewSplitProbe.xcodeproj -scheme ViewSplitProbe \
  -destination "platform=iOS Simulator,id=$SIM" -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO 2>&1 | grep PROBE_RESULT

# control: previous toolchain, same simulator
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild ... (same)
```

Address the simulator **by UDID**, not by name. Not because name addressing is broken — it works fine — but because of what it does when a name is ambiguous:

```
$ xcodebuild ... -showdestinations
{ ... id:A45369CD-..., OS:26.4.1, name:iPhone 17e }
{ ... id:4957FA6E-..., OS:27.0,   name:iPhone 17e }
```

`-destination 'name=iPhone 17e'` succeeds against either one and **the output never says which OS ran**. For a probe whose entire purpose is detecting OS- and SDK-dependent behaviour, that is a silent wrong-attribution risk of exactly the kind this directory exists to catch. A UDID names one runtime and cannot slide.

(Separately: device names do come and go between releases — `iPhone 17 Pro`, which this README used to name, is not in the Xcode 27 device set at all. That breaks loudly, so it is the lesser problem. For ordinary build/test work, where the OS version is not the measurement, addressing by name is fine as long as you check `xcrun simctl list devices available` first.)
