# 0006 — Versioned Git hooks via `core.hooksPath`

* Status: accepted
* Date: 2026-04-19
* Deciders: Jose Nunez (for a 5-person team)

## Context

The pre-commit pipeline (`.git/hooks/pre-commit`) enforces five architecture
invariants:

1. Validation stamp for Swift changes (layer 4 of
   `code-changes-enforcement.mdc`)
2. `print()` in production code is blocked
3. ADR obligation on structural changes (`adr-required.sh` from T0d)
4. UI state sync anti-pattern (`ui-state-sync-enforcement.mdc` from T0a)
5. Architecture documentation sync (`architecture-documentation-sync.mdc`)

So far the hook lived exclusively in `.git/hooks/pre-commit` — that is,
**not versioned**. For a 1-person development this had no
effect; with five contributors, however, a hole appears immediately:

- Four of five machines do not have the hook.
- Architecture regressions (e.g. reviving `changeVersion` polling)
  happen silently and are only discovered in code review — if at all.
- ADR-0001/0002/0003/0005/0006 lose their main enforcement; the
  `mdc` rules are only L2-advisory, the real L4 block comes from the hook.
- The entire investment from T0a–T0e becomes useless for 4/5 of the team.

Since 2.9 Git has supported the configuration option `core.hooksPath`, with which
a repository can be redirected to a versioned hook folder.
Apple ships Git ≥ 2.45 with Xcode 16 (used by `~/Downloads/Xcode.app`),
so it is compatible.

## Options

- **A — Keep the status quo**
  Hooks locally in `.git/hooks/`. Everyone on the team installs them themselves.
  Reliability: 0 — no one will do that.

- **B — Husky / Lefthook / pre-commit framework**
  External tools (Node, Go, or Python respectively). Advantages: mature
  configuration language, parallel execution. Disadvantages: an additional
  toolchain dependency (Node) for a Swift repo that currently has **zero**
  Node dependencies. `pre-commit` (the Python tool) would be closer to the
  existing setup, but it changes the diagnostic output and would have to rebuild
  the RULE/VIOLATION/FIX formatting of the existing checks.

- **C — `core.hooksPath` to a versioned `.githooks/` directory** ✅
  An Apple/Git first-party mechanism. No external toolchain.
  Setup: run `scripts/install-hooks.sh` once per clone (idempotent).
  The hook contents are identical to today's `.git/hooks/pre-commit` — no
  behavior change, just versioning of the file.

- **D — `core.hooksPath` plus auto-install via `post-checkout`/`post-merge`**
  Like C, but additionally the hook tries to activate itself.
  Risk: runtime-critical magic. If the auto-install fails, no one
  knows why the validations suddenly do or do not apply.
  Rejected for the sake of diagnostic clarity.

## Decision

**Option C**: a repository-versioned `.githooks/` directory and a manual
one-time setup per clone via `scripts/install-hooks.sh`.

Rationale:

- **Zero additional toolchain**: the repo stays a pure Xcode project,
  no `package.json`, no `pre-commit-config.yaml`.
- **Discoverable**: every contributor sees `.githooks/` and the
  `scripts/install-hooks.sh` on the first `git status` after a clone. The
  onboarding doc (`docs/adr/ONBOARDING.md`) mentions it as the first step.
- **No behavior change**: the hook contents are identical to today —
  tests/validations as before, just now for everyone.
- **Reversible**: `git config --unset core.hooksPath` deactivates immediately.
  If anyone ever wants to disable a hook locally, `--no-verify`
  is the documented way (see `code-changes-enforcement.mdc`).

## Consequences

**Positive**

- Pre-commit architecture protection applies on all 5 machines.
- Hook changes come into review as normal PRs — no more
  "shadow configuration".
- ADR-0001/0002/0003/0005 are enforceable end to end (the L4 layer
  works team-wide).

**Negative**

- One additional setup step after a clone (`./scripts/install-hooks.sh`).
  Mitigation: documented in `docs/adr/ONBOARDING.md` and in the repo `README.md`
  (see follow-up task).

**Neutral**

- Whoever forgets the setup step gets a code-review lecture instead of
  a hook block. That is acceptable — no new risk, just the
  familiar "hook missing" of a status-quo setup.

## References

- ADR-0001 — `@Model` as UI SoT (enforced via hook check 4)
- ADR-0005 — schema migration strategy (enforced via hook check 3)
- `.cursor/rules/code-changes-enforcement.mdc` — describes the L1–L5 layers
- `scripts/install-hooks.sh` — setup script
- `.githooks/pre-commit` — the versioned hook script

Co-authored-by: Cursor <cursor@cursor.com>
