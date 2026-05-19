---
description: 重構指定 Feature，依照 MVVMC 架構規範逐層審查並輸出重構代碼
disable-model-invocation: true
argument-hint: [feature-path]
---

重構 Feature：$ARGUMENTS

請依照以下流程執行：

1. 列出 `$ARGUMENTS` 目錄下所有 Swift 檔案
2. 依 M → VM → V → C 順序逐層讀取、審查、重構：
   - `*ViewModel+Models.swift`：套用 `swift-model` 規範
   - `*ViewModel.swift` + `*ViewModel+APIs.swift`：套用 `swift-viewmodel` 規範
   - `*View.swift`：套用 `swiftui-expert` 規範
   - `*HostController.swift`：套用 `swift-hostcontroller` 規範
   - 所有涉及 async/await / Task 的代碼同時套用 `swift-concurrency` 規範
3. 每層輸出：
   - 審查報告（✅ 符合 / ❌ 違規 / ⚠️ 灰色地帶）
   - 重構後完整代碼
4. 最後輸出跨層一致性摘要（Action 命名、State 欄位、Router 銜接是否一致）
