# 新專案導入 Skip — 從零架設

把一個既有的 MVVMC iOS 專案（XcodeGen + `Sources/Pages/`）轉成 Skip 可以處理的形狀。

以下用 `<Module>` 代表模組名，範例用 `MVVMCSkipDemo`。

⚠️ **順序不能亂**。最後一步（綁插件）之前，iOS build 必須全程保持綠燈；綁定之後才會開始出現轉譯錯誤。

---

## 最終目錄結構

```
<Repo>/
├── Package.swift                  ← SPM 是唯一的 source of truth
├── Skip.env                       ← 產品名 / bundle id / Android 套件名
├── Project.xcworkspace/           ← 給 Xcode 與 skip CLI 的統一入口
├── Sources/
│   └── <Module>/
│       ├── Skip/skip.yml          ← 必須在模組目錄下
│       ├── App/                   ← AppDelegate / SceneDelegate / AppRouter / Deeplink
│       ├── Android/AppEntry.swift ← #if SKIP，Android 進入點型別
│       ├── Pages/                 ← M/VM/V/C 功能程式碼
│       └── Shared/
├── Darwin/                        ← iOS App 外殼
│   ├── <Module>.xcodeproj/
│   ├── <Module>.xcconfig
│   ├── Info.plist
│   ├── Assets.xcassets/
│   └── Sources/Main.swift         ← @main 住在這裡
├── Android/                       ← Android Gradle 專案
│   ├── app/build.gradle.kts
│   ├── app/src/main/AndroidManifest.xml
│   ├── app/src/main/kotlin/Main.kt
│   └── settings.gradle.kts
└── Tests/
```

💡 快速取得 `Darwin/` 與 `Android/` 的骨架：另開暫存目錄跑一次
`skip init --transpiled-app <Module>`，把產出的兩個資料夾複製過來再改。比手寫可靠。

---

## Step 1 — `Package.swift`

先讓 SPM 看得到既有程式碼，**這一步不要加任何 Skip 相依**。

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "<Module>",
  defaultLocalization: "zh-Hant",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "<Module>", type: .dynamic, targets: ["<Module>"]),
  ],
  targets: [
    .target(name: "<Module>", path: "Sources/<Module>"),
    .testTarget(name: "<Module>Tests", dependencies: ["<Module>"], path: "Tests"),
  ]
)
```

⚠️ `swift build` 會失敗（SPM 在 macOS 主機預設 macOS SDK，找不到 `UIKit`）。這是正常的，一律用：
```
xcodebuild -scheme <Module> -destination 'generic/platform=iOS Simulator' build
```

**驗收**：`** BUILD SUCCEEDED **`。

---

## Step 2 — 搬到 `Sources/<Module>/`

```
git mv Sources/App Sources/Pages Sources/Shared Sources/<Module>/
```

同步更新 `Package.swift` 的 `path` 與測試的 `@testable import`。

**為什麼**：Skip 的插件會去 `<targetPath>/Skip/skip.yml` 找設定。模組名、資料夾名、`Skip.env` 的 `PRODUCT_NAME`、`@testable import` 四者必須一致，後續 Skip 產生 `Darwin/*.xcconfig` 與 `Android/settings.gradle.kts` 時才對得上。

用 `git mv` 保留檔案歷史。**不改任何檔案內容**。

---

## Step 3 — Skip 設定檔

### `Skip.env`（repo 根目錄）

```
PRODUCT_NAME = <Module>
PRODUCT_BUNDLE_IDENTIFIER = com.your.bundle.id
ANDROID_PACKAGE_NAME = yourmodule.demo
ANDROID_APPLICATION_ID = com.your.bundle.id
```

⚠️ **最容易搞混的一組**：

| 欄位 | 意義 | 要跟誰一致 |
|---|---|---|
| `ANDROID_PACKAGE_NAME` | Kotlin **套件名** | `Android/app/src/main/kotlin/Main.kt` 的 `package` 那行 |
| `ANDROID_APPLICATION_ID` | Android **App ID** | 通常等同 iOS 的 bundle id |

把 bundle id 填進 `ANDROID_PACKAGE_NAME` 會導致 gradle 解析不到模組。

### `Sources/<Module>/Skip/skip.yml`

```yaml
mode: 'transpiled'
```

### 加上 Skip 相依（**但先不要綁插件**）

```swift
dependencies: [
  .package(url: "https://source.skip.tools/skip.git", from: "1.9.3"),
  .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
],
targets: [
  .target(
    name: "<Module>",
    dependencies: [.product(name: "SkipUI", package: "skip-ui")],
    path: "Sources/<Module>"
    // plugins: 先留空，見 Step 7
  ),
]
```

**驗收**：`skip doctor` 綠燈，且 iOS build 仍為 `** BUILD SUCCEEDED **`。

---

## Step 4 — `Darwin/` iOS 外殼

### `@main` 該住哪 —— 保留 UIKit 生命週期的關鍵

iOS 從 App target 的執行檔找 `main` 符號，**框架裡的 `@main` 不會被當成進入點**。所以 `@main` 必須離開 SPM library。

有三條路，選第一條：

| 路線 | 做法 | 代價 |
|---|---|---|
| ✅ **UIApplicationMain shim** | `Darwin/Sources/Main.swift` 呼叫 `UIApplicationMain(..., AppDelegate.self)` | `AppDelegate` 拿掉 `@main`、少數型別加 `public`，約 20 行 |
| ❌ SwiftUI `@main struct App` | 用 `UIApplicationDelegateAdaptor` 代理 | UIKit 生命週期被 SwiftUI 包住，進入點架構變形 |
| ❌ 把 UIKit 檔案全搬到 `Darwin/` | 物理隔離 | 跨模組後要在 View/VM/Router 上灑幾十個 `public` |

```swift
// Darwin/Sources/Main.swift
import UIKit
import <Module>

UIApplicationMain(
  CommandLine.argc,
  CommandLine.unsafeArgv,
  nil,
  NSStringFromClass(AppDelegate.self)
)
```

配合修改：`AppDelegate` 拿掉 `@main`、改 `public`（含 `public override init()`）；`SceneDelegate` 改 `public`，其 `UISceneDelegate` 協定方法一併補 `public`。

### `Info.plist` 的地雷

```xml
<key>UISceneDelegateClassName</key>
<string><Module>.SceneDelegate</string>
```

⚠️ **不要用 `$(PRODUCT_MODULE_NAME).SceneDelegate`**。xcconfig 通常把 App target 的模組名設成 `<Module>App`，但 `SceneDelegate` 住在 library（模組名 `<Module>`）。用變數會指到不存在的類別，開機即崩。

### `Darwin/<Module>.xcconfig`

```
PRODUCT_NAME = <Module>
SKIP_ACTION = none
```

`SKIP_ACTION` 先設 `none`，等 Android 那側準備好再改成 `launch`（Step 8）。

**驗收**：
```
xcodebuild -project Darwin/<Module>.xcodeproj -scheme "<Module> App" \
  -destination 'generic/platform=iOS Simulator' build
```
這是第一個真正可以啟動的 `.app`（先前綠燈的都只是 framework）。

---

## Step 5 — `Project.xcworkspace`

repo 根目錄放一個只含單一 `FileRef` 的 workspace，指向 `Darwin/<Module>.xcodeproj`（該 project 已經引用了 `..` 的 SPM package，會自動看到 `Package.swift`）。

**為什麼**：讓 `open Project.xcworkspace` 與 `skip app launch --ios` 都不需要額外參數。

**驗收**：`skip app launch --ios --plain` 成功，模擬器上的行為與遷移前一致。

---

## Step 6 — `Android/` 外殼

從 `skip init` 的產出複製 `app/build.gradle.kts`、`AndroidManifest.xml`、`Main.kt`、launcher icons、`gradle.properties`、`settings.gradle.kts`。

`Main.kt` 靠兩個 `typealias` 對接 Swift 側，**名稱是 Skip 的固定契約**：

```kotlin
package yourmodule.demo

typealias AppRootView = <Module>RootView
typealias AppDelegate = <Module>AppDelegate
```

對應的 Swift 側（`Sources/<Module>/Android/AppEntry.swift`，整檔 `#if SKIP`）：

```swift
#if SKIP
import SwiftUI

public struct <Module>RootView: View {
  public init() {}
  public var body: some View { /* 見 android-router.md */ }
}

public final class <Module>AppDelegate {
  public static let shared = <Module>AppDelegate()
  private init() {}

  public func onInit() {}
  public func onLaunch() {}
  public func onResume() {}
  public func onPause() {}
  public func onStop() {}
  public func onDestroy() {}
  public func onLowMemory() {}
}
#endif
```

💡 iOS **不使用**這兩個型別，進入點仍是 `UIApplicationMain → AppDelegate → SceneDelegate → UITabBarController`。

**預期失敗**：此時 `cd Android && gradle :app:assembleDebug` 會報
```
Could not locate transpiled module for <Module> in .../.build/plugins/outputs
```
這是正確的 —— 還沒綁插件，沒有 Kotlin 產出。這個錯誤就是進入 Step 7 的信號。

---

## Step 7 — 綁定 `skipstone` 插件（轉捩點）

```swift
.target(
  name: "<Module>",
  dependencies: [.product(name: "SkipUI", package: "skip-ui")],
  path: "Sources/<Module>",
  plugins: [.plugin(name: "skipstone", package: "skip")]
),
```

⚠️ **這一刻起 iOS build 會變紅**，而且是刻意的。`skipstone` 是 eager 的：一旦綁定，每次 `xcodebuild` 都會跑轉譯。

接下來就是第 1 關的 fail-fast 循環：

1. 建置 → 看唯一那一個錯誤
2. 對照主檔的眉角表修掉
3. 重建 → 下一個錯誤
4. 重複直到整個模組轉譯乾淨

**建議先做的事**：把所有 UIKit-only 檔案整檔包 `#if !SKIP`（眉角 #2），可以一次消掉一整類錯誤：
- `App/AppDelegate.swift`、`App/SceneDelegate.swift`、`App/AppRouter.swift`、`App/Deeplink.swift`
- 每個 `Pages/*/​*HostController.swift`

💡 錯誤前線的移動順序**不可預測**。不要假設「包完 C 層就只剩 VM 問題」—— 每一層都有各自的 Skip 不相容寫法（View 有 `case where`、VM 有巢狀 enum、C 層有建構子委派）。照 Skip 報什麼修什麼。

**驗收**：iOS `** BUILD SUCCEEDED **`，且 `.build` 底下產生了 `.kt` 檔。

---

## Step 8 — 開啟 Android 流程

`Darwin/<Module>.xcconfig`：
```
SKIP_ACTION = launch
```

之後每次 iOS build 都會連帶跑 Android gradle 流程 —— 第 2 關（Kotlin 編譯）從這裡開始。

先讓**一個最單純的 feature**（沒有 API、沒有 deeplink、呼叫點最少的那個）在 Android 跑起來，其餘的先用 `#if !SKIP` 擋著，之後一個一個放行。

**驗收**：
```
skip app launch --android --plain
skip app launch --ios --plain
```
兩邊都成功，且 iOS 行為與遷移前完全相同。

---

## 檢查清單

- [ ] `swift build` 失敗是正常的，用 `xcodebuild -destination` 驗證
- [ ] 模組名 / 資料夾名 / `PRODUCT_NAME` / `@testable import` 四者一致
- [ ] `ANDROID_PACKAGE_NAME` 是 Kotlin 套件名，不是 bundle id
- [ ] `Info.plist` 的 `UISceneDelegateClassName` 寫死模組名，不用變數
- [ ] `@main` 在 `Darwin/Sources/Main.swift`，不在 library 裡
- [ ] 插件是最後才綁的
- [ ] `SKIP_ACTION` 在 Android 外殼就緒前保持 `none`
