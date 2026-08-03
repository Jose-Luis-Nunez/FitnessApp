---
name: reviewing-code-changes
description: >-
  Risk-based Swift/SwiftUI validation. Uses a lightweight self-review for local
  presentation changes and independent reviewer/tester agents for logic,
  state, persistence, navigation, and cross-package changes.
---

# Reviewing Code Changes

## 0. Freeze the Working-Tree Candidate

Final validation starts only after implementation is complete and no known
finding or product decision remains open. It is not an exploratory review loop.

- The candidate is every tracked modification and untracked file currently in
  the working tree; `/validate` never stages it.
- Code and test manifests fingerprint every candidate file except generated
  evidence state. Pre-commit requires the eventual staged candidate to match
  that manifest exactly; a subset needs its own explicit validation.
- Inventory the combined candidate from `git diff HEAD --name-only` plus
  untracked files. Partial staging does not narrow the review scope.
- Run `git diff HEAD --check` before any expensive test command so staged and
  unstaged tracked changes are checked together.
- Resolve applicable ADR triggers before the reviewer/tester phase. An existing
  ADR may justify a one-line exception; do not wait for pre-commit to discover
  the missing coverage.
- When product and executable agent-infrastructure files change together,
  keep their evidence tracks separate: code reviewer/tester for product files,
  infrastructure verifier for agent-system files.

The yellow/red reviewer below is the senior-quality review. Do not run a
lighter "commit ready" review and then add a second senior review afterward.

## 1. Classify

Run:

```bash
bash .claude/hooks/lib/change-risk.sh classify worktree
```

The conservative result is `green`, `yellow`, or `red`.

- **Green:** at most two local presentation files, no state/API/persistence
  signals. Self-review plus one relevant final test or snapshot. No subagents.
- **Yellow:** normal logic, ViewModel/use-case, or public UI work. Independent
  reviewer and one final affected test run.
- **Red:** schema, storage, DI, coordinator, navigation, concurrency, package
  boundary, public domain API, multiple packages, or 10+ production Swift
  files. Reviewer, tester, affected package tests, app build, relevant UI tests,
  and ADR when the change makes an architectural decision.

If the classification looks too low, raise it. Never lower it manually.

## 2. Load Only Relevant Checks

Always read:

- `.claude/skills/reviewing-code-changes/references/base-review.md`

Read only the references matched by the diff:

- SwiftUI/AppStyle → `swiftui-review.md`
- SwiftData/schema/storage → `swiftdata-review.md`
- state/service/coordinator/concurrency → `state-services-review.md`
- tests/fixtures/snapshots/UI tests → `test-review.md`
- structural/public change → `architecture-routing.md`

Never read the complete architecture document for a review. Route to the
relevant heading and read that section only.

## 3. Review

For green changes, the main agent performs the short review.

For yellow/red changes, spawn the reviewer with fresh context:

- Codex: use `fork_turns: "none"`.
- Claude Code: use a fresh reviewer Task.
- Pass only the risk, changed-file list, and requested references.
- Do not paste the diff or conversation history; the reviewer reads the
  workspace.

The reviewer uses `.codex/agents/reviewer.toml` in Codex or
`.claude/agents/reviewer.md` in Claude Code. Fix Bug findings and re-review the
final contents. Report residual duplication only when one actually remains.
Missing or stale test/infrastructure evidence is not a code finding during
this phase; those artifacts are intentionally produced after the code review.

## 4. Test Once

Development may use focused tests. Completion requires one final result bound
to the current contents.

Start the final tester only after the reviewer reports no Bug findings and the
working-tree product/test contents are stable. This prevents an otherwise successful
test run from becoming stale during senior-quality cleanup.

- If no matching result exists, the tester uses `run`.
- If the main agent already ran the complete required command on the final
  contents, the tester uses `verify` and checks command, exit code, counts, and
  xcresult without re-running it.
- Any content change after the run invalidates the evidence.

Green changes do not need a tester subagent. Yellow/red changes use a fresh
tester with no conversation history.

## 5. Record Evidence

After the final review, the reviewer writes:

```bash
bash .claude/hooks/lib/validation-evidence.sh write \
  .claude/hooks/state/code-changes.manifest.tsv worktree
bash .claude/hooks/lib/validation-evidence.sh fingerprint \
  .claude/hooks/state/code-changes.manifest.tsv
```

Write `code-changes.stamp.md` with:

```yaml
date: <ISO timestamp>
result: PASS
risk: <green|yellow|red>
verified_by: <main-agent|reviewer-subagent>
files_inspected: <count>
findings: <count>
source_fingerprint: <manifest fingerprint>
```

After the final test or verification, create
`test-execution.manifest.tsv`, obtain its fingerprint the same way, and write:

```yaml
date: <ISO timestamp>
result: PASS
verified_by: <main-agent|tester-subagent>
command: <final command>
tests: <passed/total>
xcresult: <path or n/a>
source_fingerprint: <manifest fingerprint>
```

Yellow/red stamps require `reviewer-subagent` and `tester-subagent`. Green
stamps may use `main-agent`.

## Architecture Sync

Use `architecture-routing.md`. Update only the relevant current-state entry for
structural/public changes. Product reference edits do not require an
agent-infrastructure verifier.
