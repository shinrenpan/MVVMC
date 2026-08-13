---
name: mvvmc-review
description: |
  審查或重構指定 Feature，涵蓋 MVVMC 架構合規、Swift 品質與 Swift 6、跨層一致性。預設為純審查模式；若使用者明確要求重構，則每層額外輸出重構後完整代碼。
disable-model-invocation: true
argument-hint: [feature-path]
---

審查 Feature：$ARGUMENTS

> 未取得 feature 路徑時，先列出專案的 feature 目錄（MVVMC 慣例是 `Sources/Pages/`，其他專案依實際結構）請使用者指定，不要自行猜測。

請依照以下三個 Pass 逐一執行，每個 Pass 輸出獨立報告區塊。

---

## Pass 1 — MVVMC 架構合規

1. 列出 `$ARGUMENTS` 目錄下所有 Swift 檔案
2. 依 M → VM → V → C 順序逐層讀取並審查：
   - `*ViewModel+Models.swift`：套用 `mvvmc-model` 規範
   - `*ViewModel.swift` + `*ViewModel+APIs.swift`：套用 `mvvmc-viewmodel` 規範
   - `*View.swift`：套用 `mvvmc-view` 規範
   - `*HostController.swift`：套用 `mvvmc-hostcontroller` 規範
   - 對應的 `Tests/*ViewModelTests.swift`（若存在）：套用 `mvvmc-testing` 規範
   - 審查範圍若含 `Sources/App/`（AppRouter / Deeplink / SceneDelegate）：套用 `mvvmc-navigation` 規範
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

---

## Pass 2 — Swift 品質與 Swift 6（套用 deep-review 判準）

本 Pass **不另立檢查清單**——直接套用 `mvvmc-deep-review` 的 Pass 1（Swift 寫法品質）與 Pass 2（Concurrency & Swift 6）判準逐檔執行。清單只維護在 deep-review 一處，避免兩份規範各自漂移。

> 執行方式：`mvvmc-deep-review` 是手動觸發的 skill，模型不會自動載入——用 **Read 讀取 `.claude/skills/mvvmc-deep-review/SKILL.md`** 取得完整判準清單，再逐檔套用。

涉及 async/await / Task / actor 的代碼另套用 `swift-concurrency` 規範。

輸出格式：

```
### Swift 品質與 Swift 6

❌ 需要修正：
| 檔案:行號 | 問題 | 風險（high/medium/low）| 建議修正 |
|-----------|------|------------------------|----------|

⚠️ 風格建議 / 需要留意：
- ...

✅ 無問題
```

> Feature 層級審查求廣度；單檔的 Performance & Memory 深挖走 `/mvvmc-deep-review <檔案路徑>`。

---

## Pass 3 — 跨層一致性

只有把整個 feature 攤開才看得見的問題，逐項確認：

- **Action 命名**：ViewAction 是否為事件風格（`xxxDidTap`）；子層 Action 是否被父層業務語意污染；是否存在純 Forwarding 的中間層
- **State 欄位**：View 讀取的欄位是否都在 State；是否有已無人使用的殘留欄位
- **Router 銜接**：VM 的每個 `Router` case 是否都在 C 層 `handleRouter` 有對應分支，反之亦然
- **Callback 銜接**：子 VM 的每個 `Callback` case 是否都被父 HostController 處理
- **測試覆蓋**：ViewAction / APIResponse 的 case 是否都有對應測試（見 `mvvmc-testing`）
- **命名前綴**：HostController / ViewModel / View 三者的 Feature prefix 是否一致

輸出格式：

```
### 跨層一致性

✅ 一致：
- ...

❌ 不一致：
| 涉及層 | 問題 | 建議修正 |
|--------|------|----------|
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

## 重構模式（可選）

若使用者明確要求重構，在每層審查報告後額外輸出：

1. 重構後完整代碼
2. 「重構說明」：列出每項改動對應的規範條目

最後依 Pass 3 輸出跨層一致性摘要。

---

💡 **深度分析**：如需對個別檔案進行 Swift 6 / Concurrency / Performance / Memory 深度審查，可執行：

```
/mvvmc-deep-review <檔案路徑>
```

建議優先審查業務邏輯集中的檔案（ViewModel、HostController）。
