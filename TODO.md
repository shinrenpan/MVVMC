# TODO

Pending work tracker. Not part of the spec — see `CLAUDE.md` for the architecture rules.

## Next up (after v2.2.0)

- [x] ~~**Module-default `@MainActor`**~~ — **settled 2026-08, rationale replaced 2026-09: keep annotating explicitly.**
  The original reason ("the skills travel to projects whose build settings you don't control") **was demolished in 2026-09** by a shipped project that *is* one of those projects and had enabled the setting deliberately. The replacement reason is stronger and comes from a project with a widget extension: **`SWIFT_DEFAULT_ACTOR_ISOLATION` is per-target, and sharing source files across targets is the norm once you have an extension.** A file compiled by two targets cannot have its default isolation decided outside the file — the same line would mean two things and nothing in the file says so.
  What also changed: the skill now **branches by task mode** (generate / review / refactor) instead of stating one rule, because reviewing a project that *has* enabled it with the old wording produced a batch of false findings. Rationale in `mvvmc-viewmodel`〈強制宣告〉; the demo deliberately leaves the setting off.
  **Re-open condition** (checkable on the spot): a project appears that shares no source files across targets *and* whose `nonisolated` annotation count exceeds its `@MainActor` count — `grep -c` both in that repo.
- [x] ~~**`withMainSerialExecutor` in `mvvmc-testing`**~~ — **settled 2026-08: not adopting.** Tests that inject through `.apiResponse` are already deterministic, and the one flaky-prone category (a ViewAction that chains into a real request) is excluded at source by 〈什麼值得測試〉. A permanent dependency for a hypothetical benefit. Rationale written into `mvvmc-testing`〈設計哲學〉; revisit if real flakiness ever appears.
  **Measured 2026-09-22** (Xcode 27, iPhone 18 Pro): the whole suite is **1.013 s** — 18 tests, 16 of them at ~0.011 s, and the two that reach the fake API (`didFilterUser`, `clearFilter`) at 1.012 s each, which is the `Task.sleep(for: .seconds(1))` in `PostListViewModel+APIs.swift` and nothing else. Re-run: `xcodebuild -project MVVMCDemo.xcodeproj -scheme MVVMCDemo -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test CODE_SIGNING_ALLOWED=NO`. This retires the *speed* argument for introducing an injection seam at `handleAPIRequest`, which is the form the question took when it came back on 2026-09-22 from an external write-up (Shopify's Helix, "tests from minutes to milliseconds"). **There are no minutes here to save.** A seam would still be arguable on other grounds — determinism is already covered above, so what is left is offline CI and cross-page flows — but none of those is the argument that was made, and per axis 0 an external write-up is a source of questions, not of rules. The re-open condition is unchanged: real flakiness, or a field report with a re-runnable command.
- [x] ~~**Verify `@concurrent` declaration form**~~ — done 2026-08 on Swift 6.3.1: `@concurrent func` (member and top-level) compiles, `Task { @concurrent in }` compiles, but `nonisolated @concurrent func` fails to parse (`@concurrent` already implies nonisolated). Recorded in `swift-concurrency` SKILL.md.

- [x] ~~**Demo coverage gaps / 規範成長超過 demo**~~ — **settled 2026-08: the spec is allowed to reach further than the demo.** The six demo features cover every structural rule; the remaining ❌ are scenario rules (pagination, forms, polling, deep return), and stuffing those into the demo would trade clarity for coverage. They are verified through `Experiments/GenerationProbe/` instead — five features built from the spec alone, each typechecked under Swift 6. Stated at the top of `SPEC-COVERAGE.md`, so ❌ now reads "not in the demo" rather than "never checked".

- [x] ~~**Skip × V-layer Action Pattern**~~ — **2026-09-17 移出本 repo。** `mvvmc-skip` 已刪除，所以本 repo 不再有「驗證後寫進哪裡」的終點；Skip 的知識現在只住在 [`MVVMC-Skip`](https://github.com/shinrenpan/MVVMC-Skip)，未解的 `send` 形狀問題已記在那邊的 Open Questions。**這條留成墓碑而不是直接刪，是為了讓「為什麼 TODO 裡沒有任何 Skip 項目」查得到答案。**

- [ ] **規範變更不會傳播到已上架專案，而 consumer 清單沒有涵蓋它們** — `CLAUDE.md`〈Maintaining the Spec〉列的 consumer（skills、review skill、`TODO.md`、`SPEC-COVERAGE.md`、兩份 README、demo、probes）**全部 grep 得到**；上架專案 grep 不到，所以「什麼在讀這個？」對它們永遠是零命中。2026-09-17 的實例：`mvvmc-view` 規則 5 的 `@MainActor (Action) -> Void` 於 **2026-08-13**（`798906a`）進規範，`FoodEntropy` 的 `SettingsView` 三個 `send` 宣告寫於 **2026-07-23**，至今仍是舊形狀。**那三個是漂移不是違規**——同檔 `BucketListView.ExtendSheet` 於 2026-09-16（規範之後一個月）新寫的那個才是真的漏，兩者要分開看，這正是「開單前先用 git 日期比對」的案例。要決定的是：規範改動要不要有「通知已上架專案」的動作，還是接受漂移、只在各專案自己跑 review 時才發現。**先不要加機制**——軸 0 的教訓是釘版那次。

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

**One real conflict in the demo, not the spec — done 2026-10-07.** `AppRouter.deeplink()` walked `UIApplication.shared.connectedScenes…first?.keyWindow`; Apple's `app-resizability` rule 11 forbids it and prescribes the fix used: `deeplink(_:in scene: UIWindowScene)`, scene taken from each entry point (`openURLContexts`, `willConnectTo`, `response.targetScene`). Deferred on 2026-09-11 as latent; iPhone Duo (first iPhone with multiple scenes) was the trigger to do it in its own round. Demo rebuilt, 18 tests pass, template re-diffed against `Sources/App/` (identical), cold/warm URL deeplinks run by hand on the iPhone Duo simulator (iOS 27.1). **One thing the plan did not foresee:** carrying `response` into `Task { @MainActor in }` is a Swift 6 error (`UNNotificationResponse` is not `Sendable`) — extract `targetScene` first. Written into `mvvmc-navigation`.

  **Cold-start push measured 2026-10-07** (iPhone Duo outer display, iOS 27.1 simulator, app terminated, `simctl push`, tapped from the lock screen): routed to Post 2 correctly. That matters because `UNUserNotificationCenter.h:99` says *"The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:"*, and the demo sets it later, in `willConnectTo`. The contract is violated and nothing observable breaks — **on the simulator**. Not changed: no observed failure, and the entry gate does not admit a rule for one. Re-open on a device report of a lost cold-start tap.

  **Multi-scene is not actually pinned by any rule** — `UIApplicationSupportsMultipleScenes: false` appears only as the demo's config inside a YAML example. After `deeplink(_:in:)` the one known multi-scene hazard left is that `UNUserNotificationCenter.delegate` is **`weak`** (same header, line 42): each scene's `SceneDelegate` overwrites it, and closing the scene that set it last leaves push taps unhandled until another scene connects. Setting it once in `AppDelegate` would fix both this and the timing contract above. **Unmeasured** — needs the demo flipped to multi-scene and a second window opened by hand. Do it when a project actually enables multi-scene.

  **Still open from the same line of thought:** `UIApplicationSupportsMultipleScenes: false` stays pinned. Not verified: a second scene *of the demo itself* — the manual run had Safari beside the demo, which is two apps, not two scenes. Also unexamined: Apple's `scene-lifecycle-task.md` lists push notifications under "stays in AppDelegate", while the demo sets `UNUserNotificationCenter.current().delegate` in `SceneDelegate` — with several scenes, each would overwrite it. `targetScene` makes routing correct either way, so this is a question, not a defect.

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

## iPhone Duo (foldable) — unblocked 2026-10-07, measuring

**解除條件已達成（2026-10-07）**：Xcode 27.1 RC（27A9275）本機在、`simctl` 有 iOS 27.1 runtime（24A94232）與 iPhone Duo。第一個落地的是 Router（見上方 `deeplink(_:in:)`）。以下素材**仍然不是規則**，進規範要過 `Experiments/README.md` 的 entry gate。

### Demo 在 Duo 模擬器上的手動實跑（2026-10-07，iOS 27.1 / 24A94232，Xcode 27.1 RC 27A9275，`deeplink(_:in:)` 版）

使用者手動操作、截圖確認。**全部通過，demo 不需要為 Duo 改任何程式**：

- 外螢幕冷啟動：列表正常；tab bar 自動變直、在狀態列下方；內容不壓狀態列／鏡頭。
- 外螢幕詳細頁 → 打開：停在同一頁（不重建），返回鈕移到右側直欄（27.1 垂直 nav bar），返回正常。
- 內螢幕開 Settings sheet（`.medium`/`.large` detents）→ 闔上：sheet 存活，關閉正常。內螢幕 sheet 置中、toolbar 橫向。~~差別可能是 sheet 高度~~ **已量（同日 A/B，外螢幕 Settings sheet）**：只有文字的 `Button("關閉")`／`.topBarLeading` 在半高與全高**都維持橫向**、從未消失；改成 `Button("關閉", systemImage: "xmark")`／`.cancellationAction` 後，半高是橫向（移到右上），**全高變成右側直欄**。要直排得同時滿足「有圖示」與「sheet 全高」。Apple DocC／HIG 說只有文字的按鈕永遠不直排；SDK header（`UIBarButtonItem.h:76`）說只支援橫向的按鈕在沒有橫向 bar 時**不顯示**——這個消失情境本次沒觀察到。demo 改用 B 的寫法（與 `PostFilterView` 已用的 `.cancellationAction` 一致），**不寫成規則**：這是設計取捨，不是架構。
- URL 冷／熱啟動與推播點擊（`response.targetScene`）三個進入點都導到正確頁面。
- 非架構觀察：內螢幕上內文單行橫跨全寬並越過折線——V 層 readable width 的問題，不是規則。
- **外螢幕遵守 `supportedInterfaceOrientations`，內螢幕不理會**（FoodEntropy 實測，兩邊成對照）：FoodEntropy 只宣告 Portrait → 闔上後旋轉介面不轉；demo 沒宣告（iPhone 預設含橫向）→ 闔上後旋轉介面跟著轉、tab bar 移到右側直欄，compact/compact 矮版面——一般 iPhone 橫向也是如此，非 Duo 特有。
- **原則 11 的另一個落點（開放問題）**：FoodEntropy `BannerAdView.keyRootViewController()` 在 `UIViewRepresentable` 內以 `connectedScenes … isKeyWindow` 取 rootVC 交給 AdMob。`mvvmc-navigation` 新寫的那條只管 `deeplink()`；第三方 SDK 橋接要一個 VC 時怎麼取（例如在 `didMoveToWindow` 讀 `window?.rootViewController`）**沒有規範也沒有實測**。單一 scene 下是潛在而非現行錯誤；demo 沒有這種橋接，要寫規則得先有可編譯的形狀。
- **沒測到**：demo 自己的第二個 scene（`UIApplicationSupportsMultipleScenes: false`；使用者測的是 Safari 與 demo 並排，兩個 app）；半開（折線 active）姿態；內螢幕旋轉。

### FoodEntropy 帶回的素材（2026-10-07，跨 session，可重跑的附 branch／commit）

依據等級照原樣保留：**實測** = FoodEntropy 在 Duo 模擬器跑過；**文件** = 只有 Apple 文件／Tech Talk；**二手** = 第三方整理，引用前要對回原文。

- **`sizeThatFits` — 已寫入 `mvvmc-view` 規則 15（2026-10-07）**。`Experiments/SizeThatFitsProbe` 以自製 UIView 重現兩種症狀，iOS 27.0 的一般 iPhone 也重現——不是 AdMob 特有、也不是 Duo 特有；範圍收在「自報寬度跟著長」的 view（固定／不自報者 probe 量到全為 0）。以下為當初的素材：包進 SwiftUI 的 AdMob `BannerView` 沒實作 `sizeThatFits` 時，**app 執行中由單欄轉兩欄**（Duo 內螢幕直向冷啟動 → 轉橫向）會出事；冷啟動直接橫向不會。症狀依容器不同：`ArrangementView` 整欄被撐歪（home 寬停在 669、被蓋 236pt，frame 直讀，`248c804`）；HStack + `.frame(width:)` 欄位正確但 view 本身溢出、蓋進鄰欄 123pt（直讀，`ec0069f`）。GoogleMobileAds **13.7.0 與 13.11.0（官方宣稱支援 Duo）皆重現**。加 `sizeThatFits` 後：ArrangementView 重疊 0（直讀）、HStack 無溢出（**僅截圖**）。**缺口：只量過一種 view。** 下一步是 `Experiments/` 用自製、intrinsicContentSize 隨寬度變的 UIView 重跑；重現 → 範圍寫「所有自報尺寸的 UIView」，不重現 → 收窄成「執行中改變自身尺寸的第三方 SDK view」。
- **「Pane 容器」提案（未成立）**：FoodEntropy 目前在 V 層組合（Home 的 HC 持有 SettingsViewModel、代處理設定的 `onRoute`、`SettingsView` 帶 `isEmbedded`）。提案是 C 層容器把兩個完整 feature HC 當 child。**反例（實測）**：從設定欄開 pageSheet 後直接闔上，sheet 存活並在外螢幕轉全螢幕——因為 presenter 是 Home HC、收合時仍在畫面上；容器版設定 pane 是 presenter，收合時被移除，sheet 很可能跟著消失（**推論，未測**）。所以「外層 HC 代處理內嵌 feature 的 onRoute」可能是正確歸屬、只是寫法（`static handle(_:from:)`）不對。容器同時會撞上 `deeplink(.navigate)` 的 `selectedViewController as? UINavigationController` cast。**容器與「外層代處理」要在 demo 並排做出來比較，才談得上規則。**
- **Apple 的三層版面優先序（文件／二手）**：① 標準容器（`NavigationSplitView`／`UISplitViewController`／`TabView`）→ ② `ArrangementView` → ③ 自己排版＋`reservedRegions`。引文來源是 Anton Gubarenko 整理的 forums Q&A（二手）與 Tech Talk 111463。FoodEntropy 三層的落選理由（實測）：① `UISplitViewController` column 樣式收合時把 secondary 推到 primary 的 stack 上，與「首頁是 stack root」衝突；classic delegate 寫法在 iOS 27 SDK 斷言 crash ② `.split` 無指定 primary 邊的 API（27.1 SDK 比對）③ 採用 GeometryReader + HStack + `reservedRegions(kind: .division, options: .includeInactive)`。**開放問題：① 落選的原因是 MVVMC 的 Router 假設，不是 Duo。** Router 是否該接受系統容器的收合，是比 Pane 容器更上游的一題。
- **事實（FoodEntropy 實測，二手數字，引用前重量）**：iOS 27.1 模擬器 runtime 只支援 iPhone Duo；內螢幕不理會 `supportedInterfaceOrientations`，直橫都是 regular/regular；折線 reserved region 寬度固定（量到 40pt），平放 off、任何彎曲 on；arrangement 環境值（`splitArrangementAxis` 等）只有子 view 讀得到，root 讀到預設值；常駐 pane 不再觸發 `onAppear`。
- **不收**：「版面判斷寫成純函式來測」——好做法，但 `mvvmc-testing` 管的是 ViewModel；「姿態改變不可重建 identity」——來源是第三方 PR（`sven-ericmolzahn/iphone-duo-skill` #8），且 `if` 換 identity 是 SwiftUI 基本語意，`mvvmc-view` identity 段已涵蓋。

### 舊段落（2026-09-11，模擬器到位前的研究）

> ⚠️ **2026-10-07 對照官方網頁與 27.1 RC SDK 後，下列說法已過時或錯誤**：「27.1 摺疊 API 一條都還沒發布」——全部都在 27.1 SDK（`ArrangementView`、`UIArrangementViewController`、`UISplitArrangement`、`reservedRegions(kind:options:)`、`UIHingeInteraction`、`verticalBarEdge`、`preferredVerticalBarBehavior`、`UIBarButtonItem.axisBehavior`、`toolbarVerticalBehavior`）；「等 27.1 的只是排成垂直的呈現」——`axisBehavior` 等是新 API；「舊 SDK 照跑、熟悉尺寸」——現在分三級（SDK 26 置中留白／27 填滿大部分／27.1 滿版＋垂直 bar）；「demo 無 TabBar」——demo 根就是 `UITabBarController`；「五支 Tech Talk」——是 111461–111466 七支加 Group Labs。sheet 擺放 API（`preferredPlacement`／`presentationPlacement`）確為 **27.0** 不是 27.1。

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
- ~~**Still recorded against Swift 6.3.1 / Xcode 26.4.1**, not re-run: `mvvmc-view/references/architecture.md`'s `@Bindable` `$`-placement note.~~ — **re-run 2026-09-16 on both toolchains (6.3.1 / iOS SDK 26.4 and 6.4 / iOS SDK 27.0, `-target ios17.0-simulator`): behaviour identical, the note's advice stands.** What was wrong was the *quoted diagnostic*: the note cited `cannot convert value of type 'VM' to expected argument type 'Bindable<VM>'`; the compiler actually says `cannot convert value 'bVM' of type 'VM' to expected type 'Bindable<VM>', use wrapper instead` — on 6.3.1 too, so this was a mis-transcription from the start, not SDK drift. **A quoted error string is a claim like any other, and it is the kind nobody re-reads** — it only fails the person who greps for it. This one cannot be moved into a test (it asserts code that must *not* compile), so the stamp now names both toolchains rather than one.
  - ~~`mvvmc-testing/references/patterns.md`'s three examples~~ — **closed 2026-09-11 by removing the need for the check rather than performing it.** They now live in `Tests/SwiftTestingTechniqueTests.swift` and run under every `xcodebuild test` (18 tests / 4 suites green on Xcode 27.0 / Swift 6.4). The general move: **a claim that needs periodic re-verification should be turned into something that verifies itself, not scheduled.** A stamp expires silently; a test in the target cannot.
- **Language-feature version labels re-dated (2026-09-16).** Three labels in `swift-concurrency/SKILL.md` said 6.3; two were wrong. `~Sendable` is **6.4** (6.3.1 refuses it outright: `'~Sendable' requires -enable-experimental-feature TildeSendable`). The unhandled-throwing-`Task` warning is **6.4** (6.3.1 is silent; 6.4 emits `#NoUseUnstructuredThrowingTask`). Region-based isolation is **the Swift 6 language mode**, not 6.3 — gated by `SWIFT_VERSION`, not by toolchain version — and was stale in three places including `mvvmc-view/references/architecture.md`, which had copied the wrong number. `weak let` compiles on 6.3.1, so that one stands.
  - **Dating a feature without chasing release notes**: `swiftc -swift-version 6 -enable-upcoming-feature <Name>` makes the compiler state its own baseline — `upcoming feature 'RegionBasedIsolation' already enabled as of the Swift 6 language mode`. Two toolchains on disk (`Xcode-26.4.1` = 6.3.1, `Xcode-27.0.0-RC` = 6.4) bracket everything else by `DEVELOPER_DIR` swap.
  - **The trap that invalidated the first attempt**: an *unrecognised* `-enable-upcoming-feature` name is **silently ignored** — `BogusFeatureXYZ` produces no diagnostic at all. So "it compiled with the flag on" proves nothing, and neither does a probe whose snippet compiles with the flag off. **Run the bogus-name control before reading anything into a feature probe.**
