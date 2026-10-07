import SwiftUI
import UIKit

// 變因全部走啟動參數，app 自己完成「單欄 → 兩欄」並印出一行 RESULT 後結束，
// 不需要旋轉或點擊。見 ../README.md。
//
//   -container hstack|arrangement   兩欄容器
//   -view fixed|sticky|none         UIView 怎麼自報 intrinsicContentSize
//   -fit 0|1                        UIViewRepresentable 是否實作 sizeThatFits
//   -start 0|1                      0 = 先單欄再轉兩欄（轉換）；1 = 一開始就兩欄（對照）
struct Config {
  let container: String
  let view: String
  let fit: Bool
  let start: Int

  static let current: Config = {
    let d = UserDefaults.standard
    return Config(
      container: d.string(forKey: "container") ?? "hstack",
      view: d.string(forKey: "view") ?? "sticky",
      fit: d.bool(forKey: "fit"),
      start: d.integer(forKey: "start")
    )
  }()
}

@MainActor enum Probe {
  static weak var probeView: UIView?
  static var column: CGRect = .zero
  static var other: CGRect = .zero
}

// MARK: - 被測的 UIView

/// fixed：intrinsicContentSize 固定 120×50（小於任何欄寬）
/// sticky：自報「曾經被排到的最大寬度」——模擬 AdMob BannerView 轉向後寬度停在舊值
/// none：不自報（noIntrinsicMetric）
final class ProbeUIView: UIView {
  let mode: String
  private var widest: CGFloat = 120

  init(mode: String) {
    self.mode = mode
    super.init(frame: .zero)
    backgroundColor = .systemOrange
  }
  required init?(coder: NSCoder) { fatalError() }

  override var intrinsicContentSize: CGSize {
    switch mode {
    case "fixed": CGSize(width: 120, height: 50)
    case "sticky": CGSize(width: widest, height: 50)
    default: CGSize(width: UIView.noIntrinsicMetric, height: 50)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if mode == "sticky", bounds.width > widest {
      widest = bounds.width
      invalidateIntrinsicContentSize()
    }
  }
}

struct ProbeRepresentable: UIViewRepresentable {
  let mode: String
  func makeUIView(context: Context) -> ProbeUIView {
    let v = ProbeUIView(mode: mode)
    Probe.probeView = v
    return v
  }
  func updateUIView(_ uiView: ProbeUIView, context: Context) {}
}

/// 與 ProbeRepresentable 唯一差別：實作 sizeThatFits（與 FoodEntropy BannerAdView 同一寫法）
struct FittingProbeRepresentable: UIViewRepresentable {
  let mode: String
  func makeUIView(context: Context) -> ProbeUIView {
    let v = ProbeUIView(mode: mode)
    Probe.probeView = v
    return v
  }
  func updateUIView(_ uiView: ProbeUIView, context: Context) {}
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: ProbeUIView, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? 120, height: 50)
  }
}

// MARK: - 欄位

/// 對應 FoodEntropy 的首頁欄：頂部 safeAreaInset 放 representable，左右 16pt padding
struct HomeColumn: View {
  let config: Config
  var body: some View {
    Color(.systemGroupedBackground)
      .safeAreaInset(edge: .top) {
        Group {
          if config.fit {
            FittingProbeRepresentable(mode: config.view)
          } else {
            ProbeRepresentable(mode: config.view)
          }
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
      }
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { Probe.column = $0 }
  }
}

struct OtherColumn: View {
  var body: some View {
    Color(.systemBlue).opacity(0.2)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { Probe.other = $0 }
  }
}

// MARK: - 容器

struct ProbeRoot: View {
  let config = Config.current
  @State private var twoColumns: Bool

  init() { _twoColumns = State(initialValue: Config.current.start == 1) }

  var body: some View {
    GeometryReader { proxy in
      let w = proxy.size.width
      let h = proxy.size.height
      container(w: w, h: h)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .task {
      try? await Task.sleep(for: .seconds(1.5))
      if !twoColumns { twoColumns = true }
      try? await Task.sleep(for: .seconds(1.5))
      report()
      exit(0)
    }
  }

  @ViewBuilder
  private func container(w: CGFloat, h: CGFloat) -> some View {
    switch config.container {
    case "arrangement":
      // ArrangementView 依自身長寬比決定分不分欄，所以用外框長寬比切換：
      // 單欄 = 高 > 寬，兩欄 = 寬 > 高。不靠旋轉。
      // 單欄必須比兩欄後的 primary 欄寬，否則 view 沒有經歷「先寬後窄」——第一版用 0.6
      // 單欄只有 401pt、兩欄 primary 是 456pt，什麼都量不到。
      let side = min(w, h)
      let size = twoColumns ? CGSize(width: w, height: min(h, w * 0.6)) : CGSize(width: side * 0.95, height: side)
      if #available(iOS 27.1, *) {
        ArrangementView {
          HomeColumn(config: config)
        } secondary: {
          OtherColumn()
        }
        .arrangementViewStyle(.split.axes(.horizontal))
        .frame(width: size.width, height: size.height)
      } else {
        Text("ArrangementView requires iOS 27.1")
          .task { print("RESULT unavailable"); exit(0) }
      }
    default:
      // 與 FoodEntropy ec0069f 同形：首頁固定在第二個位置、只增減左欄、兩欄都給確定寬度
      HStack(spacing: 0) {
        if twoColumns {
          OtherColumn().frame(width: w / 2)
        }
        HomeColumn(config: config).frame(width: twoColumns ? w / 2 : w)
      }
    }
  }

  private func report() {
    let col = Probe.column
    let other = Probe.other
    let v = Probe.probeView.map { $0.convert($0.bounds, to: nil) } ?? .zero
    let screenW = Probe.probeView?.window?.bounds.width ?? 0
    // 不用「欄位邊界」當基準：溢出的 view 會把欄位自己的 frame 一起撐大（第一版就被這個騙了，
    // 量到 overflow=0 而截圖明顯蓋到左欄）。改量兩個不會被撐的東西：
    //   intoOther = view 與另一欄重疊的寬度；offScreen = view 超出視窗右緣的寬度
    let intoOther = max(0, min(v.maxX, other.maxX) - max(v.minX, other.minX))
    let offScreen = max(0, v.maxX - screenW)
    func r(_ x: CGFloat) -> String { String(format: "%.0f", x) }
    print("RESULT container=\(config.container) view=\(config.view) fit=\(config.fit ? 1 : 0) start=\(config.start)"
      + " screen=\(r(screenW)) other=[x=\(r(other.minX)) w=\(r(other.width))] homeCol=[x=\(r(col.minX)) w=\(r(col.width))]"
      + " view=[x=\(r(v.minX)) w=\(r(v.width))] intoOther=\(r(intoOther)) offScreen=\(r(offScreen))")
  }
}

@main
struct ProbeApp: App {
  var body: some Scene {
    WindowGroup { ProbeRoot() }
  }
}
