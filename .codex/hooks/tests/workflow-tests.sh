#!/bin/bash
# Fixture tests for risk routing, content evidence, infra triggers, and hooks.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
RISK="$REPO_ROOT/.claude/hooks/lib/change-risk.sh"
EVIDENCE="$REPO_ROOT/.claude/hooks/lib/validation-evidence.sh"
INFRA_CHECK="$REPO_ROOT/.claude/hooks/checks/agent-infrastructure.sh"
PRE_COMMIT="$REPO_ROOT/.githooks/pre-commit"
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT

pass_count=0

expect_equal() {
  local expected="$1"
  local actual="$2"
  local name="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $name — expected '$expected', got '$actual'" >&2
    exit 1
  fi
  pass_count=$((pass_count + 1))
}

expect_success() {
  local name="$1"
  shift
  if ! "$@"; then
    echo "FAIL: $name" >&2
    exit 1
  fi
  pass_count=$((pass_count + 1))
}

expect_failure() {
  local name="$1"
  shift
  if "$@"; then
    echo "FAIL: $name — command unexpectedly succeeded" >&2
    exit 1
  fi
  pass_count=$((pass_count + 1))
}

expect_hook_output() {
  local repo="$1"
  local pattern="$2"
  local name="$3"
  local output=""

  output=$(cd "$repo" && bash "$PRE_COMMIT" 2>&1 || true)
  if ! printf '%s\n' "$output" | grep -qiE "$pattern"; then
    echo "FAIL: $name — missing pattern '$pattern'" >&2
    printf '%s\n' "$output" >&2
    (cd "$repo" && bash -x "$PRE_COMMIT") >&2 || true
    exit 1
  fi
  pass_count=$((pass_count + 1))
}

write_fixture_evidence() {
  local repo="$1"
  local risk="$2"
  local reviewer="$3"
  local tester="$4"

  (
    cd "$repo"
    bash "$EVIDENCE" write .claude/hooks/state/code-changes.manifest.tsv staged
    code_fingerprint=$(bash "$EVIDENCE" fingerprint .claude/hooks/state/code-changes.manifest.tsv)
    printf 'result: PASS\nrisk: %s\nverified_by: %s\nsource_fingerprint: %s\n' \
      "$risk" "$reviewer" "$code_fingerprint" > .claude/hooks/state/code-changes.stamp.md
    bash "$EVIDENCE" write .claude/hooks/state/test-execution.manifest.tsv staged
    test_fingerprint=$(bash "$EVIDENCE" fingerprint .claude/hooks/state/test-execution.manifest.tsv)
    printf 'result: PASS\nverified_by: %s\nmode: verify\ncommand: focused fixture\ntests: 1/1\nsource_fingerprint: %s\n' \
      "$tester" "$test_fingerprint" > .claude/hooks/state/test-execution.stamp.md
  )
}

new_repo() {
  local name="$1"
  local path="$TEMP_ROOT/$name"
  mkdir -p "$path"
  (
    cd "$path"
    git init -q
    git config user.email workflow@example.com
    git config user.name Workflow
    mkdir -p Packages/FitnessUI/Sources/FitnessUI
    mkdir -p Packages/FitnessExercise/Sources/FitnessExercise
    mkdir -p Packages/FitnessStorage/Sources/FitnessStorage
    mkdir -p .claude/references .claude/rules .claude/hooks/lib .claude/hooks/state
    printf 'struct CardView {}\n' > Packages/FitnessUI/Sources/FitnessUI/CardView.swift
    printf 'final class FormViewModel {}\n' > Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift
    printf 'final class WorkoutStorage {}\n' > Packages/FitnessStorage/Sources/FitnessStorage/WorkoutStorage.swift
    printf '# Architecture\n' > .claude/references/architecture-documentation.md
    printf '%s\n' '---' 'alwaysApply: true' '---' > .claude/rules/example.mdc
    cp "$REPO_ROOT/.claude/hooks/lib/validation-evidence.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/.claude/hooks/lib/change-risk.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/.claude/hooks/lib/agent-infrastructure-evidence.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/.claude/hooks/lib/adr-triggers.sh" .claude/hooks/lib/
    git add .
    git commit -qm baseline
  )
  printf '%s\n' "$path"
}

green_repo=$(new_repo green)
printf 'struct CardView { let spacing = 8 }\n' > "$green_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
expect_equal "green" "$(cd "$green_repo" && bash "$RISK" classify)" "green layout classification"

yellow_repo=$(new_repo yellow)
printf 'final class FormViewModel { var value = 1 }\n' > "$yellow_repo/Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift"
expect_equal "yellow" "$(cd "$yellow_repo" && bash "$RISK" classify)" "yellow logic classification"

red_repo=$(new_repo red)
printf 'final class WorkoutStorage { func save() {} }\n' > "$red_repo/Packages/FitnessStorage/Sources/FitnessStorage/WorkoutStorage.swift"
expect_equal "red" "$(cd "$red_repo" && bash "$RISK" classify)" "red storage classification"

manifest="$green_repo/.claude/hooks/state/evidence.tsv"
(
  cd "$green_repo"
  bash "$EVIDENCE" write "$manifest"
)
expect_success "unchanged evidence remains valid" bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest'"
(
  cd "$green_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_success "manifest covers identical staged blob" bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest' staged"
printf 'struct CardView { let spacing = 9 }\n' > "$green_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
expect_failure "same-path content edit invalidates evidence" bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest'"
expect_success "unstaged follow-up does not invalidate staged evidence" \
  bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest' staged"

infra_repo=$(new_repo infra)
printf '# Architecture updated\n' > "$infra_repo/.claude/references/architecture-documentation.md"
mkdir -p "$TEMP_ROOT/infra-state"
infra_product_output=$(
  cd "$infra_repo"
  CONTENT="" STATE_DIR="$TEMP_ROOT/infra-state" HOOKS_DIR="$REPO_ROOT/.claude/hooks" \
    HAS_QUESTION=0 bash "$INFRA_CHECK"
)
expect_equal "" "$infra_product_output" "product reference does not trigger infra verifier"
printf '%s\n' '---' 'alwaysApply: false' '---' > "$infra_repo/.claude/rules/example.mdc"
infra_rule_output=$(
  cd "$infra_repo"
  CONTENT="## Agent Infrastructure Validation Report" \
    STATE_DIR="$TEMP_ROOT/infra-state" HOOKS_DIR="$REPO_ROOT/.claude/hooks" \
    HAS_QUESTION=0 bash "$INFRA_CHECK"
)
if ! printf '%s\n' "$infra_rule_output" | grep -qi "agent-infrastructure"; then
  echo "FAIL: report text bypassed the required infra-verifier stamp" >&2
  exit 1
fi
pass_count=$((pass_count + 1))

(
  cd "$infra_repo"
  bash "$REPO_ROOT/.claude/hooks/lib/agent-infrastructure-evidence.sh" write \
    "$TEMP_ROOT/infra-state/agent-infrastructure.manifest.tsv"
)
infra_fingerprint=$(cd "$infra_repo" && bash "$REPO_ROOT/.claude/hooks/lib/agent-infrastructure-evidence.sh" fingerprint "$TEMP_ROOT/infra-state/agent-infrastructure.manifest.tsv")
cat > "$TEMP_ROOT/infra-state/agent-infrastructure.stamp.md" <<EOF
result: PASS
verified_by: verifier-subagent
source_fingerprint: $infra_fingerprint
reference_integrity: PASS
overview_sync: PASS
description_consistency: PASS
handoff_links: PASS
hook_alignment: PASS
name_consistency: PASS
EOF
infra_verified_output=$(
  cd "$infra_repo"
  CONTENT="" STATE_DIR="$TEMP_ROOT/infra-state" HOOKS_DIR="$REPO_ROOT/.claude/hooks" \
    HAS_QUESTION=0 bash "$INFRA_CHECK"
)
expect_equal "" "$infra_verified_output" "exact verifier stamp satisfies infra check"

(
  cd "$infra_repo"
  git add .claude/rules/example.mdc
)
expect_failure "pre-commit blocks unverified infrastructure" \
  bash -c "cd '$infra_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"
cp "$TEMP_ROOT/infra-state/agent-infrastructure.stamp.md" \
  "$infra_repo/.claude/hooks/state/agent-infrastructure.stamp.md"
(
  cd "$infra_repo"
  bash "$REPO_ROOT/.claude/hooks/lib/agent-infrastructure-evidence.sh" write \
    .claude/hooks/state/agent-infrastructure.manifest.tsv staged
)
infra_commit_fingerprint=$(cd "$infra_repo" && bash "$REPO_ROOT/.claude/hooks/lib/agent-infrastructure-evidence.sh" fingerprint .claude/hooks/state/agent-infrastructure.manifest.tsv)
sed -i '' "s/${infra_fingerprint}/${infra_commit_fingerprint}/" \
  "$infra_repo/.claude/hooks/state/agent-infrastructure.stamp.md"
expect_success "pre-commit accepts exact verifier infrastructure evidence" \
  bash -c "cd '$infra_repo' && bash '$PRE_COMMIT'"

hook_repo=$(new_repo precommit)
printf 'struct CardView { let spacing = 8 }\n' > "$hook_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
(
  cd "$hook_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_failure "pre-commit blocks missing evidence" bash -c "cd '$hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

write_fixture_evidence "$hook_repo" green main-agent main-agent
(
  cd "$hook_repo"
  bash "$EVIDENCE" verify .claude/hooks/state/code-changes.manifest.tsv staged
  bash "$EVIDENCE" stamp-matches .claude/hooks/state/code-changes.stamp.md .claude/hooks/state/code-changes.manifest.tsv
  expect_equal "green" "$(bash "$RISK" classify staged)" "staged green classification"
)
expect_success "pre-commit accepts exact green evidence" bash -c "cd '$hook_repo' && bash '$PRE_COMMIT'"

printf 'struct CardView { let spacing = 10 }\n' > "$hook_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
(
  cd "$hook_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_failure "pre-commit rejects content changed after validation" bash -c "cd '$hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

yellow_hook_repo=$(new_repo yellow-precommit)
printf 'final class FormViewModel { var value = 1 }\n' > "$yellow_hook_repo/Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift"
(
  cd "$yellow_hook_repo"
  git add Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift
)
write_fixture_evidence "$yellow_hook_repo" yellow main-agent main-agent
expect_failure "yellow rejects main-agent-only evidence" bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"
write_fixture_evidence "$yellow_hook_repo" yellow reviewer-subagent tester-subagent
expect_success "yellow accepts reviewer and tester verification" bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null"

print_repo=$(new_repo print)
printf 'struct CardView { func debug() { print(\"debug\") } }\n' > "$print_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
(
  cd "$print_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_hook_output "$print_repo" "No print\\(\\)" "production print protection remains"

state_repo=$(new_repo state)
printf 'final class FormViewModel {\n  var changeVersion: Int = 0\n  func observe() async {\n    while !Task.isCancelled { }\n  }\n}\n' > "$state_repo/Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift"
(
  cd "$state_repo"
  git add Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift
)
expect_hook_output "$state_repo" "ui-state-sync-enforcement" "UI state anti-pattern protection remains"

adr_repo=$(new_repo adr)
printf '@Observable\nfinal class SyncService {}\n' > "$adr_repo/Packages/FitnessExercise/Sources/FitnessExercise/SyncService.swift"
(
  cd "$adr_repo"
  git add Packages/FitnessExercise/Sources/FitnessExercise/SyncService.swift
)
expect_hook_output "$adr_repo" "adr-required" "ADR protection remains"
expect_hook_output "$adr_repo" "architecture-documentation.md" "architecture sync protection remains"

expect_success "runtime adapters are synchronized" "$REPO_ROOT/scripts/sync-agent-runtime.sh" --check
expect_success "subagent gate remains valid shell" bash -n "$REPO_ROOT/.claude/hooks/subagent-gate.sh"

kill_switch_repo="$TEMP_ROOT/kill-switch"
mkdir -p "$kill_switch_repo/.claude/hooks/state" "$kill_switch_repo/.codex/hooks"
cp "$REPO_ROOT/.codex/hooks/post-task-check.sh" "$kill_switch_repo/.codex/hooks/"
: > "$kill_switch_repo/.claude/hooks/state/checks-disabled"
expect_success "Codex adapter honors canonical kill switch" \
  bash -c "cd '$kill_switch_repo' && printf '{}\\n' | bash .codex/hooks/post-task-check.sh"

rule_bytes=$(find "$REPO_ROOT/.claude/rules" -name '*.mdc' -type f -exec wc -c {} + | awk 'END {print $1}')
review_skill_bytes=$(wc -c < "$REPO_ROOT/.claude/skills/reviewing-code-changes/SKILL.md" | tr -d ' ')
largest_routed_reference=$(find "$REPO_ROOT/.claude/skills/reviewing-code-changes/references" -name '*.md' -type f -exec wc -c {} + | awk '$2 != "total" {if ($1 > max) max=$1} END {print max+0}')

if [ "$rule_bytes" -gt 6000 ]; then
  echo "FAIL: always/glob rule budget exceeded: ${rule_bytes} bytes" >&2
  exit 1
fi
pass_count=$((pass_count + 1))

if [ "$review_skill_bytes" -gt 6000 ]; then
  echo "FAIL: review orchestrator budget exceeded: ${review_skill_bytes} bytes" >&2
  exit 1
fi
pass_count=$((pass_count + 1))

if [ "$largest_routed_reference" -gt 2000 ]; then
  echo "FAIL: routed review reference budget exceeded: ${largest_routed_reference} bytes" >&2
  exit 1
fi
pass_count=$((pass_count + 1))

echo "PASS: $pass_count workflow fixture checks"
