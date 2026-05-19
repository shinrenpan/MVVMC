---
description: 審查指定 Feature，涵蓋 MVVMC 架構合規、Swift 寫法品質、Swift 6 Readiness，輸出分層報告
disable-model-invocation: true
argument-hint: [feature-path]
---

審查 Feature：$ARGUMENTS

請依照以下三個 Pass 逐一執行，每個 Pass 輸出獨立報告區塊。

---

## Pass 1 — MVVMC 架構合規

1. 列出 `$ARGUMENTS` 目錄下所有 Swift 檔案
2. 依 M → VM → V → C 順序逐層讀取並審查：
   - `*ViewModel+Models.swift`：套用 `swift-model` 規範
   - `*ViewModel.swift` + `*ViewModel+APIs.swift`：套用 `swift-viewmodel` 規範
   - `*View.swift`：套用 `swiftui-expert` 規範
   - `*HostController.swift`：套用 `swift-hostcontroller` 規範
3. 每層輸出：

```
### [層名稱]

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 灰色地帶：
- ...
```

4. 輸出跨層一致性摘要（Action 命名、State 欄位、Router 銜接是否一致）

---

## Pass 2 — Swift 寫法品質

逐檔審查以下項目：

- **命名**：型別 UpperCamelCase、變數/函式 lowerCamelCase、縮寫全大寫（`URL`、`ID`）
- **存取控制**：能用 `private` 就不用 `internal`，`public` 需要明確理由
- **Force unwrap / Force cast**：`!`、`as!` 出現即標記，提供安全替代方案
- **冗餘寫法**：不必要的 `self.`、可省略的型別標注、`return` 在單行 closure
- **Magic number / string**：未命名常數應提取為 `static let`
- **Guard vs if-let**：早期返回應優先使用 `guard`

輸出格式：

```
### Swift 寫法品質

❌ 問題項目：
| 檔案:行號 | 問題 | 建議修正 |
|-----------|------|----------|

✅ 無問題
```

---

## Pass 3 — Swift 6 Readiness

涉及 async/await / Task / actor 的代碼同時套用 `swift-concurrency` 規範，並額外審查：

- **`Sendable` 合規**：跨 actor 傳遞的型別是否正確標注 `Sendable`
- **Actor isolation**：`@MainActor` 是否覆蓋所有 UI 存取，`nonisolated` 使用是否恰當
- **`@unchecked Sendable`**：標記出所有使用位置，說明是否可改為正式 `Sendable`
- **Data race 風險**：共享可變狀態是否有 actor 保護
- **廢棄 API**：是否使用已在 Swift 6 廢棄的 concurrency API（如 `withUnsafeCurrentTask`）
- **`Task.init` isolation**：`Task { }` 繼承 caller isolation 是否符合預期

輸出格式：

```
### Swift 6 Readiness

❌ 需要修正：
| 檔案:行號 | 問題 | 風險等級（high/medium/low）| 建議修正 |
|-----------|------|--------------------------|----------|

⚠️ 需要留意：
- ...

✅ 無問題
```

---

## 最終摘要 — 優先修正清單

綜合三個 Pass，輸出依優先順序排列的修正清單：

```
### 優先修正清單

🔴 高優先（架構違規 / data race 風險）：
1. ...

🟡 中優先（Swift 寫法問題 / Swift 6 潛在問題）：
1. ...

🟢 低優先（命名、冗餘寫法）：
1. ...
```

---

💡 **深度分析**：如需對個別檔案進行 Swift 6 / Concurrency / Performance / Memory 深度審查，可執行：

```
/deep-review <檔案路徑>
```

建議優先審查業務邏輯集中的檔案（ViewModel、HostController）。
