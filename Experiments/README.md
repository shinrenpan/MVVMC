# Experiments — how this spec gets verified

The skills in `.claude/skills/` are prose. Prose can be internally consistent and still be wrong, unenforceable, or full of holes. This directory holds the machinery that checks which of those is true, plus what that machinery has actually caught.

Read this before starting another round of spec work — the useful thing to carry forward is not *what changed* (git log has that) but *which kind of check finds which kind of problem*.

---

## The five axes

Each answers a different question. They are not interchangeable, and passing one says almost nothing about the others.

### 1. Measurement — "is this claim about the world true?"

`ViewSplitProbe/`, `ConcurrencyProbe/`

Take a factual assertion the spec relies on and put it in front of a compiler or a simulator. Both probes are re-runnable; both README files record the toolchain version, because these answers expire.

**Caught:** three pieces of received wisdom that turned out to be false — `AnyView` does *not* stop a child's body from being skipped; "precise injection" cannot be justified on performance grounds (passing the whole object redraws *less*); `nonisolated async` behaviour flips depending on one build flag.

**Use when:** the spec says "X is faster / X breaks Y / X behaves like Z". Especially when it sounds like something everyone knows.

### 2. Enforcement — "will an AI actually catch a violation?"

`ReviewProbe/`

Plant a known set of violations in plausible-looking code, hand it to an agent that has not seen the ground truth, compare. **The reviewer must not be able to read the answer** — that is the whole experiment.

**Caught:** nothing at first (31/31, zero false positives), which was itself the lesson — see the pitfalls below.

**Use when:** you have rewritten a rule and want to know it still bites. Also the right check after any *reduction* in the spec.

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

---

## Pitfalls learned the hard way

**A perfect enforcement score is not evidence of a good spec.** The review probe scored 31/31 with zero false positives, which read as "the spec is complete". The very next generation run found six real holes. Enforcement only tests the places where a rule exists; it is structurally blind to absence.

**Every round of fixes creates the next round's bugs.** Five times in a row, the newly-found problem was in material added during the *previous* round — the four-state skeleton, the performance measurement's shape, the optimistic-update/polling race, the Preview/polling deadlock. This is not carelessness; it is what happens when rules interact. It also means "keep going until nothing turns up" is an unreachable stopping condition. Stop on **severity** instead: when the findings stop being things that would produce a bug.

**Reduction must be verified in both directions.** After moving 357 lines out of the SKILL.md files, an enforcement run passed — but reviewing only needs "is this right?", while generating needs "how do I do it?", and the relocated material was exactly what generation depends on. A separate generation run was required, and it found four navigation problems the enforcement run could not have seen.

**Saying "this has no solution" beats saying nothing.** A generation agent specifically praised the swipe-back limitation for being written down as unsolved: *"明講沒解比沒寫更有用"*. Silence gets read as "not thought about yet", and the next reader re-derives the dead end from scratch.

**An upstream rule can dissolve a downstream problem.** After the wizard rule ("default to one feature") landed, the deep-return machinery it was written alongside became unnecessary — collapsing the wizard leaves a single callback level. When a section keeps growing in complexity, check whether an earlier decision is what's generating it.

---

## Where this leaves the spec

As of 2026-08, after a full pass on all five axes: the *content* is close to complete — the last round's findings were all navigation problems (the rule existed, the index didn't point at it) rather than missing rules. What remains unverified is the one axis that cannot be run here: **sustained use on a real project**. Everything above tests the spec as a document and as instructions; none of it tests whether it is pleasant to work with over months.

When picking up spec work again, the cheapest useful move is a generation probe with a requirement shape that hasn't been tried yet (editing existing data, file upload with progress, offline/caching). If it comes back with only navigation-level findings, the content is holding.
