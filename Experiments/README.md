# Experiments — how this spec gets verified

The skills in `.claude/skills/` are prose. Prose can be internally consistent and still be wrong, unenforceable, or full of holes. This directory holds the machinery that checks which of those is true, plus what that machinery has actually caught.

Read this before starting another round of spec work — the useful thing to carry forward is not *what changed* (git log has that) but *which kind of check finds which kind of problem*.

---

## The five axes

Each answers a different question. They are not interchangeable, and passing one says almost nothing about the others.

### 1. Measurement — "is this claim about the world true?"

`ViewSplitProbe/`, `ConcurrencyProbe/`, `CancellationProbe/`

Take a factual assertion the spec relies on and put it in front of a compiler or a simulator. Both probes are re-runnable; both README files record the toolchain version, because these answers expire.

**Caught:** six pieces of received wisdom that turned out to be false — **all three of `mvvmc-view` §8's claims at once** — the problem (`ForEach` misplaces a child's `@State` on reorder), the fix (`.id(item.id)` corrects it — with and without produced *identical* numbers), and the side effect (adding it resets the state). A prescription for a problem that didn't reproduce, with no measurable effect, guarding against something that doesn't happen (`ViewSplitProbe`); a rule asserting that a reset written after `await` "will not run" on cancellation, which holds only when the cancellation is actually *thrown* (`CancellationProbe`); and three older ones — `AnyView` does *not* stop a child's body from being skipped; "precise injection" cannot be justified on performance grounds (passing the whole object redraws *less*); `nonisolated async` behaviour flips depending on one build flag.

**Use when:** the spec says "X is faster / X breaks Y / X behaves like Z". Especially when it sounds like something everyone knows.

> **The probe can be the thing that is wrong.** The first run of the reorder measurement gave `bodies=3`; a second run of identical code gave `0`. Swift Testing parallelises suites by default and the suites shared a counter singleton — one test's `reset()` was wiping another's in-flight counts. **A spec change had already been written from the contaminated numbers.** Before trusting any probe output: run it twice and compare. A number that moves is not a measurement, and nothing about the harness announces the contamination.

> **Measure before writing a rule on top of an assertion — including a rule you are writing to fix a field report.** Within a single session, a shipped-app report identified a bug-level scenario derived from §8's stated side effect, a warning was written into the spec for it, and the probe then showed the side effect does not occur. The report reasoned correctly; the fix reasoned correctly; **the premise underneath both had never been checked.** An unverified assertion does not merely sit there being wrong — it generates plausible findings and plausible fixes, and each layer built on it looks more solid than the last.

> **An expiry trigger with fewer variables than the rule it guards will misfire — and it misfires by telling you to do the wrong thing, confidently.** `swift-concurrency` carried the instruction *"run `swift --version`; if it has reached 6.4, mark `withTaskCancellationShield` usable."* In 2026-09 the toolchain did reach 6.4, so the trigger fired exactly as designed — and following it would have marked an API usable that does not compile against the project's iOS 17 deployment target, because the SDK gates it at `@available(anyAppleOS 27.0, *)`. **Availability of an API is two independent variables** (toolchain version decides the *syntax*; deployment target vs `@available` decides the *call*) and the trigger only watched one. Contrast the `NonisolatedNonsendingByDefault` rule two sections down, which retires itself on *"the day the probe stops showing a difference"* — that one names the observation, not a proxy for it, and on the same 6.4 bump it correctly did **not** fire. → **Write the expiry condition as something the probe can observe, not as a version number you expect to correlate with it.**

> **The OS you run on and the SDK you build against are two variables, and upgrading Xcode moves both at once.** Re-measuring `ViewSplitProbe` on 2026-09-10 showed a reorder result flip from `bodies=3` to `bodies=0` on the iOS 27 simulator — which reads unmistakably as "iOS 27 changed SwiftUI's diffing", and would have been written up that way. **The iOS 26.4 simulator control also gave `0`**, killing that reading; swapping only `DEVELOPER_DIR` back to Xcode 26.4.1, against that same iOS 26.4 simulator, restored `3`. The variable was the **linked SDK**. That distinction is not cosmetic — it decides who is affected: an app rebuilt with the new Xcode gets the new behaviour *on old OS versions too*, while an app not yet rebuilt keeps the old behaviour *on the new OS*. → **Whenever a measurement moves after an Xcode upgrade, run both controls before naming a cause: the old OS on the new toolchain, and the old toolchain on the old OS.** Keep the previous Xcode installed for exactly this; `DEVELOPER_DIR=` swaps it per-command with no sudo and no global state.

### 2. Enforcement — "will an AI actually catch a violation?"

`ReviewProbe/`

Plant a known set of violations in plausible-looking code, hand it to an agent that has not seen the ground truth, compare. **The reviewer must not be able to read the answer** — that is the whole experiment.

**Caught:** nothing at first (31/31, zero false positives), which was itself the lesson — see the pitfalls below.

**Use when:** you have rewritten a rule and want to know it still bites. Also the right check after any *reduction* in the spec.

> **Which documents to include is not a question about their subject.** `mvvmc-skip` was skipped by all three readers on the reasoning "Android-specific, small interaction surface with the four layers". That was wrong, and wrong in a regular way: **its interaction surface is not small — the interactions simply live in the five skills it exempts, not in itself.** Every "on Android, write it this way" entry is an exemption from an iOS rule, and none of them had been carried back. Running the review skill on such a project produces five false findings, and applying them silently breaks the Android build's rendering. → **Rank a document for adversarial reading by how many exceptions/exemptions/"here it's different" clauses it contains, not by its topic.** A document made entirely of exemptions has the largest surface of all.
>
> **What happened to this one (2026-09-11).** The four scope notes were carried back (`mvvmc-hostcontroller`, `mvvmc-navigation`, `mvvmc-view`, `mvvmc-viewmodel` each now say "stop at the `#else` branch, those deviations are mandated, do not file against this skill"; `mvvmc-model` has none). **`mvvmc-review` still has zero** — and the checklist is where a check item actually fires, so a reviewer working down the list is not saved by a note in a skill it never opens. Rather than carry five unverified exemptions into the only enforcement path, `mvvmc-skip` was **frozen**: marked as unverified notes, excluded from per-round consistency checks, and barred from being used to derive or amend any iOS rule. The unfreeze condition is a project that has actually built with Skip. → **When a document is the largest exemption surface *and* nothing can verify it, quarantining it is cheaper than propagating it.** Propagation moves unverifiable claims into the place that enforces them.

> **Genre matters, and axis 5 has a blind spot.** Adversarial reading looks for two rules that collide — which requires prose that *argues*. A checklist (`mvvmc-review`'s Pass 3) has no arguments, only entries, so the technique returns nothing there. Checklists need the mirror method: **bidirectional coverage audit** — for each upstream rule, is there an entry? for each entry, does the rule still read that way? for each entry, is the file it needs even in the scan scope? The third direction found a check whose output was ✅ based on **zero files read** — and a false pass is worse than a false finding, because nobody argues with it. A 2026-09 audit found 14 "do not file this" exemptions upstream and **0** carried into the review skill; the transfer loss is structural, since a checklist's value is brevity and exemptions are all qualifiers.

### 3. Repair — "can the spec guide a fix, not just a diagnosis?"

`ReviewProbe/` (second half)

Same broken code, but the agent must fix it and the result must compile. Finding a problem and repairing it correctly are different abilities.

**Caught:** the repair agent hit the same spec contradiction as a generation agent had, from the opposite direction — two independent tasks colliding with one hole is far stronger evidence than either alone.

### 4. Generation — "what happens where there is no rule?"

`GenerationProbe/`

Give a product requirement, allow the skills, **forbid reading `Sources/`**. Without existing code to imitate, the agent must derive everything from the prose — and where the prose is silent, it has to invent something and say so.

The deliverable that matters is not the code. It is the **gap list**: every decision the rules didn't cover, every place two rules pulled in different directions. Ask for it explicitly, and state that "no gaps found" is an acceptable answer, or you will get invented ones.

**Caught:** by far the most — broken examples that don't compile, two rules that cannot both be satisfied, and whole scenarios (pagination, forms, polling, deep return) that the spec had never addressed.

**Use when:** always, if you only run one axis. Vary the requirement shape between runs: display-only → flow with intermediate state → multi-level navigation. Each shape hits a different part of the spec.

### 5. Adversarial reading — "which pairs of rules deadlock?"

No dedicated directory; done by hand.

Extract every hard prohibition across all skills, then reason about which combinations become unsatisfiable in some concrete situation. This is the only proactive axis — the other four wait for an agent to walk into the problem.

**Caught:** Preview forbids hitting the network, but a View's `.task` always runs during Preview rendering — two rules, written months apart, in direct conflict. The demo had been violating its own spec.

**Use when:** after adding several rules in one sitting. New rules multiply the interaction surface faster than they add coverage.

### 6. Field reports — "what happens to a spec that ships?"

No directory; run by asking the sessions that built real products with these skills.

The other five axes all test the spec **as a document**. This one tests what happens to it in the 33 days between a rule being written and reaching the project that needs it. Run 2026-09 against three shipped App Store apps.

**Caught five failure mechanisms, and not one of them is visible to the other five axes** — because all five happen *outside* the spec text:

| Mechanism | What it looks like |
|---|---|
| **Delivery failure** | `mvvmc-navigation` existed for **33 days** with no `~/.claude/skills/` symlink. Two of three projects wrote their Router with no access to it. One of them *cited the skill by name* in its planning doc — a file it could not open |
| **Back-propagation failure** | A Swift 6 violation in the demo's `AppRouter` was hit by one downstream project, not pushed back, and re-discovered by a second project **64 days** later |
| **Circular authorization** | Agent A records its own deviation in the project's `CLAUDE.md`; agent B reads the skill, sees the conflict, and **cites that note as independent authority**. It never was — it is agent A's deviation |
| **Precedent over spec** | During compliance work the codebase is a stronger normative signal than the skill. **Negative conditions ("unless X, don't do Y") almost always lose**, because a codebase shows examples of "did it" and never of "deliberately didn't" |
| **Rationale lost in migration** | A design decision was documented, adopted, and then deleted in a docs reorg. The code survived; the reason did not. The modifier it protects now reads as freely swappable |

> **Two axes, not one.** Where a rule *came from* and what has *verified* it are independent, and a rule can score low on the first while scoring high on the second — the demo is exactly that case (worthless as a source, strongest available check for unimplementable rules). Judging verification by the standards of provenance is how "the demo agrees with the spec by construction, so it tells us nothing" gets written down, and it was written down here before this round corrected it.

**Use when:** the spec has shipped to at least one project you did not write. It is the only axis that can see these, and none of them are fixed by writing better rules.

**Pitfalls specific to this axis** — all three cost real time:

- **Version skew.** Reporters describe today's code against today's spec. Most "violations" were compliance with the spec *as it stood that week*. **Date every finding before believing it**: `git log --diff-filter=A` on the rule, first-commit date on the file. `git show $(git rev-list -1 --before=<date> HEAD):<skill path>` recovers the text they actually had.
  **Apply the same filter to retractions, at the moment they are made.** One reporter withdrew seven findings as "I claimed the spec was silent without reading it"; dating them afterwards showed **five of the seven were rules that did not exist yet**. Those are not discoverability failures — they are independent convergence, the strongest evidence a rule can get. Filter at the *entry* to the retraction, not the exit: a misclassified retraction poisons the methodology sample before anyone thinks to re-check it.
- **Memory is not evidence.** Reporters answer from what they *remember the spec saying*. Across three projects, ~10 claimed gaps turned out to be rules that existed, sometimes verbatim, sometimes with the reporter's own reasoning already written in a parenthetical. **Require a re-runnable command for every claim**; label the rest as inference. The gap between "what the rule says" and "what the practitioner remembers" is itself the measurement — it quantifies discoverability — but the two must be recorded separately.
- **Coverage claims are unverifiable.** One reporter stated it had read every skill; it had opened none of the two under discussion, and disclosed this only later. Nothing in the transcript could have caught it. **Ask for the list of files actually opened**, never accept "read everything".

**What made a report trustworthy** was not the reporter's experience. All four participants — the spec's own session included — retracted findings during the round. Two failure points, not one: **claiming the spec is silent without having opened the file**, and **claiming to have read a file that was never opened**. The first is the common one; the second was self-disclosed and was otherwise undetectable from the transcript. Once every claim had to carry a re-runnable command and every reporter had to list the files actually opened, both stopped. → *A field report's credibility tracks whether the file was opened before sending, not who sent it.*

**How to stop.** "Keep going until nothing turns up" is unreachable, but "I can't think of another one" is weak. The strongest stop reached here was **enumerating a generator and closing it**: one reporter identified the pattern behind two findings (V-layer rules assume state changes are user-driven; polling makes them continuous and automatic, and the two rules live in files that don't cross-reference), then swept every place that generator could act — three sites. **The honest settlement, made by that reporter afterwards: one was real, one had already been handled, and the third turned out to rest on an unverified assertion and evaporated when measured.** *What survives is the method's ability to bound the search, not the hit count it reported at the time* — "I enumerated where this can occur and closed them" stays a bounded claim even when the count deflates; "I found nothing else" never was one.

**A converged report line is not a clean spec.** The reporter with the deepest coverage flagged its own limit: after reading fourteen documents and helping derive a dozen fixes, "I can't find any more" is partly "I can no longer see them". Record the outcome as *this line is exhausted*, never as *the spec is clean* — the second is a stamp, and the whole round was built to avoid producing one.

**What made it work:** the gate on findings was *counter-example*, not approval. Every proposed fix was sent back with "find a situation where following this produces wrong code" — and that caught two fixes that would have shipped bugs, plus one meta-error (fixing an over-broad rule by adding another rule written as a generalisation). **Approval would have caught none of them**; on one question two reporters gave directly opposite answers, so consensus would have been decided by whoever replied first.

**Recording the result:** write "no counter-example offered (date, sources)" plus a re-open condition — never "approved by N reviewers". The latter is a stamp, and this repo has a worked example of what a stamp does: a review that honestly found "no violations" while missing two, whose conclusion then sat in a project `CLAUDE.md` prefixed `don't "fix"`.

---

## Pitfalls learned the hard way

**A perfect enforcement score is not evidence of a good spec.** The review probe scored 31/31 with zero false positives, which read as "the spec is complete". The very next generation run found six real holes. Enforcement only tests the places where a rule exists; it is structurally blind to absence.

**Every round of fixes creates the next round's bugs.** Five times in a row, the newly-found problem was in material added during the *previous* round — the four-state skeleton, the performance measurement's shape, the optimistic-update/polling race, the Preview/polling deadlock. This is not carelessness; it is what happens when rules interact. It also means "keep going until nothing turns up" is an unreachable stopping condition. Stop on **severity** instead: when the findings stop being things that would produce a bug.

**Reduction must be verified in both directions.** After moving 357 lines out of the SKILL.md files, an enforcement run passed — but reviewing only needs "is this right?", while generating needs "how do I do it?", and the relocated material was exactly what generation depends on. A separate generation run was required, and it found four navigation problems the enforcement run could not have seen.

**Saying "this has no solution" beats saying nothing.** A generation agent specifically praised the swipe-back limitation for being written down as unsolved: *"明講沒解比沒寫更有用"*. Silence gets read as "not thought about yet", and the next reader re-derives the dead end from scratch.

**An upstream rule can dissolve a downstream problem.** After the wizard rule ("default to one feature") landed, the deep-return machinery it was written alongside became unnecessary — collapsing the wizard leaves a single callback level. When a section keeps growing in complexity, check whether an earlier decision is what's generating it.

---

## Axis 0 — subtraction: "what may enter, and what should leave?"

*(Added 2026-09-11. Every axis above hunts for things to **add**. None of them ever removes anything, and that turned out to be the spec's actual instability.)*

### The measurement that prompted it

Rule lines (`✅`/`❌`/`⚠️` bullets) across `.claude/skills/`, per release tag:

```
v1.0.0   36        added over the whole history:  117
v2.0.0   70        removed:                        12
v3.0.0  129        ratio:                        ~10:1
v3.5.0  141
```

Nearly 4× in four months, with essentially no deletions — and half of those twelve were rewrites, not removals. Set that beside axis 5's own warning, *"new rules multiply the interaction surface faster than they add coverage"*, and **"every round of fixes creates the next round's bugs" stops being bad luck and becomes arithmetic.** The interaction surface of 141 rules is more than ten times that of 36. No amount of care at the authoring end compensates for a body of rules that only grows.

A full inventory on the same day classified **217 normative statements** (counting table rows and prose rules, so finer-grained than the bullet count above) by what actually backs each one:

**115 of them — 53% — had nothing behind them at all**: not a measurement, not a demo file, not a field report. Per layer: M/VM 52 of 89, V/C 38 of 72, cross-cutting 25 of 56. The remainder are backed by the demo compiling them (`D`, the largest group), a probe (`M`, concentrated in `mvvmc-view` §7–§8 and `swift-concurrency`), or a shipped project (`F`, the rarest and the most valuable).

### The finding that matters more than the 53%

**"Unbacked" is not one category, and treating it as a deletion list is wrong.** It is three, and only the middle one pays:

1. **Axioms** — statements that *define* what MVVMC is: DTOs never leave M, `doAction` is the only entry point, C is the only layer that routes. These cannot be verified because they are not claims about the world; they are the architecture. `mvvmc-model`'s "State must never hold a DTO" says so in its own text — *"這是 M 層三段抽象存在的唯一理由"*. **Freeze them. Never ask for evidence.**

2. **Unaudited rules** — correct, consequential rules that simply nobody has checked. The same inventory turned up `mvvmc-view` §1 (test for content first, status second) sitting in this pile — **and `PostListView` was violating it in exactly the way §1 predicts**: it switched on status at the top level, so a failed pull-to-refresh replaced a populated list with an error screen. The ViewModel had preserved `state.posts` correctly; the View threw it away. **This is where the payoff is.** The rule was right, the consumer was broken, and the inventory is what surfaced it.

3. **Prudential judgments** — "in this situation, do it this way", about situations nobody here has run. `patterns.md`'s polling / pagination / form sections hold **19 hard rules** for scenarios `SPEC-COVERAGE.md` marks ❌. These are not wrong; they are **unearned**, and they are written in the imperative voice of category 1.

**The instability is category 3 wearing category 1's clothes.** A `❌` that has shipped nowhere and been measured nowhere still gets enforced by `mvvmc-review`, still has to be kept consistent with every new rule, and still multiplies the interaction surface — while carrying none of the authority its phrasing claims.

Across the whole spec the inventory found **16 unbacked hard prohibitions** (`❌` / 禁止 / 必須 / 一律), **9 of them in `swift-concurrency`** — the densest pocket, and the one where being confidently wrong costs the most.

### The entry gate

A statement may enter the spec as a `❌`/`✅` hard rule only if it is:

- **an axiom** — it defines the architecture, and is written in a place that says so; or
- **measured** — a probe in `Experiments/` produces the number, and the rule carries the toolchain version; or
- **compiled** — the demo demonstrates it, and `SPEC-COVERAGE.md` names the file; or
- **reported** — a shipped project hit it, and the entry says which.

Everything else enters as `⚠️` advisory, and **`mvvmc-review` must not file against advisory text.** Whichever it is, **the entry must say which** — that is what made this inventory possible at all, and what makes the next one cheap.

External documentation — Apple's agent skills, a framework's release notes, a well-argued blog post — is **a source of questions, never a source of rules**. The 2026-09-11 comparison against Apple's Xcode 27 skills produced roughly fifteen findings of which **four were wrong**, all in the same way: text compared against text generates conflicts that dissolve the moment you check this repo. The one that survived was the one Apple stated as a falsifiable mechanism, which was then *measured* (§7's table had never included the `send` closure the spec mandates). → **Let an external claim tell you what to measure. Never let it tell you what to write.**

### Expiry conditions must name an observation, not a version

Four rules currently expire on a version number or a date: `swift-concurrency` §versions, its module-default assertion, the `withTaskCancellationShield` note, and `patterns.md`'s toolchain stamp. Exactly one is written correctly — `cc:37`, which retires itself *"the day the probe stops showing a difference"* — and on the Swift 6.4 bump it was the only one that did not misfire.

Better than either: **make the claim verify itself.** `patterns.md`'s three Swift Testing examples carried a stamp (*"compiled under Swift 6.3.1 / Xcode 26.4.1"*) that nothing re-checked; moving them into `Tests/SwiftTestingTechniqueTests.swift` means every `xcodebuild test` re-verifies them and no schedule is needed. **A stamp expires silently. A test in the target cannot.**

### When to open a round, and when to stop

Open a round only on one of: **a toolchain major upgrade**, **a field report carrying a re-runnable command**, or **a probe result that moved**. Curiosity is not a trigger — a review invited to find something will always find something, and the record above shows that five times in a row what it found was material added by the previous round.

Stop on **severity**, never on exhaustion (see the pitfalls above) — and add the subtraction question to every round's close: **which rule did this round make unnecessary?** The wizard case is the worked example: an upstream decision dissolved the deep-return machinery downstream. A round that adds rules and removes none has not finished; it has deferred.

---

## Where this leaves the spec

As of 2026-08, after a full pass on all five axes: the *content* is close to complete — the last round's findings were all navigation problems (the rule existed, the index didn't point at it) rather than missing rules. What remains unverified is the one axis that cannot be run here: **sustained use on a real project**. Everything above tests the spec as a document and as instructions; none of it tests whether it is pleasant to work with over months.

> **Revised 2026-09-11 by axis 0.** "The content is close to complete" was measuring the wrong thing. Judged by coverage it was true; judged by *backing* it was not — 53% of the spec's normative statements had none, and one of them (§1's four-state ordering) was being violated by the demo in precisely the way it warns about. **Completeness and stability are different properties, and only the first one had been measured.** The spec does not need more content. It needs its existing content sorted into what is definitional, what is measured, and what is merely opinion in a hard voice.

When picking up spec work again, the cheapest useful move is a generation probe with a requirement shape that hasn't been tried yet (editing existing data, file upload with progress, offline/caching). If it comes back with only navigation-level findings, the content is holding.
