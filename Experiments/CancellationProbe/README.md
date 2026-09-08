# CancellationProbe

Answers one question the `mvvmc-viewmodel` form-page rule depends on: **when a `Task` is cancelled, does the line after an `await` still run — and does `defer` still run?**

It exists because the spec's re-submit guard (`state.isSubmitting`) is only correct if its reset is guaranteed to execute. The rule was originally written asserting that "the line after `await` will not run" **unconditionally**, and that turned out to be half true.

## Running it

```bash
cd Experiments/CancellationProbe
swiftc -swift-version 6 -parse-as-library probe.swift -o probe && ./probe
```

## Result (2026-09-08, Swift 6 language mode)

```
A（try? await sleep）  : defer=true  afterAwait=true
B（try await sleep）   : defer=true  afterAwait=false
```

| Submit path | `defer` runs? | Line after `await` runs? |
|---|---|---|
| `try await` — cancellation propagates | ✅ | ❌ |
| `try?` / non-throwing await — cancellation swallowed | ✅ | ✅ |

## What this changed in the spec

`mvvmc-viewmodel/references/patterns.md`〈表單頁〉originally said the reset written after `await` "will not run". That is **only** true when the cancellation is actually thrown — which is the correct way to write it, but not the only way people write it.

The rule now states both rows and keeps the same conclusion for a better reason: **`defer` is safe in both cases, so it is the only form that does not require first deciding which row you are in.**

## Why this expires

Cancellation is a cooperative, library-level behaviour: whether `Task.sleep` (or any given `await`) throws on cancellation is a property of that API, not of the language. A future toolchain — or simply a different call in that position — can move a case from row B to row A. Re-run before trusting the table.
