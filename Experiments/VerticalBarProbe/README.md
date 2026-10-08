# VerticalBarProbe

Backs `mvvmc-hostcontroller`〈導覽列（title / toolbar）歸誰〉: where an MVVMC page must opt out of iPhone Duo's vertical bars.

## Question

MVVMC pages are `UIHostingController` subclasses pushed on a UIKit `UINavigationController` inside a `UITabBarController`. iOS 27.1 offers two opt-outs — SwiftUI `.toolbarVerticalBehavior(.disabled)` (V layer) and `UIViewController.preferredVerticalBarBehavior` (C layer). Does the SwiftUI one reach the UIKit containers?

## Run

```bash
cd Experiments/VerticalBarProbe && xcodegen generate
xcodebuild build -scheme VerticalBarProbe -destination 'id=<Duo UDID>' -derivedDataPath /tmp/vbp
xcrun simctl install <UDID> /tmp/vbp/Build/Products/Debug-iphonesimulator/VerticalBarProbe.app
for m in none swiftui uikit; do xcrun simctl launch --console-pty <UDID> com.probe.VerticalBarProbe -mode $m | grep RESULT; done
```

Must run where vertical bars exist (iPhone Duo, 27.1 SDK and runtime). The page's toolbar items have icons — text-only items never go vertical and would hide the effect.

## Result (2026-10-07, Xcode 27.1 RC 27A9275, iPhone Duo inner display 951×669, iOS 27.1)

```
RESULT mode=none    verticalBarEdge=trailing    hostInsets=[t82 l0 b34 r84] navBar=[x0 y24 w951 h58] tabBar=[x882 y0 w69 h669]
RESULT mode=swiftui verticalBarEdge=trailing    hostInsets=[t82 l0 b34 r84] navBar=[x0 y24 w951 h58] tabBar=[x882 y0 w69 h669]
RESULT mode=uikit   verticalBarEdge=unspecified hostInsets=[t82 l0 b83 r0]  navBar=[x0 y24 w951 h58] tabBar=[x0 y586 w951 h83]
```

**The SwiftUI modifier is a silent no-op in this hierarchy**: `swiftui` is identical to `none`. Overriding `preferredVerticalBarBehavior` on the hosting controller works — the vertical bar disappears and the tab bar returns to the bottom. So in MVVMC the opt-out is a C-layer appearance setting, not a V-layer modifier.

## Item-level and navigationItem-level settings do cross the bridge

Two more modes (same run conditions):

```
RESULT mode=axis     … items=compression=0 2:Profile/axis=1,Filter/axis=1   ← ToolbarItem.axisBehavior(.horizontalOnly)
RESULT mode=compress … items=compression=1 2:Profile/axis=0,Filter/axis=0   ← .toolbarVerticalCompressionBehavior(.prefersToolbarItems)
```

`items=` reads the hosting controller's UIKit `navigationItem` directly. Item-level `.axisBehavior` lands on each `UIBarButtonItem` (screenshot confirms both icons leave the vertical bar for the top row), and the compression modifier lands on `navigationItem.verticalBarCompressionBehavior`. They travel the same bridge as the toolbar items themselves. **Only the view-controller property `preferredVerticalBarBehavior` does not** — `UIHostingController` does not forward it to its SwiftUI content.

Not measured: whether the SwiftUI modifier works when SwiftUI owns the navigation container (`NavigationStack` / `TabView`) — MVVMC never has that shape.

## Which side the vertical bar is on — asymmetric safe areas (2026-10-08)

Apple's Tech Talk 111461 says *"safe areas are often asymmetric … vertical buttons can appear on the left side in landscape and Split View multitasking … avoid assuming that insets on opposite sides are equal."* Every measurement above had the bar on the trailing edge, so the question was whether it ever moves to leading.

`-mode watch` does not exit; it prints a `WATCH` line on every layout pass that changes the hosting controller's window size, interface orientation, `verticalBarEdge`, `safeAreaInsets`, or `directionalLayoutMargins`. Rotation was driven with Cmd+→ in DeviceHub; Split View was set up by hand (drag the home indicator to a screen edge, Safari in the other half).

```bash
xcrun simctl launch --console-pty <UDID> com.probe.VerticalBarProbe -mode watch | grep WATCH
```

Same conditions as above (Xcode 27.1 RC 27A9275, iPhone Duo inner display, iOS 27.1). Settled values only:

| Configuration | window | `verticalBarEdge` | safe area l / r | layout margins lead / trail |
|---|---|---|---|---|
| Full screen, landscapeLeft | 951×669 | trailing | 0 / 84 | 20 / 84 |
| Full screen, landscapeRight | 951×669 | trailing | 0 / 84 | 20 / 84 |
| Full screen, portrait and upside-down | 669×951 | unspecified (tab bar at bottom) | 0 / 0 | 20 / 20 |
| **Split View, probe in the left half** | 469×669 | **leading** | **84 / 0** | 84 / 20 |
| Split View, probe in the right half | 469×669 | trailing | 0 / 84 | 20 / 84 |

- **Full screen never puts the bar on the left**, in either landscape. Rotating 180° does not mirror it.
- **Split View does.** The bar sits on the window edge that is also a screen edge: probe on the left, bar on the leading side (screenshot confirms the toolbar buttons and tab bar on the left of the list); Safari on the right half has its own bar on the right at the same moment.
- **Margins follow the bar**: the side with the bar has margin = inset (84), the other side keeps the 20pt base — the "layout margins are also asymmetric" of the Tech Talk.
- **Transient values during the change are not the settled ones**: mid-rotation the trailing inset briefly read 172 (margin 192), and mid-split both sides briefly read 84. Code that caches insets from the first layout pass after a change will cache a wrong value.
- Unexplained: during one rotation the log also showed `window=678x466` against a 951×669 screen several times, alternating with the real size — looks like a system snapshot pass (app switcher), not something the app sees on screen. Not investigated.

**Consequence for MVVMC: no rule.** SwiftUI places content inside the safe area by default, and the demo does no inset arithmetic (`git grep safeAreaInsets Sources` is empty). What this changes is an assumption, not an architecture: any UIKit-bridged view, or SwiftUI code that reads insets, must not assume "the bar is on the right" or "left inset = right inset" — HerbMeet's `MKUserTrackingButton` pinned to `map.trailingAnchor` (2026-10-08, fixed by pinning to `safeAreaLayoutGuide`) is the field instance. Split View was not measured with half-open posture or on the outer display.
