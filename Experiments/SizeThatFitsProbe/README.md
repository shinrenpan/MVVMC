# SizeThatFitsProbe

Backs `mvvmc-view` rule 15 / §8〈UIViewRepresentable：自報尺寸會跟著寬度長的 UIView 必須實作 `sizeThatFits`〉. FoodEntropy hit the defect with AdMob's `BannerView`; this probe asks whether it is AdMob or a general mechanism, using a hand-written `UIView` and no third-party code.

## What it measures

The app performs the "one column → two columns" transition by itself (no rotation, no taps), waits, prints one `RESULT` line, and exits. Every variable is a launch argument:

| Argument | Values | Meaning |
|---|---|---|
| `-container` | `hstack` / `arrangement` | `HStack` with explicit `.frame(width:)` per column (FoodEntropy `ec0069f` shape) / `ArrangementView .split.axes(.horizontal)` (FoodEntropy `248c804` shape) |
| `-view` | `sticky` / `fixed` / `none` | `intrinsicContentSize` = widest width it has been laid out at / fixed 120×50 / `noIntrinsicMetric` |
| `-fit` | `0` / `1` | `UIViewRepresentable` implements `sizeThatFits` returning `proposal.width` |
| `-start` | `0` / `1` | start in one column then switch / start in two columns (control) |

`ArrangementView` decides split vs single from its own aspect ratio, so the probe switches it by changing its outer frame from tall to wide. **The single-column frame must be wider than the two-column primary**, or the view never goes through "wide then narrow" — the first version used `0.6 × side` (401pt vs 456pt) and measured nothing.

Output columns: `intoOther` = width of the probe view overlapping the other column; `offScreen` = width past the window's right edge. **Do not measure against the home column's own frame**: an overflowing view stretches that frame too, and the first version reported `overflow=0` while the screenshot plainly showed the view covering the left column.

## Run

```bash
cd Experiments/SizeThatFitsProbe && xcodegen generate
xcodebuild build -scheme SizeThatFitsProbe -destination 'id=<UDID>' -derivedDataPath /tmp/stf
xcrun simctl install <UDID> /tmp/stf/Build/Products/Debug-iphonesimulator/SizeThatFitsProbe.app
for c in hstack arrangement; do for v in sticky fixed none; do for f in 0 1; do for st in 0 1; do
  xcrun simctl launch --console-pty <UDID> com.probe.SizeThatFitsProbe -container $c -view $v -fit $f -start $st | grep RESULT
done; done; done; done
```

Use the UDID, not the device name (see `ViewSplitProbe/README.md` on same-named simulators).

## Result (2026-10-07, Xcode 27.1 RC 27A9275)

**Exactly one cell overflows: `sticky × fit=0 × start=0`.** Every other combination — fixed or absent intrinsic size, `sizeThatFits` present, or starting in two columns — measures `intoOther=0 offScreen=0`.

| Device | Container | `sticky`, no `sizeThatFits`, transition | same, `sizeThatFits` | same, start in two columns |
|---|---|---|---|---|
| iPhone Duo inner, iOS 27.1 (951pt) | `hstack` | view w=835 in a 434 column: **intoOther 201, offScreen 117** | 0 / 0 | 0 / 0 |
| iPhone Duo inner, iOS 27.1 | `arrangement` | home column **stretched 456 → 603**: **intoOther 92** | 0 / 0 | 0 / 0 |
| iPhone 18 Pro, iOS 27.0 (402pt) | `hstack` | **intoOther 84, offScreen 85** | 0 / 0 | 0 / 0 |

Conclusions:

- **Not AdMob-specific.** A plain `UIView` whose intrinsic width follows its laid-out width reproduces both of FoodEntropy's symptoms — the stretched column under `ArrangementView` and the self-overflow under `HStack`.
- **Not Duo-specific.** It reproduces on a non-foldable iPhone on iOS 27.0. Duo merely makes the trigger (a runtime width shrink) routine.
- **Not every UIView.** Fixed or absent intrinsic size is safe in every combination, which is why the rule is scoped to self-growing views rather than "every `UIViewRepresentable`".
- **SDK control not run.** Only Xcode 27.x was installed at the time; whether an older linked SDK behaves differently is unmeasured.

Raw output:

```
# iPhone Duo (87020E73…), iOS 27.1 — hstack
container=hstack view=sticky fit=0 start=0 screen=951 other=[x=0 w=434] homeCol=[x=217 w=867] view=[x=233 w=835] intoOther=201 offScreen=117
container=hstack view=sticky fit=0 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=sticky fit=1 start=0 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=sticky fit=1 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=fixed fit=0 start=0 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=fixed fit=0 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=fixed fit=1 start=0 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=fixed fit=1 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=none fit=0 start=0 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=none fit=0 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=none fit=1 start=0 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
container=hstack view=none fit=1 start=1 screen=951 other=[x=0 w=434] homeCol=[x=434 w=434] view=[x=450 w=401] intoOther=0 offScreen=0
# iPhone Duo, iOS 27.1 — arrangement (single-column frame 0.95 × side)
container=arrangement view=sticky fit=0 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=603] view=[x=16 w=571] intoOther=92 offScreen=0
container=arrangement view=sticky fit=0 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=sticky fit=1 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=sticky fit=1 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=fixed fit=0 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=fixed fit=0 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=fixed fit=1 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=fixed fit=1 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=none fit=0 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=none fit=0 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=none fit=1 start=0 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
container=arrangement view=none fit=1 start=1 screen=951 other=[x=496 w=372] homeCol=[x=0 w=456] view=[x=16 w=424] intoOther=0 offScreen=0
# iPhone 18 Pro (791F5215…), iOS 27.0 — hstack
container=hstack view=sticky fit=0 start=0 screen=402 other=[x=0 w=201] homeCol=[x=100 w=402] view=[x=117 w=370] intoOther=84 offScreen=85
container=hstack view=sticky fit=0 start=1 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=sticky fit=1 start=0 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=sticky fit=1 start=1 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=fixed fit=0 start=0 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=fixed fit=0 start=1 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=fixed fit=1 start=0 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
container=hstack view=fixed fit=1 start=1 screen=402 other=[x=0 w=201] homeCol=[x=201 w=201] view=[x=217 w=169] intoOther=0 offScreen=0
```
