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

下表只是索引，**判斷與範例一律以 `references/architecture.md` 為準**（章節編號對應該檔）。

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
| 13 | Preview 以 `#if DEBUG` 包裹，注入 M 層的 `.mock` / `.mocks`，禁止觸發真實網路 | §12 |

---

## 三種任務模式

### 模式 A：生成新視圖

1. 按照 `references/architecture.md` 的模板產生代碼
2. 輸出完整代碼後，附上「架構說明」區塊，解釋：
   - 每一層（L1/L2/L3）的職責劃分
   - Action Mapping 的設計理由
   - 若有灰色地帶判斷，說明為何這樣選擇

**輸出格式：**
```
[完整 Swift 代碼]

---
### 架構說明
- **L1 (GrandParent)**：...
- **L2 (Parent)**：...
- **L3 (Child)**：...
- **Action 設計**：...
- **灰色地帶決策**（若有）：...
```

### 模式 B：審查現有代碼

逐條對照 `references/architecture.md` 的規範檢查，輸出審查報告：

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|
| ...  | ...  | ...      | ...      |

⚠️ 灰色地帶（靈活判斷）：
- [問題描述]：[判斷理由與建議]
```

### 模式 C：重構代碼

1. 先輸出審查報告（同模式 B）
2. 再輸出重構後的完整代碼
3. 附上「重構說明」，列出每一項改動對應的規範條目
