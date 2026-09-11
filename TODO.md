# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [x] ~~**Module-default `@MainActor`**~~ — **settled 2026-08, rationale replaced 2026-09: keep annotating explicitly.**
  The original reason ("the skills travel to projects whose build settings you don't control") **was demolished in 2026-09** by a shipped project that *is* one of those projects and had enabled the setting deliberately. The replacement reason is stronger and comes from a project with a widget extension: **`SWIFT_DEFAULT_ACTOR_ISOLATION` is per-target, and sharing source files across targets is the norm once you have an extension.** A file compiled by two targets cannot have its default isolation decided outside the file — the same line would mean two things and nothing in the file says so.
  What also changed: the skill now **branches by task mode** (generate / review / refactor) instead of stating one rule, because reviewing a project that *has* enabled it with the old wording produced a batch of false findings. Rationale in `mvvmc-viewmodel`〈強制宣告〉; the demo deliberately leaves the setting off.
  **Re-open condition** (checkable on the spot): a project appears that shares no source files across targets *and* whose `nonisolated` annotation count exceeds its `@MainActor` count — `grep -c` both in that repo.
- [x] ~~**`withMainSerialExecutor` in `mvvmc-testing`**~~ — **settled 2026-08: not adopting.** Tests that inject through `.apiResponse` are already deterministic, and the one flaky-prone category (a ViewAction that chains into a real request) is excluded at source by 〈什麼值得測試〉. A permanent dependency for a hypothetical benefit. Rationale written into `mvvmc-testing`〈設計哲學〉; revisit if real flakiness ever appears.
- [x] ~~**Verify `@concurrent` declaration form**~~ — done 2026-08 on Swift 6.3.1: `@concurrent func` (member and top-level) compiles, `Task { @concurrent in }` compiles, but `nonisolated @concurrent func` fails to parse (`@concurrent` already implies nonisolated). Recorded in `swift-concurrency` SKILL.md.

- [x] ~~**Demo coverage gaps / 規範成長超過 demo**~~ — **settled 2026-08: the spec is allowed to reach further than the demo.** The six demo features cover every structural rule; the remaining ❌ are scenario rules (pagination, forms, polling, deep return), and stuffing those into the demo would trade clarity for coverage. They are verified through `Experiments/GenerationProbe/` instead — five features built from the spec alone, each typechecked under Swift 6. Stated at the top of `SPEC-COVERAGE.md`, so ❌ now reads "not in the demo" rather than "never checked".

- [ ] **Skip × V-layer Action Pattern** *(blocked: 需要有 Android target 的專案才能實測，非「還沒想」)* — `mvvmc-skip` 眉角 #6（巢狀 enum 在 Kotlin 要完整限定）目前只涵蓋 `doAction(.view(...))`。V 層的 `send(.rowDidTap)` 同樣是巢狀 enum 的 leading-dot 呼叫，理論上也會踩到，且 `send` 現在的型別是 `@MainActor (Action) -> Void`（Skip 如何轉譯 global-actor 隔離的函式型別未知）。**需要有 Android 目標的專案實測後才寫進 skill**——沒驗證過的規則不該進 skip，那份是實測筆記。

- [ ] **規範成長速度超過 demo** — `SPEC-COVERAGE.md` 現在有 **22 個 ❌ 對 15 個 🚫**（2026-09 那輪新增 20 列之後重數）。多數 ❌ 是 2026-08 生成測試補進來的**場景規範**（分頁、表單、輪詢、深層回傳、alert、樂觀更新），而 demo 六個 feature 完全沒有這些場景。需要決定走哪條路：(a) 擴充 demo 涵蓋主要場景，(b) 接受「規範涵蓋面大於 demo」並在 SPEC-COVERAGE 開頭講清楚這件事是刻意的。目前是預設 (b) 但沒有明講。

## Open — three measurements, all in `Experiments/ViewSplitProbe/`

Each decides the wording of a rule that is currently hedged. None is bug-level; all are cheap once the harness is open.

- [ ] **`Group` vs `VStack` as the `.task` mounting container** (four-state skeleton × polling). Two field reports gave **opposite** answers and neither had measured: `Group` may distribute modifiers to its children (landing `.task` back on the conditional it was meant to escape); `VStack` has its own identity but **changes the layout of both branches** — `ProgressView` wants centring, the list wants to fill. `architecture.md` §1 currently states both risks and points at a third path (`.task` on an outer container) rather than picking one.
- [ ] **`@State` misplacement in the shapes the reorder probe did not cover**: `id: \.self`, index-based `ForEach`, nested `ForEach`, animated reorder. §8's three claims did not reproduce for `Identifiable` + single-level `ForEach` + synchronous reorder, and the section is annotated as such rather than deleted — because those four shapes were never measured.
- [ ] **Does `Data` embedded in a Domain Model short-circuit on `==`?** Decides whether `mvvmc-model` Equatable exception 3's "hundreds of MB" threshold is right. If COW makes it a pointer comparison the threshold is correct and finally gets a *why* (it has none today); if not, the threshold is wrong.

## Open — carried over from the Xcode 27 agent-skills comparison (2026-09-11)

`xcrun agent skills export <dir>` (Xcode 27 only — the `agent` binary does not exist in 26.4.1) emits **ten** skills, not the seven the third-party write-ups list. Three of them were read against this spec in full. What that comparison produced is below; the one thing it actually **broke** — §7's table having been measured without the mandated `send` closure — is already fixed and recorded in `Experiments/ViewSplitProbe/README.md`.

**Two things the export does that matter more than its contents:**

- It is a **snapshot, not a link** (plain read-only files with a fresh mtime). Upgrading Xcode does not update an exported copy, and `agent skills` has only an `export` subcommand — no version, no diff. Any adoption needs a "re-export after an Xcode upgrade" step or it becomes exactly the consumer-drift shape this repo keeps paying for.
- `swiftui-specialist` declares itself as superseding prior training on ForEach identity, `@Observable` invalidation, localization, and soft-deprecated APIs — **the same triggers as `mvvmc-view`**. Installing it into `~/.claude/skills/` without first deciding rule ownership creates a fifth drift direction rather than closing one. (Also: the widely-cited `~/.agents/skills` path is not read by Claude Code here; `~/.claude/skills/` is.)

**Conflicts worth a decision (none is bug-level):**

- [ ] **`@ViewBuilder private func` for section splitting — a deliberate divergence to document, not a defect.** Apple's `structure.md` says always factor a section into its own `View` type, never a computed property *or* a `@ViewBuilder` helper. `mvvmc-view` bans computed properties but allows the helper. **This is not the self-contradiction it first looked like**: rule 10 states plainly that `@ViewBuilder func` 「只換來可讀性」, §7 measures it (`B body = 1`, the unrelated section re-runs), and the decision criteria then *recommend* it for static sections specifically to avoid a `struct`'s boilerplate cost. The spec is internally consistent and is making a cost trade-off Apple does not. Decide whether to keep the trade-off and cite Apple beside it — do not "fix" it.
- [ ] **Localization typing.** Apple puts `LocalizedStringResource` (not `String`) on view models; MVVMC stores translated `String` in State. Note this does **not** collide with the global "don't pass `LocalizedStringKey` as a parameter" rule — different type, different failure.
- [ ] **`var state: State` as a single `@Observable` property.** Apple names this exact shape AVOID (per-property observation granularity). MVVMC already concedes the cost in `architecture.md` §7's ⚠️ block. Recommend keeping the shape and citing Apple there as external corroboration — but the concession should say it is a known trade-off *that Apple documents*, not an unexamined one.

**Pure gaps — Apple has concrete rules where MVVMC has none:**

- [ ] ForEach identity: `id: \.self`, `.indices`, `.enumerated().offset`, content-derived ids, expensive-to-hash ids (`foreach.md`). Overlaps the open `@State` misplacement measurement above.
- [ ] List fast path: unary rows only — no top-level `switch` or bare `if` in a row. `-LogForEachSlowPath YES` makes it checkable. **Scope this to `List` rows only.** `AnyView` is *not* an open gap: `mvvmc-deep-review` already covers it, measured under both the Xcode 26.4.1 and 27 SDKs, and reaches a **better-supported conclusion than Apple's blanket phrasing** — `AnyView`-wrapped children with unchanged props are still skipped, so the cost is unstable structural identity (broken animation, reset `@State`), not extra body runs. Apple's fast-path claim is about a different mechanism inside `List`; confirm it is actually a separate one before writing anything.
- [ ] `init` must be constant-time (`structure.md`). Most likely to be violated in C, where HostControllers are built.
- [ ] `Equatable` as a *performance* gate — the `@Observable` setter skips invalidation only for Equatable types. `mvvmc-model` justifies Equatable only via tests and `onChange`.
- [ ] C layer: `window.windowScene.screen`, never `window.screen`; V layer must use `@Environment(\.displayScale)` / `GeometryReader`, never `UIScreen`; `prefersInterfaceOrientationLocked` (iOS 26+) — the spec has no orientation rule at all.
- [ ] AppDelegate vs SceneDelegate responsibility split, and Apple's "migrate the four lifecycle methods as a set, not individually".
- [ ] Testing: `@Suite(.serialized)` — the word appears nowhere in `.claude/skills/`, although `Experiments/ViewSplitProbe/README.md` records this repo being burned by exactly that, with a contaminated measurement reaching the spec. **Exposure is narrower than that history suggests**: the invariant tests `mvvmc-testing` actually recommends (scan the String Catalog, scan source) only *read* files and are safe in parallel. The vulnerable shape is global mutable test state — which is what the probe has and what the spec never asks for. So this is worth one sentence naming the hazard, not a new rule. Also missing: `withKnownIssue`, `.disabled(if:)`, `Attachment.record(value)`.

**One real conflict in the demo, not the spec:**

- [ ] `AppRouter.deeplink()` reads `UIApplication.shared.connectedScenes…first?.keyWindow` (`Sources/App/AppRouter.swift`). Apple's rule 11 forbids walking global scene state and prescribes exactly the fix this case needs — *add a parameter*: `deeplink(_:from scene:)`. All three SceneDelegate entry points already hold a scene; `AppRouter.swift`'s own comment admits the caller 「手上只有 window」 while the callee reaches back out to the global list. Stateless Router is unaffected and the `.first` multi-window mis-target disappears with it.

  **Ready to do — deliberately not done in the round that found it (2026-09-11).** It is latent, not live: the spec pins `UIApplicationSupportsMultipleScenes: false`, so `.first` cannot currently pick the wrong window. Against that, it changes the Router's signature, which forces `navigation-templates.md` to regenerate, a `SPEC-COVERAGE.md` row to move, and every downstream project to re-read the rule. **That round had just spent itself cleaning up drift created by a hurried API change three days earlier** — shipping a second signature change in the same sitting is the behaviour that produced the mess, not the fix for it. Do it in its own round, with the demo rebuilt and the template check re-run in the same pass.

  When picking it up: `deeplink(_:from scene: UIWindowScene)`, resolve `rootViewController` from `scene.keyWindow`, update the three call sites in `SceneDelegate.swift`, regenerate the template, and move the `SPEC-COVERAGE.md` Navigation row. The exemption in `mvvmc-review` does not need touching — it is about method *names*, not signatures.

**Settled the same day — `@ViewBuilder` does NOT need renaming to `@ContentBuilder`.** Apple's `swiftui-whats-new-27` documents a "ContentBuilder unification", which reads like a migration. It is not one. The iOS 27 SDK spells it out (`SwiftUICore.swiftinterface:8598`):

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public typealias ContentBuilder = SwiftUICore.ViewBuilder
```

**They are the same type.** `ViewBuilder`'s own declaration carries no `deprecated:` attribute, and the alias back-deploys to iOS 13. Renaming every `@ViewBuilder private func` in the spec would be a no-op edit of a type alias — **do not do it, and do not let the "unification" wording talk anyone into it later.**

What *did* change is the type-checking model behind that one type: builders no longer constrain block contents to conform to `View`, so `buildBlock()` now yields `EmptyContent` / `TupleContent` instead of `EmptyView` / `TupleView`. That switch is tied to the **linked SDK, not the spelling** — it lands the moment a project rebuilds with Xcode 27, whichever attribute name the source uses. Apple lists five ways it breaks the build:

| Shape | Symptom |
|---|---|
| `.overlay(Color.blue.opacity(0.7))` as a direct argument rather than a trailing closure | `ambiguous use of 'opacity'` |
| Another module declaring a type that shadows a SwiftUI one (its own `Color`, `Text`, …) | `ambiguous use of 'red'` |
| `TupleView<…>` hard-coded in a nested generic parameter | type mismatch; use `TupleContent` |
| An empty builder body (or a `#if` with no `#else`) in a target that has MapKit | `EmptyMapContent` does not conform to `View` |
| Swift Charts with ~10+ branches **and a deployment target below 27** | `unable to type-check this expression in reasonable time` |

The demo hits none of the five (it builds clean under Xcode 27). **The last row is the one that matters here**: it fires only when back-deploying, and MVVMC's baseline is iOS 17 — so any project on this spec that uses Swift Charts with a wide `switch` is exposed. The fix is to lift the branches into an `@ChartContentBuilder` function. This belongs with the two `Info.plist` launch/submission blockers below: same class, same trigger, **"things to check when upgrading Xcode", not "things to check when starting a project."**

> ⚠️ **Four entries in this section were wrong when first written, and all four came from relaying a subagent's framing without re-deriving it.** `@ViewBuilder` was called a self-contradiction (the spec is consistent — rule 10, §7 and the decision criteria agree); `AnyView` was called an uncovered gap (`mvvmc-deep-review` covers it, with a *better*-evidenced conclusion than Apple's); `.serialized` was called a live trap (the invariant tests the spec recommends only read files). The corrections are in the entries themselves.
>
> The fourth is the one worth keeping as a warning. A `@MainActor` entry was filed reading "the headline is absolute, reword it" — but that question was **already `[x]` settled at the top of this very file**, with a re-open condition, a three-mode table in `mvvmc-viewmodel`, and a matching row in `mvvmc-review`'s exemption table. Filing it again created a second, weaker copy of a settled decision **inside the file that exists to track decisions** — precisely the failure `CLAUDE.md` opens with. It has been deleted.
>
> **A comparison against an external authority reads as authoritative, and that is exactly why every claim it produces has to be re-derived against this repo before being written down** — including a check that the question is not already answered here. Same standard the spec applies to its own measurements.

**Assessed and dismissed:** `adopt-c-bounds-safety` (no C), `app-intents-specialist` / `app-intents-whats-new-27` (no App Intents), `building-document-based-swiftui-applications` (no document app). `audit-xcode-security-settings` yields only Phase 1 + entitlements for a pure-Swift target, drives everything through Xcode's MCP tools, and writes pbxproj/xcconfig — **which XcodeGen overwrites on the next `xcodegen generate`**. `device-interaction` is genuinely complementary to `ios-build-run` (UI hierarchy with `hitPoint`, synthesized touch/keyboard, `commandLineArguments` without editing the scheme) and overlaps it only on build/install/screenshot — but it is a subagent skill driving `DeviceInteraction*` MCP tools, and `~/Library/Developer/Xcode/CodingAssistant/mcp-servers.json` is currently **empty**. Confirm the tools resolve before writing any of it into `ios-build-run`.

## Blocked on tooling — iPhone Duo (foldable)

**不要在 Xcode 27.1 模擬器到位之前把下面任何一條寫成規範。** 這些是研究素材，不是規則。裝置 2026-10 底發售、API 在 iOS 27.1、模擬器要 Xcode 27.1（官方頁面標 "Coming later this month"），**今天一條都驗不了**。把未經量測的前提寫成規則，正是 `Experiments/README.md` 開宗明義在防的事。

來源是 Apple 官方 Tech Talk 字幕軌（111461/111462/111463/111466）與 developer.apple.com，2026-09-11 取得。

**MVVMC 現況（已盤點，2026-09-11）**：`SceneDelegate` 用 `UIWindow(windowScene:)` 而非 `UIScreen.main`、demo 零個寫死 `.frame(width:/height:)`、無 orientation 鎖定——結構上乾淨。**但全部 11 個 skill 對 size class / trait collection / adaptive layout 零著墨**，這是主要暴露面。`TARGETED_DEVICE_FAMILY: "1"`（iPhone only）。

官方事實，備查：

- **舊 SDK 建的 app 照跑**，Apple 的用詞是「熟悉的尺寸與長寬比」，不是相容模式／黑邊。**linked SDK 本身就是開關，沒有 opt-in plist key。**
- **`UIRequiresFullScreen` 仍被尊重**，但擋不住開合造成的 resize。
- **`UISplitViewController` / `NavigationSplitView` / `UITabBarController` 全部 fully adaptive**：闔上時 column 收合成單一 stack，展開時 tiled 或 overlay。
- **五支 Tech Talk 沒有任何一處建議「展開時換容器」**——一致訊息是用標準 adaptive 容器讓它原地適配。這對「C 是唯一導航層」是好消息。
- **設計層硬要求**：不要把功能綁在某個開合姿態上；使用者會頻繁開合。
- **查幾何、不要監聽事件**。layout 的輸入是三項：size class、view 寬高比、有沒有 active division region（攤平時 division region 寬度為 0）。
- **`ArrangementView` 是排版容器不是導航容器**：禁止在其中放 `NavigationSplitView`，也不要放進 `List` / `ScrollView`。跟 MVVMC 的分層不衝突。iOS 27.1 起 app 可用系統提供的 arrangement。
- **會打到 AppRouter 的細節**：sheet 的 toolbar 軸向**內外螢幕相反**——外螢幕已有 toolbar 的 sheet 顯示為垂直，內螢幕預設置中且維持水平。Router 目前統一用 `.pageSheet`，V 層若對 toolbar 佈局有假設會歪。
- split view 中**只有 detail column** 參與垂直 bar；其他 column 維持水平。

### API 現況（2026-09-11 查證，本機 `iPhoneOS27.0.sdk` 為準）

**iOS 27.1 的摺疊 API 一條都還沒發布。** 這是**列舉證明不是搜尋失敗**：SwiftUI 完整符號索引（7,150 個）與 UIKit `Headers/` 全文比對，`arrangement`（除無關的 `windowArrangement`）、`hinge`、`reservedRegion`、`toolbarVerticalEdge`、`axisBehavior`、`fold`、`posture`、`duo`、`division` 全數 0 命中。`UIArrangementViewController`、`UISplitArrangement`、`UIViewReservedRegion`、`UIHingeInteraction`、`UITraitCollection.verticalBarEdge` 同樣不存在。

所以 `ArrangementView` / `.arrangementViewStyle` / `reservedRegions(kind:)` / `.onHingeChange` 這些名字**只來自 Tech Talk 的 code block**——沒有簽章、沒有 `@available`、沒有參考頁、沒有 sample code。**現在包 wrapper 等於照影片猜參數型別。**

**但有三組摺疊相關 API 是 iOS 27.0 就有的，今天就能寫**（下列簽章已在本機 typecheck 通過）：

| 用途 | API | 與 MVVMC 的關係 |
|---|---|---|
| **sheet 擺放** | `UISheetPresentationController.preferredPlacement`（`.automatic`/`.leading`/`.center`/`.trailing`）／SwiftUI `View.presentationPlacement(_:)` | **直接打到 `AppRouter` 的 `present` 路徑**，目前統一 `.pageSheet` |
| 內螢幕 sidebar | `UITabBarController.sidebar.preferredPlacement`／`View.defaultTabBarPlacement(_:)`（需搭 `.tabViewStyle(.sidebarAdaptable)`；**iPadOS 無效**） | demo 無 TabBar |
| 垂直 bar 的**內容優先序** | `UIBarButtonItem.visibilityPriority`／`ToolbarContent.visibilityPriority(_:)`、`ToolbarOverflowMenu`、`ToolbarItemPlacement.topBarPinnedTrailing`、`UINavigationItem.navigationBarMinimization` | 優先序現在就能標；等 27.1 的只是「排成垂直」的呈現 |

> ⚠️ **但 MVVMC 基準是 iOS 17，這三組全部要包 `if #available(iOS 27.0, *)`**——實測無 guard 時逐條報 `is only available in iOS 27.0`。**跟 `withTaskCancellationShield` 完全同一個形狀**：toolchain 有了、deployment target 擋著。在基準拉到 iOS 27 之前，這三組能不能實際採用是另一個決策，不是技術問題。
>
> 附帶更正一個既有誤解：111462 那套「請 adopt」的 bar API 多半**不是新的**——`leftItemsSupplementBackButton` 是 **iOS 5**，`leadingItemGroups` / `pinnedTrailingGroup` / `additionalOverflowItems` 是 **iOS 16**，`UIBarButtonItem.badge` 與 `UICornerConfiguration` 是 **iOS 26**。真正 27.0 才新增的只有 `visibilityPriority`、`ToolbarOverflowMenu`、`topBarPinnedTrailing`。

**查證方法的兩個坑**（下次重查時會再踩）：

- **UIKit 不能只 grep `.swiftinterface`**——那份只有 6,803 行純 Swift overlay，UIKit 絕大多數 API 由 ObjC header 宣告。`preferredPlacement` 在 `.swiftinterface` 是 0 命中、在 `Headers/*.h` 是 2 命中，本輪一度因此誤判成「不存在」。要 grep `$SDK/System/Library/Frameworks/UIKit.framework/Headers/`。
- **DocC 與 SDK 衝突時以 SDK 為準**。`UISceneAccessory` 的 Mac Catalyst 可用性：DocC 說 27.0 可用、SDK header 寫 `API_UNAVAILABLE(macCatalyst,...)`。編譯器讀的是 header。

**解除條件**：Xcode 27.1 釋出且 `xcrun simctl list runtimes` 出現 iPhone Duo。屆時先做的是**量測**（把 demo 放進 Duo 模擬器，開合各截一次），不是先寫規則。第二個可查的訊號是 `.swiftinterface` / `Headers/` 裡 grep 得到 `ArrangementView` 的真實簽章——**在那之前那批 API 的形狀字面上還不存在**，而「規則描述了一個不存在的形狀」正是這個 repo 記過的教訓。

## Environment notes

- Local toolchain: Swift 6.4 (Xcode 27.0 RC, 27A266a), Target arm64-apple-macosx26.0
- Host is **macOS 26.6.2**, not macOS 27 — Xcode was upgraded for the iOS SDK, the OS was not (Homebrew / third-party). Consequence: `Experiments/ConcurrencyProbe/` builds as a native macOS binary and therefore **cannot reach any `@available(anyAppleOS 27.0, *)` API**. The iOS 27.0 simulator runtime *is* installed, so the iOS side of such an API is testable; the macOS side is not.
- Swift 6.4 is GA in the toolchain, but its new APIs (e.g. `withTaskCancellationShield`) are gated `@available(anyAppleOS 27.0, *)` and so remain unusable at the iOS 17+ deployment target. The concurrency skill states this as an availability constraint, not as "not yet released".
- **Probes re-run on Xcode 27 (2026-09-10):** `ConcurrencyProbe` unchanged; `ViewSplitProbe` unchanged **except** the reorder rows, where a `@State`-holding child went `bodies=3` → `0`. Isolated to the **linked SDK** (same machine, same iOS 26.4 simulator, `DEVELOPER_DIR` swap), so it is not an iOS 27 story — a Xcode-27 rebuild gets the new behaviour on iOS 26 as well. Written into `mvvmc-view`〈拆與不拆的決策準則〉as an SDK matrix and into `ViewSplitProbe/README.md`. The `AnyView` finding (`mvvmc-deep-review`) re-measured identical on both SDKs.
- **Still recorded against Swift 6.3.1 / Xcode 26.4.1**, not re-run: `mvvmc-testing/references/patterns.md` (three examples said to compile in the demo test target — that target now builds clean under 27, so this is probably already covered; verify rather than assume) and `mvvmc-view/references/architecture.md`'s `@Bindable` `$`-placement note. Both are compile-behaviour claims, cheaper to check than the SwiftUI measurements.
