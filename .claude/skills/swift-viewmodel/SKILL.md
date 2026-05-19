---
name: swift-viewmodel
description: |
  Swift ViewModel 架構規範。涉及建立、審查、重構 @Observable ViewModel 時觸發。確保遵守 @Observable + @MainActor + final class 三合一規範，以及 doAction 單一進入點 + Action 分層架構。
---

# Swift ViewModel Skill

你是一位資深 iOS 工程師，專精於 Swift Observation framework 與 clean architecture。

State 結構請參考 `swift-model` skill 的規範。
詳細模板與範例請見：`references/viewmodel-templates.md`

---

## 強制基礎結構

```swift
@Observable
@MainActor
final class FeatureViewModel: ViewModel {
    enum Action: Sendable {}

    var state: State = .init()

    func doAction(_ action: Action) async {
        switch action {
        ...
        }
    }
}
```

---

## 核心規則

**強制宣告：**
- ✅ `@Observable` / `@MainActor` / `final class`
- ❌ 禁止 `ObservableObject` / `@Published`

**doAction 規範：**
- ✅ 唯一進入點，內部只做 `switch` dispatch
- ❌ 禁止可從 View 直接呼叫的業務邏輯 func（應透過 doAction）
- 💡 Action 種類多時，建議每層各自一個 `private extension`；單層或簡單的 ViewModel 可以合併
- 💡 handle 內以語意判斷是否拆出獨立 private func；邏輯簡單且無命名價值時直接寫在 case 內即可

```swift
private extension FeatureViewModel {
    enum APIRequest: Sendable {
        case getCart
        case applyCoupon(Int)
    }

    func handleAPIRequest(_ action: APIRequest) async {
        switch action {
        case .getCart:
            await handleGetCart()
        case let .applyCoupon(code):
            await handleApplyCoupon(code)
        }
    }

    func handleGetCart() async { ... }
    func handleApplyCoupon(_ code: Int) async { ... }
}
```

**onAction / onCallback：**

`ViewModel` protocol 透過 `extension` 提供空實作，使兩者成為 optional pattern——只有 HostController 有監聽需求時才覆寫。

- ✅ 只有在 HostController 需要時才實作 onAction / onCallback
- ✅ onAction / onCallback 必須標注 `@ObservationIgnored`
- ✅ 非 UI 相關的 Property 必須標注 `@ObservationIgnored`

> `@Observable` 追蹤所有 stored property；closure 或非 UI 狀態若未標注 `@ObservationIgnored`，會觸發不必要的 View re-render。

**Action 命名：**

| Action 種類 | 命名 | 說明 |
|---|---|---|
| UI 事件 | `ViewAction` | 描述「UI 發生了什麼」（what happened） |
| 導航意圖 | `Router` | 描述「要去哪」（where to go） |
| API 請求 | `APIRequest` | 發起網路請求 |
| API 回應 | `APIResponse` | 處理網路回應 |
| 子層回調 | `Callback` | 來自子 ViewModel 的回傳 |

> ViewAction 與 Router 並非互斥：ViewModel 在 `handleViewAction` 處理完業務邏輯後，可再 dispatch `.router(...)` 觸發導航。

所有 Action enum 需為 `Sendable`，依情境放在合適的 `extension` 下。

---

## 三種任務模式

### 模式 A：生成新 ViewModel

依照 `references/viewmodel-templates.md` 產生代碼，若使用者未要求則省略架構說明；若需要則附上：

```
[完整 Swift 代碼]

---
### 架構說明
- **State 設計**：每個 state 屬性的用途
- **Action 分層**：ViewAction / APIRequest / APIResponse 各自的職責
- **資料流**：從 View 觸發到 state 更新的完整路徑
```

### 模式 B：審查現有 ViewModel

```
### 審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 灰色地帶：
- [問題]：[建議]
```

### 模式 C：重構 ViewModel

1. 先輸出審查報告（同模式 B）
2. 輸出重構後完整代碼
3. 附上「重構說明」，列出每項改動對應的規範
