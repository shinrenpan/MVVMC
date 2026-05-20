#if DEBUG
extension PostDetailViewModel.Post {
  static let mock: Self = .init(
    id: 1,
    title: "Understanding MVVMC",
    body: "MVVMC separates concerns across four strictly defined layers: Model, ViewModel, View, and Controller."
  )
}
#endif
