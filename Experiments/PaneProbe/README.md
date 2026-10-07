# PaneProbe

Backs the "two features side by side" research in `TODO.md` (iPhone Duo section). Question: in MVVMC, can each pane of an arrangement be a **complete HostController** — so the feature boundary (`mvvmc-structure`: features meet only through HostController init parameters) survives — instead of one HostController composing two features' Views and ViewModels?

## Shapes

Apple's shape (HIG, Tech Talk 111463, forums 848000): navigation container **outside** the arrangement. So every mode is `UINavigationController(root: container)` with two pane HostControllers; primary = Home, secondary = Settings unless noted.

| Mode | Container | Panes |
|---|---|---|
| `b` | `UIArrangementViewController`, `.split.axes(.horizontal)` | each a `UIHostingController` subclass |
| `c` | `UIHostingController` hosting SwiftUI `ArrangementView` | each wrapped by `UIViewControllerRepresentable` |
| `b2` | as `b`, but Settings = primary, Home = secondary with `layoutPriority = 1` | FoodEntropy's wanted layout |
| `b3` | as `b2`, plus `width.minimum = .absolute(400)` on both | |

Panes present a `.pageSheet` and push from `self`, the same path an MVVMC HostController uses. A loop prints one `STATE` line per second (window size; per pane: in window, parent, `navigationController != nil`, frame, `isHidden`, presented sheet), so posture changes can be read from the log while a human folds the simulator.

```bash
xcrun simctl launch --console-pty <UDID> com.probe.PaneProbe -mode b > b.log   # then fold/rotate by hand
```

Launching from the home-screen icon drops the `-mode` argument and runs `b`.

## Result (2026-10-07, Xcode 27.1 RC 27A9275, iPhone Duo, iOS 27.1; postures changed by hand)

| Question | `b` (UIKit) | `c` (SwiftUI + representable) |
|---|---|---|
| Collapsed (outer display / inner portrait): hidden pane | **removed from the hierarchy** — `parent=nil`, `inWindow=false`, `navigationController=nil` | same |
| Expanded again | **the same instance** re-attached (state kept) | same |
| Sheet presented from the pane that then collapses | **survives** — UIKit presents from the nearest full-screen presenter, so both panes report the same `presentedViewController`; the sheet never belonged to the pane | same |
| Push from a pane | covers **both** panes (one shared stack) | (same by construction) |
| Layout | panes extend under the status bar column (951pt) | respects safe area (867pt; outer display 382pt) |
| Inner portrait, default (Home primary, no priority) | Home only | Home only |

FoodEntropy's layout (Settings left, Home right, Home only when narrow):

| Mode | Inner landscape | Inner portrait (669×951) | Outer |
|---|---|---|---|
| `b2` | Settings │ Home | **still two columns** | Home only |
| `b3` | Settings │ Home | **still two columns** — Settings 400, Home squeezed to 269 despite its 400 minimum | Home only |

Matches FoodEntropy's SwiftUI measurement of the `b2` shape. Giving the secondary a priority stops the portrait collapse, and minimum widths do not force one. **No declarative arrangement setting yields "secondary kept, collapse in portrait"**; the container has to change the arrangement itself on size change (`updateArrangement`, or swapping placements) — which is what FoodEntropy's GeometryReader + HStack already does.

## Conclusions

- **Each pane can be a full HostController**, in both UIKit and SwiftUI containers. It presents its own sheets and handles its own routes; no parent needs to route on its behalf for the sheet to survive a collapse.
- **One hazard follows from "removed from the hierarchy"**: while collapsed, the hidden pane's `navigationController` is `nil`, so a push it issues does nothing. In practice it cannot receive taps while hidden; anything it triggers asynchronously (a completion that routes) would be dropped.
- **Push always covers both panes.** A pane that needs its own drill-down is a `UISplitViewController` case, not an arrangement.
