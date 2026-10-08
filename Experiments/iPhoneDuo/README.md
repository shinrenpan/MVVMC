# iPhone Duo — research record (2026-09-11 → 2026-10-08)

**This is a dated record, not a to-do list and not a spec.** It does not claim to describe the present, so it is not maintained and does not expire: when it disagrees with `.claude/skills/`, the skills win. What became rules is in the skills (each entry names its evidence); what is still actionable is in `TODO.md`. Everything else that the iPhone Duo round learned — official guidance, SDK diffs, FoodEntropy's field measurements, and the reasoning behind decisions — lives here so it can be read without being mistaken for work.

Probes from this round: `../SizeThatFitsProbe/`, `../VerticalBarProbe/`, `../PaneProbe/`.

## Router and push entry points

**One real conflict in the demo, not the spec — done 2026-10-07.** `AppRouter.deeplink()` walked `UIApplication.shared.connectedScenes…first?.keyWindow`; Apple's `app-resizability` rule 11 forbids it and prescribes the fix used: `deeplink(_:in scene: UIWindowScene)`, scene taken from each entry point (`openURLContexts`, `willConnectTo`, `response.targetScene`). Deferred on 2026-09-11 as latent; iPhone Duo (first iPhone with multiple scenes) was the trigger to do it in its own round. Demo rebuilt, 18 tests pass, template re-diffed against `Sources/App/` (identical), cold/warm URL deeplinks run by hand on the iPhone Duo simulator (iOS 27.1). **One thing the plan did not foresee:** carrying `response` into `Task { @MainActor in }` is a Swift 6 error (`UNNotificationResponse` is not `Sendable`) — extract `targetScene` first. Written into `mvvmc-navigation`.

  **Cold-start push measured 2026-10-07** (iPhone Duo outer display, iOS 27.1 simulator, app terminated, `simctl push`, tapped from the lock screen): routed to Post 2 correctly. That matters because `UNUserNotificationCenter.h:99` says *"The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:"*, and the demo sets it later, in `willConnectTo`. The contract is violated and nothing observable breaks — **on the simulator**. Not changed: no observed failure, and the entry gate does not admit a rule for one. Re-open on a device report of a lost cold-start tap.

  **Multi-scene is not actually pinned by any rule** — `UIApplicationSupportsMultipleScenes: false` appears only as the demo's config inside a YAML example. After `deeplink(_:in:)` the one known multi-scene hazard left is that `UNUserNotificationCenter.delegate` is **`weak`** (same header, line 42): each scene's `SceneDelegate` overwrites it, and closing the scene that set it last leaves push taps unhandled until another scene connects. Setting it once in `AppDelegate` would fix both this and the timing contract above. **Unmeasured** — needs the demo flipped to multi-scene and a second window opened by hand. Do it when a project actually enables multi-scene.

  **Still open from the same line of thought:** `UIApplicationSupportsMultipleScenes: false` stays pinned. Not verified: a second scene *of the demo itself* — the manual run had Safari beside the demo, which is two apps, not two scenes. Also unexamined: Apple's `scene-lifecycle-task.md` lists push notifications under "stays in AppDelegate", while the demo sets `UNUserNotificationCenter.current().delegate` in `SceneDelegate` — with several scenes, each would overwrite it. `targetScene` makes routing correct either way, so this is a question, not a defect.


## FoodEntropy field reports MVVMC does not cover (single project, below the entry gate)


- **量錯寬窄的對象**：量 HStack 自身會被固定欄寬撐住、退不回單欄 → 量外層提案（GeometryReader）；兩欄只給 `maxWidth: .infinity` 分配不穩定。
- **同一個「寬」判斷在 V、C 各寫一份會漂**，且兩邊量的尺寸不同（整個畫面 vs 扣導覽列）→ 單一出處。PaneProbe b4 把判斷收在容器是一種解。
- **常駐 pane 不再觸發 `onAppear`** → 回前景重讀改聽 `didBecomeActive`（UIKit 生命週期收不到 `scenePhase`），跨畫面狀態改聽資料層廣播。
- **被推入的頁面在姿態改變後自動退回**（設定頁翻開時已在左欄）→ `viewWillTransition` 轉場完成後經 Router `back`。
- 測試工具：`simctl openurl` 的系統確認框只在第一次出現。

## HerbMeet field report — always-on sheet ↔ two-column (2026-10-08, single project, below the entry gate)

HerbMeet is MVVMC with a **present-based** variant: the Map page keeps a `.sheet(isPresented: .constant(true))` open at all times, so every feature is presented fullScreen *on top of the sheet* (`AppRouter.present(_:from:)` walks `presentedViewController` to the top). Its Duo goal: inner-display landscape shows the sheet's content as a fixed left column and the map on the right; everything else unchanged. Advised from this repo over cross-session messages, implemented and measured there (Xcode 27.1 RC 27A9275, iOS 27.1, Duo simulator, user screenshots for every row).

- **Where the two columns live: V layer** (one View, one ViewModel — list and map share selection and scroll-to-selected), not a C-layer container. PaneProbe's "each pane a HostController" is for two *features*; this is one feature in two regions.
- **The hazard, measured before building**: with the sheet's `isPresented` driven by layout, rotating to landscape while a fullScreen modal sits on the sheet **dismissed the modal too** — UIKit dismissing a presenter takes everything above it. No VM close, no `onCallback`. The reverse (landscape → portrait with a modal up) was fine: SwiftUI retried presenting the sheet once the presenter was free. The guess that views under a fullScreen modal stop receiving size changes was **wrong** — MapView kept getting them.
- **Fix (measured working both directions, including a modal with one push in its nav)**: a C-layer gate — `isTwoPane = wants && !(sheetIsPresented && featureIsOpenAboveSheet)`, read from the UIKit tree on the next runloop; released by the Router's nav posting on `viewDidDisappear` + `isBeingDismissed`, **not** by `onCallback` (the measurement above shows it can be skipped). Sheet binding and left column read the same applied value, so the list never appears twice.
- **Identity**: the map keeps one structural position across modes (MKMapView not rebuilt; region, markers, selection kept). `.searchable` was kept off the layout switch by hosting it on a 0×0 sibling — works, relies on unguaranteed SwiftUI behaviour, commented to re-verify each iOS. The list is a new instance on every switch; `onAppear` scrolls to the VM's `selectedID`.
- `reservedRegions(kind: .division, options: .includeInactive)` with HStack: half-open puts the split on either side of the fold, flat splits evenly.
- **System bug (iOS 27.1 / 24A94232)**: unfolding straight from the outer display into inner **landscape** leaves SwiftUI toolbar buttons in the vertical bar blank and untappable until one rotation; reproduces with a single `topBarTrailing` icon button in a plain `UINavigationController`. Outer → inner portrait and inner → outer are fine. HerbMeet's workaround is `.id(horizontalSizeClass)` on the button (compact → regular on that transition forces a new one), commented with its removal test. Not reproduced here.
- `MKUserTrackingButton` pinned to `map.trailingAnchor` sat under the vertical bar; pinning to `safeAreaLayoutGuide` fixed it — the field instance of the asymmetric safe area measured in `../VerticalBarProbe` (Split View puts the bar on the **leading** side).
- **Split View (HerbMeet, same day)**: the divider **only rests at 50/50** — dragging past it closes the other app and returns to full screen, with no stop in between. So the inference sent from this repo — "an asymmetric split could give one side width > height and regular, tripping a landscape-based two-column check; use a width threshold with hysteresis" — **does not hold under Duo's current split rules**; re-evaluate if other ratios appear. Left half measured H=compact／V=regular, single column, bar on the left edge (layout size 385×499 vs. 867×553 R/R full screen — the map view's size, not the window's). A fullScreen modal open in split, dragged back to full screen, survived (the gate held on this entry too); folding in split and unfolding left the toolbar buttons working.
- **TestFlight follow-ups (1.5.0, `240f9f5`)**:
  - The two-column check measured the MapView's `onGeometryChange` size, which **the keyboard shrinks** (≈315pt tall in inner portrait → "width > height" → stayed two-column; 835 ↔ 510 on each keyboard toggle → layout flapped). `.ignoresSafeArea(.keyboard)` on a background measurer did not help; the C layer writing `view.window.bounds.size` in `viewDidLayoutSubviews` did. → refined the `mvvmc-model` advisory. **FoodEntropy measures an outer `GeometryReader` for the same decision and may have the same exposure — unchecked.**
  - **A system component rebuilt by a layout switch re-runs its activation side effect from its current state**: `.searchable` re-attached with `isPresented == true` activated itself and raised the keyboard; setting `.searchFocused` back to false afterwards had no effect (no focus change logged at all). Fix: clear `isPresented` when the window size changes, which precedes the layout switch. One project, stays here.
  - Unrelated to Duo: one-shot commands to a wrapped `UIView` deduped by value equality were silently dropped ("select A → drag map → select A" did nothing), present since 2026-07. → `mvvmc-view` rule 16 (reported).
- **iPad, one throwaway run (HerbMeet, 2026-10-08; `TARGETED_DEVICE_FAMILY` 1,2 on an experiment branch since deleted; iPad Pro 11-inch (M5), iOS 27.0 simulator; same check: R/R and window width > height from `view.window.bounds`)**: portrait full screen → single column, the always-on `.sheet` stays bottom-attached (width-capped and centred, not a form sheet); landscape → two columns. **Windowed Apps resize to any ratio**: smallest ≈510×660 → single column; wide-and-short ≈1640×660 → two columns. The minimum window height (≈660) is what bounds the narrowest two-column case at ≈330pt per column — **a system limit holding the check up, not the check itself**; 660–700pt widths not measured. So "Duo rests only at 50/50, no threshold needed" holds for Duo; on iPad the premise becomes the system minimum window height. Also: iPad has no vertical bar, and the centred nav-bar title lands exactly on the column seam (Duo's title is leading, which hid this). Input for the deferred iPad row in `TODO.md`.
- **What reaches the spec**: the `onCallback` gap (tracked in `TODO.md` — this repo's own `dismissPresented(on:then:)` has the same shape), the keyboard refinement of the `mvvmc-model` advisory, and `mvvmc-view` rule 16. Everything else is one project's layout and stays here.

### Demo 在 Duo 模擬器上的手動實跑（2026-10-07，iOS 27.1 / 24A94232，Xcode 27.1 RC 27A9275，`deeplink(_:in:)` 版）

使用者手動操作、截圖確認。**全部通過，demo 不需要為 Duo 改任何程式**：

- 外螢幕冷啟動：列表正常；tab bar 自動變直、在狀態列下方；內容不壓狀態列／鏡頭。
- 外螢幕詳細頁 → 打開：停在同一頁（不重建），返回鈕移到右側直欄（27.1 垂直 nav bar），返回正常。
- 內螢幕開 Settings sheet（`.medium`/`.large` detents）→ 闔上：sheet 存活，關閉正常。內螢幕 sheet 置中、toolbar 橫向。~~差別可能是 sheet 高度~~ **已量（同日 A/B，外螢幕 Settings sheet）**：只有文字的 `Button("關閉")`／`.topBarLeading` 在半高與全高**都維持橫向**、從未消失；改成 `Button("關閉", systemImage: "xmark")`／`.cancellationAction` 後，半高是橫向（移到右上），**全高變成右側直欄**。要直排得同時滿足「有圖示」與「sheet 全高」。Apple DocC／HIG 說只有文字的按鈕永遠不直排；SDK header（`UIBarButtonItem.h:76`）說只支援橫向的按鈕在沒有橫向 bar 時**不顯示**——這個消失情境本次沒觀察到。demo 改用 B 的寫法（與 `PostFilterView` 已用的 `.cancellationAction` 一致），**不寫成規則**：這是設計取捨，不是架構。
- URL 冷／熱啟動與推播點擊（`response.targetScene`）三個進入點都導到正確頁面。
- 非架構觀察：內螢幕上內文單行橫跨全寬並越過折線——V 層 readable width 的問題，不是規則。
- **外螢幕遵守 `supportedInterfaceOrientations`，內螢幕不理會**（FoodEntropy 實測，兩邊成對照）：FoodEntropy 只宣告 Portrait → 闔上後旋轉介面不轉；demo 沒宣告（iPhone 預設含橫向）→ 闔上後旋轉介面跟著轉、tab bar 移到右側直欄，compact/compact 矮版面——一般 iPhone 橫向也是如此，非 Duo 特有。
- **原則 11 的另一個落點（開放問題）**：FoodEntropy `BannerAdView.keyRootViewController()` 在 `UIViewRepresentable` 內以 `connectedScenes … isKeyWindow` 取 rootVC 交給 AdMob。`mvvmc-navigation` 新寫的那條只管 `deeplink()`；第三方 SDK 橋接要一個 VC 時怎麼取（例如在 `didMoveToWindow` 讀 `window?.rootViewController`）**沒有規範也沒有實測**。單一 scene 下是潛在而非現行錯誤；demo 沒有這種橋接，要寫規則得先有可編譯的形狀。
- **沒測到**：demo 自己的第二個 scene（`UIApplicationSupportsMultipleScenes: false`；使用者測的是 Safari 與 demo 並排，兩個 app）；半開（折線 active）姿態；內螢幕旋轉（2026-10-08 已量，見下方 Bars 段「非對稱安全區」）。

### 第二輪查證（2026-10-07，SDK／DocC／probe）

- **27.1 起 `UIView` 預設 layout margins 為 0**——iOS 27.2 beta 3 release notes 原文（186294594）。**實測要「27.1 SDK 建置」×「iOS 27.1 執行」兩者同時才歸零**（任一為 27.0 都還是 8pt），release note 沒寫這個條件。歸零的只是 8pt 基底，safe area 仍會加上去；VC 的 view 仍有 `systemMinimumLayoutMargins`；子 view 要繼承得設 `preservesSuperviewLayoutMargins = true`。**MVVMC 頁面是 SwiftUI，不受影響**；影響的是 UIKit 橋接 view 裡用 `layoutMarginsGuide` 的約束。記為事實，不是規則。
- **`reservedRegions` 預設是否包含 inactive：Apple 自相矛盾。** header 有 `.includeInactive`（暗示預設排除）；DocC 說「regardless of whether they are currently active」。帶 `.includeInactive` 在兩種解讀下都對。另觀察到 occlusion region 在前幾次 layout pass 為空（UIKit 第 1 pass、SwiftUI 前 3 次 GeometryReader 為 0），與第三方回報一致。
- **版面值存不存進 ViewModel：Apple 兩份 skill 一致**——不存進業務型別；View 持有的 viewport model 可以。已寫成 `mvvmc-model` 的 ⚠️ advisory。

### Bars（navigation／toolbar／tab bar）— 2026-10-07 查證＋實測

- **只有系統容器的 bar 會直排**；自建 `UIToolbar`／`UINavigationBar`／`UITabBar` 永遠橫向（111462）。內螢幕**直向**維持橫向 bar（HIG）。`.bottomBar` 也會併入垂直 bar。
- **按鈕**：只有文字永遠不直排；`.horizontalOnly` 在沒有橫向 bar 時**不顯示**（`UIBarButtonItem.h:76`）。返回／關閉在最上方（`.cancellationAction`）；重要動作 `.topBarPinnedTrailing`（27.0）；溢出由下往上，`visibilityPriority`（27.0）調整；tab bar 與按鈕互擠時預設保 tab bar。
- **非對稱安全區（2026-10-08 補量，`Experiments/VerticalBarProbe` watch 模式）**：Tech Talk 111461「safe areas are often asymmetric… vertical buttons can appear on the left side」。實測整頁兩個橫向都是 trailing（右 84／左 0），**180° 旋轉不會鏡像**；**Split View 放在左半時 bar 在 leading**（左 84／右 0）。layout margins 跟著 bar 走（有 bar 那側 84，另一側 20）。變化過程中有暫態值（172、兩側同為 84），不可在第一次 layout 就快取 inset。不寫規則：SwiftUI 預設在安全區內、demo 沒有 inset 運算；HerbMeet 的追蹤鈕接 `trailingAnchor` 被蓋是田野實例。
- **MVVMC 特有、已實測（`Experiments/VerticalBarProbe`）**：整頁退出只能 C 層覆寫 `preferredVerticalBarBehavior`，SwiftUI `.toolbarVerticalBehavior` 傳不過 `UIHostingController`；按鈕層級 `.axisBehavior` 與 `.toolbarVerticalCompressionBehavior` 傳得過去。已寫入 `mvvmc-hostcontroller`。
- **demo**：四顆 toolbar 按鈕都改成圖示＋文字（Apple 建議；設計，非規則）。
- **未查／UNKNOWN**：搜尋列、大標題、`titleView` 在垂直 bar 下的行為；`.confirmationAction`／`.primaryAction`／`.principal` 的位置；垂直 bar 容量。內螢幕 tab sidebar（`sidebar.preferredPlacement`，27.0）為 opt-in，demo 未採用。

### Pane 容器：Apple 的官方形狀（2026-10-07，HIG／Tech Talk 111463／Apple 論壇 848000、847800／27.1 SDK）

- **導覽容器放在 arrangement 外面，不是每個 pane 自帶。** HIG：「Keep navigation outside of arrangement views… place navigation containers… around it rather than within it.」111463 的 UIKit 範例是 `UINavigationController(rootViewController: arrangementVC)`。Apple 工程師（848000）：「We do not recommend embedding a `UINavigationController` in a `UIArrangementViewController`.」→ FoodEntropy 提案 A 的「每個 pane 自帶 nav」**被官方否決**。
- **形狀**：Tab → `UINavigationController` → 容器頁（nav root）→ 兩個 pane。兩個 pane 的 `navigationController` 都是同一個，所以任一 pane `AppRouter.to(_:from:)` 會**蓋住兩欄**。pane 需要自己的下鑽堆疊 → arrangement 不是對的工具，改 `UISplitViewController`（Apple：arrangement 用於「不需要展開收合行為」的並排）。
- **收合**：split 無法滿足時只顯示 `layoutPriority` 較高者，預設 primary（DTS，847800）。primary 在 leading 無 API 可改（`UISplitArrangement.ViewProperties` 只有 width／height／layoutPriority；只有 overlay 有 edge）。→ ~~FoodEntropy 的「左設定、右首頁、窄時只剩首頁」**可能**可以用「設定 = primary、首頁 = secondary、首頁 layoutPriority 較高」達成~~ **SwiftUI 已被 FoodEntropy 實測否定（同日）**：外螢幕只剩首頁（優先權生效），但**內螢幕直向 669pt 仍分成兩欄**、冷啟動直向亦同；對照組（首頁 primary、無 layoutPriority）同步驟只顯示首頁。layoutPriority 似乎也改變了「分不分得了」的判定。DTS 847800 的「保留高優先權者」只在分不了時成立。`UIArrangementViewController` 未測——demo probe 必測「內螢幕直向」。
- **重新評估 FoodEntropy 的兩筆「架構債」**：「Home HC 代處理 Settings 的 onRoute」符合官方形狀（容器頁負責呈現），也與它實測的 sheet 存活一致——**可能不是債**，只是 `static handle(_:from:)` 的寫法不對。`isEmbedded` 仍是債。
- **已實測（`Experiments/PaneProbe`，同日）**：UIKit `UIArrangementViewController` 與 SwiftUI `ArrangementView`＋representable 兩種容器，**每個 pane 都可以是完整的 HostController**——收合時被隱藏的 pane 被移出 hierarchy、展開時接回同一個實例；從它開的 sheet 收合後**存活**（UIKit 交給最外層 presenter）；push 蓋兩欄。→ FoodEntropy 的兩筆債（`static handle`、`isEmbedded`）都可以用「pane = HostController」消掉，**不需要外層代處理**。風險：收合期間被隱藏 pane 的 `navigationController == nil`，非同步觸發的 push 會靜默失效。
- **「設定在左、首頁在右、窄時只剩首頁」無法用宣告式設定達成**（UIKit `b2`／`b3` 與 FoodEntropy 的 SwiftUI 結果一致）：secondary 設 priority 就不再於直向收合，最小寬度也不會強制收合。容器必須自己在尺寸改變時調整 arrangement。**已實測可行（`b4`）**：繼承 `UIArrangementViewController`，在 `viewWillLayoutSubviews` 依「`horizontalSizeClass == .regular` 且寬 > 高」互換 primary／secondary——外螢幕直橫、內螢幕直橫全對，互換時 Settings 開的 sheet 存活。只看寬 > 高會在外螢幕橫放出錯（compact 但寬 > 高）。半開姿態：自動空出 40pt 折線，不需 `reservedRegions`。
- **pane 的 `.toolbar` 不會出現在導覽列**（B、C 皆然）：寫進了 pane 自己的 `navigationItem`，但只有最上層的容器會被顯示。**容器必須轉接**——`viewDidLayoutSubviews` 把畫面上 pane 的 bar items 設給自己，實測點得動、會進垂直 bar。標題不轉接，由容器決定。FoodEntropy 現行的「一個 HC 組兩個 View」沒有這問題（SwiftUI 自動合併 toolbar）——這是兩種做法的真實取捨。
- **仍未測**：deeplink 到另一個 pane。（垂直 bar：已量——pane 的按鈕要由容器轉接，轉接後進容器的垂直 bar，見上一條。）**下一步才是規則**：demo 是否要加一個並排範例（axis 0：只有在第二個專案需要時才值得），或先把結論寫成 `mvvmc-hostcontroller` 的 ⚠️。
- **閱讀已飽和**：三輪、四路來源（Apple agent skill、官方頁／DocC／Tech Talk、27.0→27.1 SDK diff、14 篇 blog——全部早於 RC）。剩下的問題 Apple 文件都標不出答案，下一步只能是 probe。

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
