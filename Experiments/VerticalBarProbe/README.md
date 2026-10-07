# VerticalBarProbe

Backs `mvvmc-hostcontroller`〈導覽列歸誰〉: where an MVVMC page must opt out of iPhone Duo's vertical bars.

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

Not measured: whether the SwiftUI modifier works when SwiftUI owns the navigation container (`NavigationStack` / `TabView`) — MVVMC never has that shape.
