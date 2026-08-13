# ConcurrencyProbe

Checks the four load-bearing claims in the `swift-concurrency` skill against the actual toolchain, under two different build configurations. It exists because those claims drive real decisions ("does this need `@concurrent`?") and were previously taken on faith.

`pthread_main_np()` is the observation point rather than `Thread.isMainThread` — the latter is marked unavailable in async contexts under Swift 6, and here the whole question *is* which thread we ended up on. On Apple platforms the main actor runs on the main thread, so this is a valid proxy for "did we leave the main actor".

## Running it

```bash
cd Experiments/ConcurrencyProbe

# A: Swift 6 language mode only
swiftc -swift-version 6 probe.swift -o probe_a && ./probe_a

# B: plus approachable concurrency (what SWIFT_APPROACHABLE_CONCURRENCY: YES turns on)
swiftc -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault probe.swift -o probe_b && ./probe_b
```

## Result (Swift 6.3.1 — 2026-08)

Called from a `@MainActor` context; `onMain=true` means the work stayed on the main actor.

| Construct | A: Swift 6 mode | B: + approachable |
|---|---|---|
| `Task { }` | **true** | **true** |
| `Task { @concurrent in }` | false | false |
| `Task.detached { }` | false | false |
| `nonisolated func f() async` | **false** | **true** |

Conclusions:

1. **`Task { }` does not leave the main actor.** Wrapping heavy work in a plain `Task` from a ViewModel buys you nothing — this is the single most common misconception the skill exists to correct.
2. **`@concurrent` and `.detached` both leave**, as documented.
3. **`nonisolated async` flips behaviour depending on one build setting.** Without `NonisolatedNonsendingByDefault` it hops off the main actor (the pre-6.2 mental model); with it, it runs on the caller's actor (SE-0461).

Point 3 is why the skill's Fast Path insists on reading the project's concurrency settings before giving any advice: the same source line has two opposite behaviours, and nothing in the code tells you which one you get.

## Type-level checks (Swift 6.3.1 — 2026-08)

These are compile-or-not questions rather than runtime observations, so they live here as reproducible one-liners instead of source files (some are expected to *fail* to compile).

```bash
# 1. Is a @MainActor function type implicitly @Sendable?  → YES
echo 'func r(_ f: @escaping @Sendable (Int) -> Void) {}
@MainActor func t() { let a: @MainActor (Int) -> Void = { _ in }; r(a) }' > /tmp/c.swift
swiftc -swift-version 6 -typecheck /tmp/c.swift
# Fails — but the message proves the point: it reports the value's type as
# '@MainActor @Sendable (Int) -> Void' and rejects the conversion because it
# "loses global actor 'MainActor'". Implicitly Sendable: yes. Convertible to a
# non-isolated @Sendable: no.

# 2. Does an un-annotated closure need @Sendable to cross into Task.detached?  → NOT ALWAYS
echo '@MainActor func t() { let s: (Int) -> Void = { _ in }; Task.detached { s(1) } }' > /tmp/c.swift
swiftc -swift-version 6 -typecheck /tmp/c.swift   # compiles — region-based isolation proves it safe

# 3. Do computed properties participate in Equatable synthesis?  → NO
echo 'struct T: Equatable { var a = 0; var f: (() -> Void) { {} } }
let x = T() == T()' > /tmp/c.swift
swiftc -swift-version 6 -typecheck /tmp/c.swift   # compiles despite the non-Equatable computed type
```

Check 2 is the reason `mvvmc-view` no longer claims that an un-annotated `send` "will need `@Sendable` later" — that was an overstatement. Check 3 backs the `mvvmc-model` rule that a computed property costs nothing in `Equatable` terms.
