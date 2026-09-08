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

## 開單前的排除清單（先讀這一節，再開始任何 Pass）

下列情形**一律不得列為 ❌**，最多列 ⚠️ 灰色地帶並註明「屬規範明文不介入的範圍」。它們是上游 skill 明文寫下的豁免，而**散文轉成檢查清單時，限定詞是第一個掉的東西**——這一節存在就是為了把它們接回來。

| 不得開單的情形 | 出處 |
|---|---|
| 已開啟 `SWIFT_DEFAULT_ACTOR_ISOLATION` 的專案，ViewModel 少標 `@MainActor` | `mvvmc-viewmodel`〈強制宣告〉三模式分支表 |
| Action 命名未實作全部三種分類（ViewAction / APIRequest / APIResponse） | `mvvmc-viewmodel`〈Action 命名〉不強制全部實作 |
| 「沒有 endpoint 獨立檔案 / 沒有 APIManager / 沒有用 DI」 | `mvvmc-viewmodel`〈明確不在規範範圍〉 |
| 請求狀態容器的形狀（要不要包 `api`、狀態 enum 有哪些 case、叫什麼名字） | `mvvmc-model`〈State 欄位型別〉、`mvvmc-testing` |
| 分頁游標的形式 | `patterns.md`〈分頁載入〉 |
| 中繼層與自身業務無關的 `childDidFinish` 類雜訊 case | `patterns.md`〈深層回傳〉「不該當成違規」 |
| 該層**有** forwarding 以外程式碼時，其中的 1:1 forwarding | `mvvmc-view` 規則 7 |
| 已有內容時載入失敗的呈現方式（靜默 / 底部重試列 / toast） | `architecture.md` §1「規範不指定」 |
| L3 以下的組件後綴命名不統一 | `architecture.md` §4「不強制」 |
| 參數數量超過參考點 | `architecture.md`「不是強制門檻」 |
| DTO 的命名風格 | `mvvmc-model`「不強制任何風格」 |
| ViewAction 用動詞風格而非事件風格 | `architecture.md`「推薦／避免」是**偏好不是硬規則**——只能列 ⚠️ |

> **維護規則**：新增或修改任何一條上游豁免時，**必須同步更新這張表**。它的存在價值就是讓「有沒有同步」變成一個看得見的問題——14 條散在 6 個檔案裡時，沒有人能一眼看出漏了哪條。
>
> 稽核方式（可機械執行）：
> ```
> grep -rn "不得.*開單\|不該當成違規\|不在規範範圍\|不強制\|規範不指定\|不是強制門檻" .claude/skills/
> ```
> 上游命中數應與本表列數相符。**2026-09-08 首次稽核時，上游 14 條、本檔 0 條。**

---

## Pass 1 — MVVMC 架構合規

1. 列出 `$ARGUMENTS` 目錄下所有 Swift 檔案
   > ⚠️ **另外把 `Shared/` 與 `Components/`（或該專案的等價目錄）也讀進來**。它們依定義不在任何 feature 目錄底下，所以永遠不在 `$ARGUMENTS` 範圍內——而上游對它們有硬規則（`mvvmc-structure`〈`Shared/` 判準〉、`mvvmc-view` §4 第三階的跨 feature 共用組件）。**不讀進來就永遠是零執法途徑，而輸出還會是 ✅。**
2. 依 M → VM → V → C 順序逐層讀取並審查：
   - `*ViewModel+Models.swift`：套用 `mvvmc-model` 規範
   - `*ViewModel.swift` + `*ViewModel+APIs.swift`：套用 `mvvmc-viewmodel` 規範
     > ⚠️ **開審之前先確認專案的 `SWIFT_DEFAULT_ACTOR_ISOLATION`**（`swift-concurrency`〈Fast Path〉）。**已開啟的專案，未標 `@MainActor` 的 ViewModel 不得開單**——見 `mvvmc-viewmodel`〈強制宣告〉的三模式分支表。漏掉這一步會對整個專案開出一整批假單
   - `*View.swift`：套用 `mvvmc-view` 規範
   - `*HostController.swift`：套用 `mvvmc-hostcontroller` 規範
   - **跨 feature 型別引用**：套用 `mvvmc-structure` 規範——檢查 State / Domain Model 有沒有引用其他 `XxxViewModel.` 命名空間的型別，這是最容易漏掉的一類違規
   - `*Mocks.swift`（若存在）：套用 `mvvmc-model`〈Mock 規範〉——**❌ 禁止 mock 出現在非 `#if DEBUG` 區塊**（漏掉的後果是 mock 資料進正式 build）、mock 掛在 Domain Model 而非 DTO
   - 對應的 `Tests/*ViewModelTests.swift`（若存在）：套用 `mvvmc-testing` 規範
   - **`Tests/` 底下不符合上述 glob 的測試檔**：套用 `mvvmc-testing`〈架構不變式測試〉
     > ⚠️ 那個 glob 把「測試」寫死成「ViewModel 測試」。不變式測試（在地化覆蓋、跨 feature 引用、字面值覆蓋）不對應任何 feature，**檔名不會符合**——不另外讀進來的話，審查在檔名層級就看不見它們，而它們擋的正是「編譯器沉默、執行期沉默、review 看不出來」那一類
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

> 執行方式：`mvvmc-deep-review` 是手動觸發的 skill，模型不會自動載入——用 **Read 讀取 `~/.claude/skills/mvvmc-deep-review/SKILL.md`**（skill 的全域安裝位置）取得完整判準清單，再逐檔套用。
>
> ⚠️ **不要用相對路徑 `.claude/skills/…`**。這份 skill 會被帶到別的專案執行，而那些專案的目錄下沒有 `.claude/skills/`——skill 是透過 `~/.claude/skills/` 的 symlink 生效的。用相對路徑會讀不到檔案，然後**這個 Pass 靜默降級成憑印象審查**，沒有任何錯誤訊息。若全域路徑也讀不到，**停下來回報「deep-review 判準不可用」，不要自行憑記憶補一份清單**。

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

> **這個 Pass 用 LSP，不要用 grep。** 專案已裝 `swift-lsp`（sourcekit-lsp），下列判斷全部有精確答案，grep 會被註解、字串、同名符號誤導——跟 String Catalog 那條「不要用 grep 判斷死活」是同一個教訓。
>
> | 要判斷的事 | 用哪個操作 |
> |---|---|
> | Action case / State 欄位有沒有人用 | `findReferences` 在該 case 或欄位宣告上 |
> | Router case 是否有對應 `handleRouter` 分支 | `findReferences` 對照兩端 |
> | Callback 是否被父 HostController 處理 | `findReferences` 對照兩端（**同 Router 的手法**） |
> | 有沒有跨 feature 引用 Domain Model | `findReferences` 看引用落在哪些目錄 |
> | 型別實際簽名（含推導出的 actor 隔離） | `hover` |
>
> ⚠️ **不要對 `onCallback` / `onRoute` 用 `incomingCalls`**。它們是 stored closure property，不是 function——call hierarchy 建在函式符號上，**2026-09-08 實測回「No call hierarchy item found at this position」**。這跟有沒有索引無關，是結構性的：要追「誰呼叫了存進去的那個 closure 值」屬於執行期的值流，LSP 原理上給不出來。用 `findReferences` 對照兩端即可。
>
> **哪些操作在沒有索引時仍然可用**（同日實測）：`hover` ✅、`documentSymbol` ✅（單檔操作，能正確列出型別結構與 property/method 分類）；`findReferences` ❌、`workspaceSymbol` ❌ 回空。**所以 sanity check 失敗時，Pass 3 仍可用 `documentSymbol` 建立各檔的符號清單，再用 grep 對照**——它消掉的是**假陽性**（註解、字串裡的同名符號）。
>
> ⚠️ **但假陰性它一樣看不到**（跨檔引用不在單檔符號表裡）。所以「**不得輸出任何『無呼叫者 / 無人使用 / 可移除』的結論**」這條**綁在結論上，不綁在工具上**——不管你用 grep 還是 `documentSymbol`，只要 sanity check 沒過，那類結論一律不得輸出。
>
> **開跑前必做的 sanity check（不是提醒，是步驟）**：
>
> 1. 挑一個**你確知有多處引用**的符號（例如某個 `Router` case 的宣告），對它跑一次 `findReferences`。
> 2. **回非空** → LSP 有索引，後續的空值可以信任。
> 3. **回空** → LSP 沒有 build context，**本 Pass 的所有空值都是假陰性**。改用 grep，在報告開頭標明「精確度降級：LSP 無索引」，並且**不得輸出任何「無呼叫者 / 無人使用 / 可移除」的結論**。
>
> ⚠️ **這一步不能省，因為失效方式是回空值而不是報錯。** 2026-09-08 實測：MVVMC 自己的 demo 與另一個上架專案上，`findReferences` 與 `workspaceSymbol` **都回空**，diagnostics 顯示 `Cannot find type 'State' in scope`——sourcekit-lsp 在單檔模式跑，連同一個 module 的型別都解析不到。
>
> **根因**：Xcode 專案需要 `buildServer.json`（由 `xcode-build-server` 產生）或 `compile_commands.json`，LSP 才知道編譯參數。**「這個專案建置過」與「LSP 有索引」是脫鉤的兩件事**——有 `.xcodeproj` 和 DerivedData 不代表 LSP 讀得到。`hover` 是唯一在無索引下仍可用的操作，但它只複述原始碼字面寫著的東西，**推導不出隱含的 actor 隔離**。
>
> 沒有這一步時的淨效果是：**把一個粗糙但會動的工具（grep）換成一個回空值的精確工具，然後把空值讀成「沒有呼叫者」，最後輸出一份要使用者去砍活著的程式碼的清單。** 那比沒有這個 Pass 更糟。

只有把整個 feature 攤開才看得見的問題，逐項確認：

- **Action 命名與中間層**：逐一檢視各層 Action 的命名與中間層的 Action 處理，**套用 `mvvmc-view` §3〈純 Forwarding〉的完整判準（含例外與 §5 的消除條件）**；跨 HostController 的 Callback 中繼層套用 `mvvmc-viewmodel/references/patterns.md`〈深層回傳〉。
  > 事件風格 vs 動詞風格在上游是**推薦／避免**，不是硬規則——只能列 ⚠️，不得列 ❌
- **State 欄位**：View 讀取的欄位是否都在 State；是否有已無人使用的殘留欄位。**欄位的形狀（容器怎麼包、enum 有哪些 case）套用 `mvvmc-model`〈State 欄位型別〉，該節明文不介入形狀，不得以此開單**
  > ⚠️ 規範自己要求的 Preview 專用欄位（`isPollingSuspended` 一類，見 `mvvmc-view` §12）**依設計就沒有正式流程的讀取者**，不得列為「無觸發點」
  > 找到沒有呼叫者的 Action case / 沒人讀的 State 欄位時：**標記，不要替使用者刪**。「這個功能是還沒接完，還是已經不要了」是產品決策，不是審查決策。報告寫「無觸發點，請確認是待接線或應移除」即可
- **Router 銜接**：VM 的每個 `Router` case 是否都在 C 層 `handleRouter` 有對應分支，反之亦然
- **Callback 銜接**：子 VM 的每個 `Callback` case 是否都被父 HostController 處理
- **測試覆蓋**：**套用 `mvvmc-testing`〈什麼值得測試〉與〈什麼不值得測試〉的完整清單**，不是「每個 case 都要有測試」——上游有明文排除項
  > ⚠️ **啟動輪詢的 ViewAction 要測，但不能直接 `await vm.doAction(...)`**。它不是「永不返回」，是**「不被取消就不返回」**——而取消正是正式環境每次離開畫面都會發生的事。直接 await 會讓套件掛住、CI 逾時、且沒有錯誤訊息。
  > 正確做法：包進可取消的 `Task`、明確 `cancel()`、並掛 `.timeLimit`（掛住時給出真正的失敗而不是卡住）。測的是〈週期性更新〉那兩條**編譯器不管、code review 也看不出來**的規則——「取消後迴圈是否真的結束」（寫成 `while true` 或把取消吞掉，症狀只是耗電，使用者永遠不會回報）與「`.loading` 是否只寫一次」（寫錯的症狀是畫面每 N 秒閃一次，interval 設長就看不到）
- **命名前綴**：HostController / ViewModel / View 三者的 Feature prefix 是否一致
- **高頻欄位隔離**（M 層）：**套用 `mvvmc-model`〈高頻變動欄位〉**——高頻更新的欄位有沒有從低頻 Model 拆出來。
  > 上游自己的定位是「**這是效能隔離的第一道閘門，而且它在 M 層不在 V 層**——`mvvmc-view` §7 講的拆 View 是第二道。**第一道沒做，第二道就形同虛設**」。而它的症狀是「跑起來沒事、只是慢」，不會有人主動去查——**規範自稱的第一道閘門，先前是唯一沒有檢查項的那一道**
- **`Router` / `Callback` 的 `Equatable`**：**套用 `mvvmc-viewmodel`〈onRoute / onCallback〉**——帶 associated value 的 enum 要顯式加。沒有它就寫不出 `#expect(received == .toDetail(post))`，等於整條導航意圖無法測試
- **feature 邊界**：有沒有直接引用其他 feature 的 Domain Model（應改傳 primitive）；`Shared/` 有沒有混入業務型別——**套用 `mvvmc-structure` 的判準「這個名字會出現在業務對話裡嗎」**
  > ⚠️ 這一項**不能用 `XxxViewModel.` 字串樣式偵測**。已經被提拔到 `Shared/` 的業務型別**沒有那個前綴**（`Sources/Shared/Post.swift` 被兩個 feature 直接 import，零個 `XxxViewModel.` 引用），而那正是 `mvvmc-structure` 說的「防止 God module 的唯一屏障」要擋的形狀。這是語意判斷，`findReferences` 給不出答案
  > ⚠️ **`Shared/` 與 `Components/` 不在 `$ARGUMENTS` 的掃描範圍內**（Pass 1 只列該 feature 目錄）。要檢查這一項必須另外把那些目錄讀進來，否則輸出的 ✅ 依據是零個檔案——**假通過比假發現危險，因為假發現會被反駁，假通過不會**

輸出格式：

```
### 跨層一致性

✅ 一致：
- ...

❌ 不一致：
| 涉及層 | 問題 | 建議修正 |
|--------|------|----------|
```

> **審查項的三段式**：**描述缺陷、判準委派給層 skill、療法一律不寫。**
> - **缺陷**情境無關（「沿用了跨 `await` 的過期假設」在哪裡都是錯的）→ 可以寫死
> - **判準**會演化（含例外、含邊界）→ 必須委派，否則會漂
> - **療法**情境相依（輪詢不能用旗標、表單要用旗標＋`defer`、分頁不用）→ **寫進審查項必然在某個情境撞到禁令**
>
> 判別式：**需要逐格列舉的是療法，缺陷不需要。** 一條檢查項如果得寫「在 A 情境這樣、在 B 情境那樣」，代表它寫的是療法，應該改寫成缺陷再委派判準。
>
> **維護規則——判斷一條檢查項會不會漂移**：把它指名的上游那節**整段刪掉，這條檢查項還讀得懂嗎？**
> - 讀得懂 → 它自帶了判準 → **會漂**，上游加例外時這裡不會知道
> - 讀不懂（退化成一個沒有內容的指標）→ **不會漂**
>
> Pass 1 每一條都通不過這個測試（刪掉 `mvvmc-model` 就沒東西可套），**那正是它從不漂的原因**。檢查清單該保留的是**視角**（「這件事只有把整個 feature 攤開才看得見」），委派出去的是**判準**（含例外、含邊界）。

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
