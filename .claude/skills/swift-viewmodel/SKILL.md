---
name: swift-viewmodel
description: |
  Swift ViewModel 架構規範。涉及建立、審查、重構 @Observable ViewModel 時觸發。確保遵守 @Observable + @MainActor + final class 三合一規範，以及 doAction 單一進入點。
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
final class FeatureViewModel {
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
- ❌ 禁止繼承任何 ViewModel protocol
- ❌ 禁止 `ObservableObject` / `@Published`

**doAction 規範：**
- ✅ 唯一進入點，內部只做 `switch` dispatch
- ❌ 禁止可從 View 直接呼叫的業務邏輯 func（應透過 doAction）
- 💡 Action 種類多時，建議每層各自一個 `private extension`；單層或簡單的 ViewModel 可以合併
- 💡 handle 內以語意判斷是否拆出獨立 private func；邏輯簡單且無命名價值時直接寫在 case 內即可

**Action 命名（不強制全部實作，依需求取捨）：**

| Action 種類 | 命名 | 說明 |
|---|---|---|
| UI 事件 | `ViewAction` | 描述「UI 發生了什麼」（what happened） |
| API 請求 | `APIRequest` | 發起網路請求 |
| API 回應 | `APIResponse` | 處理網路回應，更新 state |

所有 Action enum 需為 `Sendable`，依情境放在合適的 `extension` 下。

**onRoute / onCallback：**

- `onRoute` — HostController 設定，接收導航意圖後執行導航
  - 型別：`(@MainActor (Router) -> Void)?`，同步
  - ViewModel 呼叫：`onRoute?(.toDetail(post))`（不經過 doAction dispatch）
- `onCallback` — 父 HostController 設定，接收跨 VC 回傳值
  - 型別：`(@MainActor (Callback) async -> Void)?`，async（避免呼叫端需要包 Task）
  - ViewModel 呼叫：`await onCallback?(.didSelectUser(user))`（在 doAction 內 await）
- ✅ 兩者只在有實際需求時才宣告
- ✅ 必須標注 `@ObservationIgnored`
- ✅ 非 UI 相關的 property 一律標注 `@ObservationIgnored`

> `@Observable` 追蹤所有 stored property；closure 或非 UI 狀態若未標注 `@ObservationIgnored`，會觸發不必要的 View re-render。

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
