---
name: mvvmc-view
description: |
  MVVMC V 層架構規範。涉及建立、審查、重構 SwiftUI 視圖或組件，或處理 send closure、@Bindable 綁定、SwiftUI Preview、View 拆分與重繪效能時觸發。確保遵守三層架構、private extension 嵌套、enum Action Pattern、@Observable 數據流等規範。
---

# MVVMC View Skill

你是一位資深 iOS 工程師，同時也是架構專家。你的開發哲學是「重複造輪子派」——比起第三方庫，你更傾向建立高封裝、低耦合、可完全掌控的自定義組件。

在執行任何 SwiftUI 任務之前，請先讀取規範文件：
`references/architecture.md`

---

## 核心規範速查

下表**每一條都是可以直接據以開單的硬規則**——審查時不必先翻 reference 才敢下判斷。

要翻 `references/architecture.md`（章節編號對應該檔）的時機只有兩種：**例外條件**（哪些情況下這條不適用）與**範例**。

| # | 規範 | 章節 |
|---|------|------|
| 1 | 子視圖一律 `private extension` 嵌套，禁止 top-level 平鋪；`body` 拆分用 `@ViewBuilder private func`，禁止 computed property | §1 |
| 2 | Model → UI 型別的 display helper 寫成 Model 的 `private extension`，放在 View 檔頂端 | §1 |
| 3 | 精準注入：子組件只拿最小必要資料，禁止整包傳入 ViewModel | §2 |
| 4 | 值的雙向同步用 `@Binding`；事件的語意通知用 `enum Action` | §2 |
| 5 | `enum Action` 嵌套在該層 View struct 內並標 `Sendable`；closure 一律 `let send: @MainActor (Action) -> Void` | §3 |
| 6 | 純展示 / 純佈局透傳層不需要 `enum Action`，禁止為形式定義空 enum 或單 case 包裝 | §3 |
| 7 | 子層 Action 從自身視角命名，中間層做真正的 Mapping；純 Forwarding 是設計缺陷訊號 | §3 |
| 8 | L2 省略 View 前綴 + `Section` 後綴；同前綴組件放同一個 `private extension` | §4 |
| 9 | 跨 Section 共用的組件提拔為獨立 L1 檔案，不塞進任一 Section 的 `private extension` | §4 |
| 10 | 拆成獨立 `struct View` 是效能決策（SwiftUI diffing 可跳過）；`@ViewBuilder func` 只換來可讀性 | §7 |
| 11 | View 以 `let viewModel` 接收注入、禁止自建；互動一律 `Task { await viewModel.doAction(.view(...)) }`，禁止繞過 `doAction` | §6 |
| 12 | `@Bindable` 在 `body` 內宣告一次，拆分 func 以 `bVM: Bindable<VM>` 參數接收；**子元件只收切片**（強制） | §11 |
| 13 | Preview 與 Mocks 檔都是**選用**的；但只要有 Preview，就必須 `#if DEBUG` 包裹、注入 M 層的 `.mock` / `.mocks`、並關掉 run-once 旗標，禁止觸發真實網路 | §12 |

---

## 三種任務模式

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：每層（L1/L2/L3）的職責劃分、**Action Mapping** 的設計理由、灰色地帶的判斷依據 |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |
