// 驗證 swift-concurrency skill 的四條骨幹主張。
// 觀測指標是 onMainThread() —— 在 Apple 平台上主 actor 就跑在主執行緒，
// 因此可作為「有沒有離開主 actor」的代理指標。
//
// 跑法見 README.md（同一份原始碼要用兩種設定各編一次）。

import Foundation

// pthread_main_np() 而非 Thread.isMainThread —— 後者在 Swift 6 的 async context 被標為
// unavailable（編譯器認為你應該改標 @MainActor），但這裡要觀測的正是「現在到底在不在主緒」
nonisolated func onMainThread() -> Bool { pthread_main_np() != 0 }

nonisolated func nonisolatedAsyncCheck() async -> Bool {
  onMainThread()
}

@MainActor
func runProbe() async {
  // 1. 普通 Task —— skill 主張：6.2+ 從 @MainActor 起的 Task 仍在主 actor
  let plainTask = await Task { onMainThread() }.value

  // 2. Task { @concurrent in } —— skill 主張：從主 actor 外起跑
  let concurrentTask = await Task { @concurrent in onMainThread() }.value

  // 3. Task.detached —— skill 主張：不繼承呼叫端 actor
  let detached = await Task.detached { onMainThread() }.value

  // 4. nonisolated async func —— SE-0461 主張：預設跑在呼叫端 actor
  //    （這條只有在 NonisolatedNonsendingByDefault 開啟時才成立）
  let nonisolatedAsync = await nonisolatedAsyncCheck()

  print("PROBE plainTask.onMain=\(plainTask)")
  print("PROBE concurrentTask.onMain=\(concurrentTask)")
  print("PROBE detached.onMain=\(detached)")
  print("PROBE nonisolatedAsync.onMain=\(nonisolatedAsync)")
}

await runProbe()
