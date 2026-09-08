// 驗證：Task 取消時，defer 與「寫在 await 之後那一行」各自會不會執行
actor Flag {
    var deferRan = false
    var afterAwaitRan = false
    func markDefer() { deferRan = true }
    func markAfter() { afterAwaitRan = true }
}


@main
struct Probe {
    static func main() async {
        // 情境 A：throwing await（取消時會丟 CancellationError）
        let a = Flag()
        let ta = Task {
            defer { Task { await a.markDefer() } }
            try? await Task.sleep(for: .seconds(5))   // 取消 → 立刻返回
            await a.markAfter()
        }
        try? await Task.sleep(for: .milliseconds(50))
        ta.cancel()
        _ = await ta.value
        try? await Task.sleep(for: .milliseconds(100))
        print("A（try? await sleep）: defer=\(await a.deferRan)  afterAwait=\(await a.afterAwaitRan)")

        // 情境 B：throwing await 且用 try（取消 → 拋出 → 函式提前離開）
        let b = Flag()
        let tb = Task {
            defer { Task { await b.markDefer() } }
            try await Task.sleep(for: .seconds(5))
            await b.markAfter()
        }
        try? await Task.sleep(for: .milliseconds(50))
        tb.cancel()
        _ = try? await tb.value
        try? await Task.sleep(for: .milliseconds(100))
        print("B（try await sleep，會拋）: defer=\(await b.deferRan)  afterAwait=\(await b.afterAwaitRan)")
    }
}
