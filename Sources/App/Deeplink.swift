import UIKit

// MARK: - Deeplink

enum Deeplink {
  case settings
  case postDetail(id: Int)
}

// MARK: - URL Parsing

extension Deeplink {
  init?(url: URL) {
    guard url.scheme == "mvvmc" else { return nil }
    switch url.host {
    case "settings":
      self = .settings
    case "posts":
      guard let idString = url.pathComponents.dropFirst().first,
            let id = Int(idString) else { return nil }
      self = .postDetail(id: id)
    default:
      return nil
    }
  }
}

// MARK: - Destination

extension Deeplink {
  /// deeplink 的目的地是「一組 VC ＋ 一個呈現意圖」，不是單一 VC。
  ///
  /// why：只 present 一個詳情頁，冷啟動時會得到一個**孤兒頁面**——使用者的心智模型是
  /// 「往回按可以看到列表」，而那個 stack 是空的。真正該是 modal 的（獨立 onboarding、
  /// 強制更新）才用 `.present`。
  enum Destination {
    /// 切到某個分頁，並把這一組 VC 推上該分頁的 stack（第一個是脈絡，最後一個是目的地）
    case navigate(tab: Int, stack: [UIViewController])
    /// 真正該是 modal 的：獨立於導航脈絡、看完就關
    case present(UIViewController)
  }

  @MainActor func makeDestination() -> Destination {
    switch self {
    case .settings:
      // 設定與任何分頁的脈絡無關，關掉就回到原本在看的東西 → modal
      // 它的關閉入口由 SettingsView 的 .toolbar 自己提供（見 mvvmc-navigation）
      return .present(SettingsHostController(viewModel: .init()))

    case let .postDetail(id):
      // 詳情頁屬於 Posts 分頁的脈絡 → 切分頁 + 推上去，系統返回鈕自然存在
      return .navigate(tab: 0, stack: [
        PostDetailHostController(id: id, title: "Post #\(id)", body: "")
      ])
    }
  }
}
