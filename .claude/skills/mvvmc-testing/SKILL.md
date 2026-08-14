---
name: mvvmc-testing
description: |
  MVVMC 單元測試規範。涉及為 ViewModel 撰寫、審查、重構測試，或使用 Swift Testing（@Test、#expect、#require、confirmation）測試 MVVMC 程式碼時觸發。核心哲學：透過 doAction(.apiResponse(...)) 直接注入結果，不需要 protocol 或 mock class。
---

# MVVMC Testing Skill

你是一位資深 iOS 工程師，專注於 MVVMC 架構下的單元測試策略。

---

## 設計哲學

**不需要 protocol，不需要 mock class。**

MVVMC 的 `doAction(.apiResponse(...))` 本身就是天然的測試注入點：

```swift
// 不走 API，直接注入結果
await vm.doAction(.apiResponse(.fetchUser(.success(dto))))
await vm.doAction(.apiResponse(.fetchUser(.failure(.message("Not found")))))
```

這樣做的好處：
- 零額外抽象：不需要為了測試引入 protocol / dependency injection 框架
- 測試意圖清晰：直接驗證「給定這個 API 回應，state 變成什麼」
- Feature 變動快時，只有 Action enum 改動，測試跟著改即可

### `state.api` 狀態容器

下方範例大量出現 `state.api.<name>`。這是 **demo 採用的做法**：每個 API 動作在 `State` 裡有一個對應的狀態欄位，記錄該次請求目前處於哪個階段。demo 用的狀態值：

- `.prepare`：初始／尚未觸發
- `.success`：請求成功
- `.error(...)`：請求失敗，附帶錯誤訊息
- （若該流程有讀取指示器，也可有 `.loading`）

> **形狀不強制**：要不要包成 `api` 容器、狀態 enum 有哪些 case、怎麼命名，屬個人／團隊習慣（見 `mvvmc-model`〈State 欄位型別〉）。本 skill 只借它示範測試手法——**重點是「斷言請求狀態的轉移」這個做法**，不是這個特定形狀。專案若用別的表達方式（`isLoading: Bool` + `errorMessage: String?` 等），把下方斷言換成對應欄位即可。

---

## 測試結構

### 基本格式

```swift
import Testing
@testable import AppModule

@MainActor
struct FeatureViewModelTests {

  @Test
  func `isFirstAppear guard blocks duplicate trigger`() async {
    let vm = FeatureViewModel()
    vm.state.isFirstAppear = false
    await vm.doAction(.view(.isFirstAppear))
    #expect(vm.state.api.fetchItems == .prepare)
  }
}
```

- `import Testing`（Swift Testing framework，iOS 17+）
- `@testable import` 對應 app module 名稱
- `@MainActor` 標注在 struct 層級，覆蓋所有 test func
- 每個 `@Test` func 都是 `async`

### 測試命名（Swift 6.2 raw identifier）

使用反引號包裹完整描述句，不需要 `@Test("...")`：

```swift
// ✅ Swift 6.2 raw identifier
@Test
func `fetchUser success sets user state`() async { ... }

// ❌ 舊寫法，避免使用
@Test("fetchUser success sets user state")
func testFetchUserSuccess() async { ... }
```

Raw identifier 格式：`描述主語` + `條件/輸入` + `預期結果`

---

## 什麼值得測試

| 情境 | 測試方式 |
|------|----------|
| Guard 邏輯（isFirstAppear、防重入） | 設定 state 後觸發 action，驗證 state 未變 |
| API 成功路徑 | 注入 `.success(dto)`，驗證 state 欄位正確 |
| API 失敗路徑 | 注入 `.failure(.message(...))`，驗證 error status |
| Callback 觸發 | 設定 `onCallback` closure，驗證回傳值 |
| 導航意圖（`onRoute`） | 設定 `onRoute` closure，驗證收到的 Router case |
| State 欄位計算 | 直接操作 state，驗證 computed property |

> 每一類的完整範例見 `references/patterns.md`，另附三個按需採用的手法（參數化測試、`#require` 解 Optional、`confirmation` 驗證呼叫次數）。

## 什麼不值得測試

| 情境 | 原因 |
|------|------|
| 實際 API 網路呼叫 | 非確定性、速度慢，交給整合測試 |
| SwiftUI View render | UI 測試範疇，非單元測試 |
| HostController 的導航**行為**（push / pop / present 真的發生） | 依賴 UIKit 環境；VM 端只驗證意圖（`onRoute` 收到什麼），見上表 |

---

## 三種任務模式

| 模式 | 做什麼 |
|---|---|
| **A：生成** | 依上方規範產生代碼。使用者未要求就只給代碼；要說明時講這幾件事：先讀 `*ViewModel.swift` 與 `+Models.swift` 識別所有 ViewAction / APIResponse case，再依〈什麼值得測試〉逐項覆蓋 |
| **B：審查** | 輸出報告：✅ 符合規範 / ❌ 違規（表格：位置、問題、規範依據、建議修正）/ ⚠️ 灰色地帶（說明判斷理由） |
| **C：重構** | 先出審查報告（同 B）→ 重構後完整代碼 → 「重構說明」列出每項改動對應的規範條目 |
