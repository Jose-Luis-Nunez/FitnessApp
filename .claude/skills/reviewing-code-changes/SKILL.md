---
name: reviewing-code-changes
description: >-
  Risk-based Swift/SwiftUI validation. Uses a lightweight self-review for local
  presentation changes and independent reviewer/tester agents for logic,
  state, persistence, navigation, and cross-package changes.
---

# Reviewing Code Changes

## 1. Classify

Run:

```bash
bash .claude/hooks/lib/change-risk.sh classify
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

## 4. Test Once

Development may use focused tests. Completion requires one final result bound
to the current contents.

- If no matching result exists, the tester uses `run`.
- If the main agent already ran the complete required command on the final
  contents, the tester uses `verify` and checks command, exit code, counts, and
  xcresult without re-running it.
- Any content change after the run invalidates the evidence.

Green changes do not need a tester subagent. Yellow/red changes use a fresh
tester with no conversation history.

## 5. Record Evidence

After the final review:

```bash
bash .claude/hooks/lib/validation-evidence.sh write \
  .claude/hooks/state/code-changes.manifest.tsv
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
