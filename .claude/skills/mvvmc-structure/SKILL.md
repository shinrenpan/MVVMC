---
name: mvvmc-structure
description: |
  MVVMC 程式碼組織規範（跨 feature 的歸屬決策）。涉及新建 feature、決定某個型別／組件該放哪個目錄、判斷 feature 是否該拆分、處理兩個 feature 都要用同一份東西時觸發。確保 Domain Model 不跨 feature 外洩、Shared 只放與業務無關的基礎設施。
---

# MVVMC Structure Skill

你是一位資深 iOS 工程師，專注於模組邊界與程式碼組織。

此 skill 管的是**橫向的歸屬決策**——某個型別、某個組件該住哪裡。它不屬於 M/V/VM/C 任何一層，各層**內部**的規範見對應 skill（`mvvmc-model` / `mvvmc-viewmodel` / `mvvmc-view` / `mvvmc-hostcontroller`）。

---

## 目錄結構

```
Sources/
├── App/                  導航地基與 App 生命週期（見 mvvmc-navigation）
│   ├── AppRouter.swift
│   ├── Deeplink.swift
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Pages/                一個 feature 一個目錄
│   └── FeatureName/
│       ├── FeatureNameViewModel+Models.swift   ← M
│       ├── FeatureNameViewModel.swift          ← VM
│       ├── FeatureNameViewModel+APIs.swift     ← VM（選用）
│       ├── FeatureNameView.swift               ← V
│       ├── FeatureNameMocks.swift              ← #if DEBUG（選用）
│       └── FeatureNameHostController.swift     ← C
└── Shared/               跨 feature 的基礎設施型別

Tests/
└── FeatureNameViewModelTests.swift    一個 feature 一個測試檔（見 mvvmc-testing）
```

目錄名（`Pages` / `Shared`）可依專案調整，**分界原則不可調整**：feature 的東西住在自己的目錄裡，跨 feature 的東西必須先通過下面兩道判準。

---

## 核心原則：Domain Model 不跨 feature

兩個 feature 都要顯示「貼文」時，**各自定義各自的 `Post`**，不抽出去共用。

```swift
// PostList — 列表要顯示作者，所以帶 userId
extension PostListViewModel {
  struct Post: Identifiable, Equatable, Sendable {
    let id: Int
    let userId: Int
    var title: String
    var body: String
  }
}

// PostDetail — 詳情頁不顯示作者，就沒有 userId
extension PostDetailViewModel {
  struct Post: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var body: String
  }
}
```

**why**：抽成共用的 `Post` 會強迫兩邊都扛下「任一方需要的欄位聯集」，而且任何一邊的 API 變動都會波及沒提出需求的另一邊。複製一個 struct 的成本，遠低於把兩個 feature 的生命週期綁在一起。

### 跨 feature 怎麼傳資料

走 **HostController 的 init 參數，傳 primitive**，不傳 Domain Model：

```swift
// ✅ 父層不需要知道子 feature 的 Domain Model 型別
AppRouter.shared.to(
  PostDetailHostController(id: post.id, title: post.title, body: post.body),
  from: self
)

// ❌ 傳 Domain Model → 兩個 feature 的型別被綁死
PostDetailHostController(post: post)
```

詳見 `mvvmc-hostcontroller`〈變體：傳入原始參數〉。參數多到難看時，那是**拆 feature 的訊號**，不是放寬這條規則的理由。

**回程也一樣**——子 feature 透過 `onCallback` 回傳結果時，同樣傳 primitive：

```swift
// ✅ 父層只需要知道一個 Int
enum Callback: Equatable, Sendable {
  case didSelectUser(id: Int)
}

// ❌ 父層被迫認識 PostFilterViewModel.User 這個型別
enum Callback: Equatable, Sendable {
  case didSelectUser(User)
}
```

去程傳 primitive、回程卻帶 Domain Model 是不對稱的——**耦合是雙向的**，型別跟著回程走一樣會把兩個 feature 綁死。而且實務上父層通常只用得到其中一兩個欄位（demo 的父層就只用了 `user.id`），帶整個 Model 過去並沒有換到什麼。

---

## Shared/ 放什麼

判準只有一句：**這個名字會出現在業務對話裡嗎？**

| | 例子 | 判斷 |
|---|---|---|
| ✅ 可以放 | `APIStatus`、`APIError`、日期／金額格式化、`Collection` 的共用 extension | 與業務無關，換一個 App 也照樣能用 |
| ❌ 不可以放 | `User`、`Post`、`Order`、`OrderStatus` | 是業務概念 → 屬於某個 feature |

❌ 那一欄若真的兩個 feature 都要用，答案是**各自定義**（見上方核心原則），不是搬進 `Shared/`。

> `Shared/` 一旦開始堆業務型別，它就會長成沒有邊界的 God module——所有 feature 都依賴它，改一行要重編全部。這條判準是防止那件事發生的唯一屏障。

---

## 跨 feature 共用的 UI 組件

一個 View 組件被**兩個以上的 View 檔案**使用時，它已經不專屬於任何一頁：

- ✅ 提拔為獨立檔案，不帶 feature 前綴（`TagBadge` 而非 `ListTagBadge`）
- ✅ 不放在任何 feature 的 `private extension` 裡（否則另一個 feature 會反向依賴）
- ✅ 目錄建議 `Sources/Components/`（名稱可依專案調整，重點是**不在 `Pages/<Feature>/` 底下**）
- ❌ 不要為了「將來可能共用」先提拔——等真的出現第二個使用者再說

判斷細節與反例見 `mvvmc-view`〈跨 Section 共用組件的處理〉。

---

## feature 邊界：何時該拆

**該拆的訊號**（任一成立就值得拆）：

- `State` 長出了「沒有任何一個畫面會同時讀」的欄位群
- `ViewAction` 明顯分成兩簇，兩簇之間從不互動
- 同一個 ViewModel 同時服務兩種導航目的地（既是列表又是編輯器）

**不該拿來當理由的**：

- ❌ 檔案太長——長度是症狀不是病因，先問上面三條
- ❌ 「這段以後可能會複用」——沒有第二個使用者就沒有複用

**拆的方向**：切成兩個 `Pages/` 目錄，各自 M/VM/V/C 齊全，用 primitive 銜接。不要拆成「共用 ViewModel + 兩個 View」——那會讓 VM 同時對兩個畫面負責，違反 `doAction` 單一進入點的意圖。

### 例外：多步驟流程（wizard）優先合成一個 feature

「步驟 1 → 2 → 3 → 送出」這種流程，表面上符合上面兩條拆分訊號（ViewAction 分三簇、State 欄位群不共讀），但**預設應該做成一個 feature**，用 `step` enum 驅動畫面切換：

- **判準是「這幾頁是否共用同一份還沒送出的資料」**。是 → 一個 feature；否（每頁各自完成一件獨立的事）→ 才分開
- **why**：拆成三個 feature 後，草稿得在三者之間傳遞——中間每一層都被迫帶著不屬於自己的欄位（prop drilling），而且最後一步的結果要逐層中繼回起點（見 `mvvmc-viewmodel`〈深層回傳〉）。兩者都是純成本，換不到任何解耦，因為這三頁本來就一起生、一起死
- 反過來說，若某一步**可以獨立進入**（例如從別的入口直接編輯地址），那它就是獨立 feature，不是 wizard 的一步

---

## 三種任務模式

### 模式 A：新建 feature

1. 確認它確實是一個獨立 feature（對照〈feature 邊界〉）
2. 在 `Pages/` 下建目錄，依 M → VM → V → C 順序產生檔案
3. 需要跨 feature 資料時，設計成 primitive 參數，不引用他人的 Domain Model
4. 輸出檔案清單與「為何是獨立 feature」的一句話說明

### 模式 B：審查組織

```
### 組織審查報告

✅ 符合規範：
- ...

❌ 違規項目：
| 位置 | 問題 | 規範依據 | 建議修正 |
|------|------|----------|----------|

⚠️ 灰色地帶：
- ...
```

重點檢查：`Shared/` 有沒有混入業務型別、feature 之間有沒有直接引用對方的 Domain Model、共用組件是否還卡在某個 feature 的 `private extension` 裡。

### 模式 C：重構歸屬

1. 先輸出審查報告（同模式 B）
2. 列出搬移計畫（哪個型別從哪搬到哪、影響哪些 import）
3. 附上「重構說明」，列出每項改動對應的規範
