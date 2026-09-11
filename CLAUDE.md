# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A personal MVVMC architecture guideline, continuously evolved through discussion, refinement, and demo validation. MVVMC is a custom iOS architecture pattern designed for personal and team use.

---

## Repository Layout

| Path | Role |
|---|---|
| `.claude/skills/` | **The specification.** One skill per layer / concern; each is the single source of truth for its own rules |
| `Sources/` | Demo app — the compile-time test for the spec |
| `Tests/` | ViewModel unit tests |
| `README.md` / `README.en.md` | Human-facing overview |

---

## Architecture: MVVMC

Four strictly separated layers. SwiftUI + UIKit hybrid. iOS 17+.

| Layer | File | Responsibility | Rules live in |
|---|---|---|---|
| M | `FeatureViewModel+Models.swift` | State / Domain Models / DTOs | `mvvmc-model` |
| VM | `FeatureViewModel.swift` | `@Observable @MainActor`, single `doAction` entry point | `mvvmc-viewmodel` |
| V | `FeatureView.swift` | Pure SwiftUI, zero navigation logic | `mvvmc-view` |
| C | `FeatureHostController.swift` | UIKit bridge, sole owner of routing | `mvvmc-hostcontroller` |

Cross-cutting concerns:

| Concern | Rules live in |
|---|---|
| Where a type or component lives; feature boundaries | `mvvmc-structure` |
| AppRouter / Deeplink / SceneDelegate | `mvvmc-navigation` |
| ViewModel unit tests | `mvvmc-testing` |
| async / Task / actor / Sendable | `swift-concurrency` |
| Feature review · single-file deep review | `mvvmc-review` · `mvvmc-deep-review` |
| Skip.tools → Android | `mvvmc-skip` — 🧊 **凍結的筆記，不是規範**（從未被任何 Android 建置驗證；不得用來推導或修改 iOS 規則；每輪一致性檢查不涵蓋它） |

### Creation Order

M → VM → V → C

### File Structure

```
Pages/FeatureName/
├── FeatureNameViewModel+Models.swift   ← M
├── FeatureNameViewModel.swift          ← VM
├── FeatureNameViewModel+APIs.swift     ← VM (endpoint definitions — one possible layout, not a spec requirement)
├── FeatureNameView.swift               ← V
├── FeatureNameMocks.swift              ← Mock (#if DEBUG, optional)
└── FeatureNameHostController.swift     ← C
```

### Layer Boundaries

These four lines define what the layers *are*. Every concrete rule, template, and ✅/❌ list lives in the skills above — not here.

- **M** — DTOs never leave this layer; `toDomain()` is the only path from API data into State.
- **VM** — `doAction(_:)` is the only entry point. The ViewModel never navigates: it emits `onRoute` / `onCallback` and lets C act.
- **V** — no navigation logic, no business logic, never creates its own ViewModel.
- **C** — the only layer that routes, and it routes exclusively through `AppRouter.shared`.

### Data Flow

```
User interaction  → V:  Task { await viewModel.doAction(.view(.xxx)) }
                  → VM: handleViewAction   → doAction(.apiRequest(...))
                  → VM: handleAPIRequest   → call API → doAction(.apiResponse(...))
                  → VM: handleAPIResponse  → update state → View refreshes automatically

Navigation        → VM: onRoute?(.toXxx) → C → AppRouter.shared.to(vc, from: self)
Cross-VC result   → child VM: await onCallback?(.xxx) → parent C → AppRouter.shared.back(from: self)
```

---

## Maintaining the Spec

- **Never restate a rule anywhere but in the skill that owns it.** Duplicated rules drift, and this repo has now produced the failure in **four** directions — the rule is not just about this file:
  - `CLAUDE.md` ↔ skill — the `send` closure type had two conflicting definitions for months
  - **skill ↔ skill** — `swift-concurrency` said "undecided" while `mvvmc-viewmodel` said "settled" about the same question; a project that had enabled the setting could legitimately pick either
  - **`TODO.md` ↔ skill** — the settlement was written into one skill and not the other, and `TODO.md` recorded the contradiction on 2026-07-11 without anyone acting on it for two months
  - **skill ↔ its consumer** — `mvvmc-review` restates each layer's rules as check items. When a rule gains an exemption, nothing checks whether the enforcement end learned about it. A 2026-09 audit found **14 "do not file this" exemptions upstream and 0 carried into the review skill.** This one is the worst, because review is the spec's only enforcement path: a stale enforcer means the rule changed but did not take effect.

  Test for whether a check item will drift: **delete the upstream section it names — does the item still read as an instruction?** If yes it carries its own criteria and will drift; if it degrades into an empty pointer, it will not.

  **These four are not a spec-specific disease.** The same round that catalogued them also changed an API and left `README.md` describing the removed one, and changed twenty rules without rebuilding the demo — neither of which is a *restated rule*. The actual shape is **"something changed and its consumers did not"**, and the spec is merely its most visible host. So the question to ask after any change is not "did I restate this somewhere" but **"what reads this?"** — skills, the review skill, `TODO.md`, `SPEC-COVERAGE.md`, both READMEs, the demo, and the probes each consume something here.

  **Ask it with `git grep`, not with memory.** That question was written down on 2026-09-08 and *still* failed three days later, in the very round that wrote it. `59f7e41` renamed `Deeplink.makeHostController()` → `makeDestination()`; the same commit edited `mvvmc-navigation/SKILL.md` — but only the six lines that were *about the Close button*, because that was the commit's topic. Four more mentions sat further down the same file, in the Deeplink section, which did not look related. Then `ebb7e1c`, the documentation-sync pass, touched `CLAUDE.md`, both READMEs, `SPEC-COVERAGE.md`, and `TODO.md` — **no `references/` file was in its list at all**, so `navigation-templates.md` stayed a generation behind and went on demonstrating a shape the rules had just forbidden. A 2026-09-11 sweep found the rename stale in **six** places and `SPEC-COVERAGE.md` carrying a row that contradicted its own text twelve lines earlier.

  None of that needed judgment. It needed one line, run at the moment of the rename:

  ```bash
  git grep makeHostController          # the old name, everywhere, including references/
  ```

  So: **after renaming or removing anything, grep the old name across the whole repo before committing.** Enumerate consumers by what mentions the symbol, never by which directory feels like "the docs" — `references/` is where the pasteable code lives, which makes it the *worst* place to leave stale, not a lesser one.

  The same sweep generalized (run it when a round has touched the demo's API):

  ```bash
  # every demo-specific symbol named in any .md that no longer exists in Sources/ or Tests/
  python3 - <<'EOF'
  import re, glob, collections
  src = "".join(open(f).read() for p in ('Sources/**/*.swift','Tests/**/*.swift')
                for f in glob.glob(p, recursive=True))
  PREFIX = r'(?:AppRouter|Deeplink|PostList|PostDetail|PostFilter|Profile|Settings|UserDetail|AppTransition)'
  hits = collections.defaultdict(list)
  for pat in ('.claude/skills/**/*.md', '*.md', 'Experiments/**/*.md'):
      for f in sorted(glob.glob(pat, recursive=True)):
          for i, line in enumerate(open(f).read().splitlines(), 1):
              for tok in re.findall(rf'`({PREFIX}[A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)\(?`?', line):
                  if tok.endswith('.swift'): continue
                  if tok.split('.')[-1].rstrip('(') not in src: hits[tok].append(f"{f}:{i}")
  for k, v in sorted(hits.items()): print('STALE', k, '→', ', '.join(v))
  EOF
  ```

  Two hits are known and deliberate, so treat anything **else** it prints as real: the Android column of `mvvmc-skip/references/android-router.md` (those are Kotlin-side names, not demo symbols), and the `Deeplink.makeHostController` in the paragraph above — this file tells the story of that rename, so it necessarily names the symbol that no longer exists.
- This file may hold only what belongs to no single layer: the layer table, creation order, file structure, layer boundaries, and data flow.
- **A new skill needs a symlink in `~/.claude/skills/`**, or it only exists while working inside this repo — which is precisely when you least need it. The skills are meant to travel to whatever project you are actually writing MVVMC code in.

  ```bash
  ln -s "$PWD/.claude/skills/<name>/" ~/.claude/skills/<name>
  ```

  This is the step most easily forgotten, and the cost is not hypothetical: `mvvmc-structure` went a whole session without one, and **`mvvmc-navigation` went 33 days** — during which two shipped apps wrote their entire Router layer with no access to it. One of them cited the skill *by name* in its planning document, a file it could not open. **Verify delivery, do not assume it**: `ls ~/.claude/skills/` after adding a skill, and treat a skill named in a plan but absent from that listing as a hard stop.

- **The global symlink is the *development* channel, not the way a real project should consume this spec.** Because `~/.claude/skills/mvvmc-*` points into this repo's working tree, **every project on this machine silently tracks HEAD**: a rule edited here changes the rules of every app instantly, with no version, no notice, and no way to say afterwards which version an app was written against. That is not a hypothetical either — the three shipped apps are each on a different MVVMC, and they had no way not to be.

  So a project that wants to build on a *stable* MVVMC vendors a pinned copy instead:

  ```bash
  scripts/vendor-skills.sh <project-dir> [tag]     # copy the skills at a tag + write a version stamp
  scripts/vendor-skills.sh --check <project-dir>   # has the copy been edited? is a newer tag out?
  ```

  It copies the ten spec skills into `<project>/.claude/skills/` and writes `MVVMC-VERSION` (tag, commit, date). `mvvmc-skip` is excluded on purpose — it is frozen, unverified notes, not part of the spec. Upgrading is then an explicit act: re-run the command with a newer tag. **Nothing arrives while you sleep.**

  Two channels, two purposes, and they must not be confused:

  | | `~/.claude/skills/` symlink | vendored copy |
  |---|---|---|
  | Tracks | HEAD, live | one tag, frozen |
  | For | working *on* the spec; exploratory code | any project whose code you intend to keep |
  | Upgrade | happens to you | you run a command |

  **Spectra projects get this automatically** — `spectra-bootstrap` step 6 vendors and pins, so nothing new to remember. That skill previously said the opposite (*「全專案自動可用，不需複製」*), which is precisely where the three shipped apps' divergence came from; it and the `SpecDemo` template were corrected in the same pass (both live in other repos).

  **Stability is not a property the spec reaches by being written well enough — it is a property a consumer gets by pinning.** No amount of verification upstream helps a project that silently follows HEAD. And the reverse: a pinned project stays stable even while the spec is still being worked on, which is what makes it safe to keep improving this repo at all.

- **Before another round of spec work, read `Experiments/README.md`** — it records which kind of check finds which kind of problem, and the pitfalls that cost the most to learn (a perfect enforcement score is not evidence of a good spec; every round of fixes creates the next round's bugs).

  **Start with axis 0 (subtraction) — it is the one that decides whether a round helps.** Rule lines went 36 → 141 in four months with 117 additions against 12 removals, and that ratio, not carelessness, is why "every round of fixes creates the next round's bugs". Axis 0 carries the entry gate (what may enter as a hard rule at all), the three-way split of unbacked statements (axiom / unaudited / prudential — only the middle one pays), the rule that external documentation is a source of questions and never of rules, and the trigger conditions for opening a round. **A round that adds rules and removes none has not finished.**
- `Sources/` and `Tests/` play **two roles with opposite evidential weight**, and collapsing them is a mistake this file made once already:
  - **As a source of rules** — mirroring the demo's API surface into the spec — it is worth **nothing**. The demo is written to match the spec, so it agrees by construction. `mvvmc-navigation`'s six-method list came from here (commit `df7ebbb` says so) and matched **0 of 3** shipped projects.
  - **As a consumer forced to compile** — it is the strongest check there is for one specific class of defect: **a rule that describes a shape which should not exist.** In 2026-09, "the Router must not inject a Close button" turned out to be unimplementable alone, because the demo's detail page is reached by both push and deeplink and would have had to know which. Adversarial reading could not find that (nothing on paper says one VC has two entry paths) and neither could the field reports (none of the three apps had that shape). **That is a design defect, not a wording one**, and only the demo surfaces those.

  So "compile-time test, not validation" is too strong: it does not verify a rule is **right**, but it does verify a rule is **implementable** — and this round showed the second catches things the first would never reach.
- After changing a rule, **build and test the demo, and update `SPEC-COVERAGE.md` in the same pass.** Both are easy to skip when the change looks documentation-only — a 2026-09 round changed twenty-odd rules and did neither until asked. Any doc that describes the demo's API (`README.md`, `README.en.md`) counts as a consumer and drifts the same way.
