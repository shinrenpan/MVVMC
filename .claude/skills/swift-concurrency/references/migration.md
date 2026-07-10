# DispatchQueue 遷移規範

> 基準 Swift 6.3（本地 toolchain 6.3.1）；並發模型脈絡見 `SKILL.md`〈Swift 6.2+ 心智模型〉。

## 強制原則

- ❌ 新代碼禁止使用 `DispatchQueue`，一律改用 Swift Concurrency
- ✅ 舊代碼遇到需要修改時，順手遷移，不要求一次全部重構

## 對照表

| DispatchQueue | Swift Concurrency |
|---|---|
| `DispatchQueue.global().async { }` | `Task { }` |
| `DispatchQueue.main.async { }` | `await MainActor.run { }` 或在 `@MainActor` context 內直接執行 |
| `DispatchQueue.main.asyncAfter(deadline: .now() + N)` | `try? await Task.sleep(for: .seconds(N))` |
| `DispatchQueue.global().async { heavyWork(); DispatchQueue.main.async { } }` | `Task { let r = await heavyWork(); await MainActor.run { } }` |

> **關於 `MainActor.run`**：它只用於「從**非 isolated** context 跳回主 actor」。若程式碼已在 `@MainActor` context（例如 MVVMC 的 ViewModel 全是 `@MainActor`），或 `Task` 起自 `@MainActor`（Task 會繼承主 actor），就**不需要**再包 `MainActor.run`——直接寫即可。上表末列的 `MainActor.run` 只在該 `Task` 起自非 isolated 環境時才需要。

> **`DispatchQueue.global()` → 真的要背景執行**：6.2+ 從 `@MainActor` 起的 `Task { }` **仍在主 actor**，不等於背景。若原本用 global queue 是為了離開主執行緒（重運算、阻塞 I/O），對應寫法是 **`@concurrent` async func**（見 `SKILL.md`），而非只包一層 `Task { }`。

## 遷移判斷流程

```
這段 DispatchQueue 代碼在 async context 裡嗎？
├── 是 → 直接替換成對應的 Swift Concurrency 寫法
└── 否（在普通 sync func 裡）
    ├── 這個 func 適合改成 async 嗎？
    │   ├── 是 → 先將 func 改為 async，再替換內部
    │   └── 否 → 用 Task {} 包起來，保持 func 為 sync
    └── 完成後確認呼叫端是否需要對應調整
```
