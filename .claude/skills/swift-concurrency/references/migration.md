# DispatchQueue 遷移規範

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
