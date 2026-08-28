#!/bin/bash
# Fixture tests for risk routing, content evidence, infra triggers, and hooks.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
RISK="$REPO_ROOT/.claude/hooks/lib/change-risk.sh"
EVIDENCE="$REPO_ROOT/.claude/hooks/lib/validation-evidence.sh"
INFRA_CHECK="$REPO_ROOT/.claude/hooks/checks/agent-infrastructure.sh"
TEST_SELECTION_CHECK="$REPO_ROOT/.claude/hooks/checks/test-selection.sh"
TEST_DOMAIN_RISK="$REPO_ROOT/.claude/hooks/lib/test-domain-risk.sh"
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
    domain_risk=$(bash "$TEST_DOMAIN_RISK" classify worktree)
    bash "$EVIDENCE" write .claude/hooks/state/code-changes.manifest.tsv worktree
    code_fingerprint=$(bash "$EVIDENCE" fingerprint .claude/hooks/state/code-changes.manifest.tsv)
    printf 'result: PASS\nrisk: %s\nverified_by: %s\nsource_fingerprint: %s\n' \
      "$risk" "$reviewer" "$code_fingerprint" > .claude/hooks/state/code-changes.stamp.md
    bash "$EVIDENCE" write .claude/hooks/state/test-execution.manifest.tsv worktree
    test_fingerprint=$(bash "$EVIDENCE" fingerprint .claude/hooks/state/test-execution.manifest.tsv)
    printf 'result: PASS\nverified_by: %s\nmode: verify\ndomain_risk: %s\ncommand: focused fixture\ntests: 1/1\nexit_code: 0\nxcresult: fixture/pre-merge.xcresult\nsource_fingerprint: %s\n' \
      "$tester" "$domain_risk" "$test_fingerprint" > .claude/hooks/state/test-execution.stamp.md
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
    mkdir -p Packages/FitnessTraining/Sources/FitnessTraining
    mkdir -p .claude/references .claude/rules .claude/hooks/lib .claude/hooks/state
    printf 'struct CardView {}\n' > Packages/FitnessUI/Sources/FitnessUI/CardView.swift
    printf 'final class FormViewModel {}\n' > Packages/FitnessExercise/Sources/FitnessExercise/FormViewModel.swift
    printf 'final class WorkoutStorage {}\n' > Packages/FitnessStorage/Sources/FitnessStorage/WorkoutStorage.swift
    printf 'final class TrainingCoordinator { func edit() {} }\n' > Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift
    printf '# Architecture\n' > .claude/references/architecture-documentation.md
    printf '%s\n' '---' 'alwaysApply: true' '---' > .claude/rules/example.mdc
    cp "$REPO_ROOT/.claude/hooks/lib/validation-evidence.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/.claude/hooks/lib/change-risk.sh" .claude/hooks/lib/
    cp "$REPO_ROOT/.claude/hooks/lib/test-domain-risk.sh" .claude/hooks/lib/
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

expect_equal "blocker" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessTraining/Sources/FitnessTraining/TrainingSessionComponent.swift)" "training test domain is blocker"
expect_equal "blocker" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift)" "exercise category test domain is blocker"
expect_equal "blocker" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/InactiveCardModelView.swift)" "training card test domain is blocker"
expect_equal "high" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessWorkouts/Sources/FitnessWorkouts/WorkoutsScreen.swift)" "workout test domain is high"
expect_equal "high" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsView.swift)" "analytics test domain is high"
expect_equal "low" "$(bash "$TEST_DOMAIN_RISK" classify-path FitnessApp/Features/BottomBar/Profile/ProfileView.swift)" "profile test domain is low"
expect_equal "low" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessTraining/Sources/FitnessTraining/Feedback/FeedbackSheetView.swift)" "feedback overrides training domain to low"
expect_equal "high" "$(printf '%s\n' Packages/FitnessProfile/Sources/FitnessProfile/ProfileViewModel.swift Packages/FitnessWorkouts/Sources/FitnessWorkouts/WorkoutsViewModel.swift | bash "$TEST_DOMAIN_RISK" classify-paths)" "mixed test domains use highest tier"
expect_equal "medium" "$(bash "$TEST_DOMAIN_RISK" classify-path Packages/FitnessSchedule/Sources/FitnessSchedule/ScheduleView.swift)" "unmapped test domain is medium"

deleted_training_repo=$(new_repo deleted-training-domain)
rm "$deleted_training_repo/Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift"
expect_equal "blocker" "$(cd "$deleted_training_repo" && bash "$TEST_DOMAIN_RISK" classify worktree)" "deleted training path remains blocker"

selection_repo=$(new_repo test-selection)
mkdir -p "$selection_repo/Packages/FitnessUI/Tests/FitnessUITests"
printf '@Test func visualContract() {}\n' > "$selection_repo/Packages/FitnessUI/Tests/FitnessUITests/CardTests.swift"
mkdir -p "$TEMP_ROOT/test-selection-state"
selection_output=$(
  cd "$selection_repo"
  STATE_DIR="$TEMP_ROOT/test-selection-state" bash "$TEST_SELECTION_CHECK"
)
if ! printf '%s\n' "$selection_output" | grep -q "Risk-Based Test Selection"; then
  echo "FAIL: new test does not trigger risk-based selection hint" >&2
  exit 1
fi
pass_count=$((pass_count + 1))
if ! printf '%s\n' "$selection_output" | grep -q "domain: blocker"; then
  echo "FAIL: test-selection hint does not include the classified domain tier" >&2
  exit 1
fi
pass_count=$((pass_count + 1))
selection_repeat_output=$(
  cd "$selection_repo"
  STATE_DIR="$TEMP_ROOT/test-selection-state" bash "$TEST_SELECTION_CHECK"
)
expect_equal "" "$selection_repeat_output" "test-selection hint is content-deduplicated"

whitespace_repo=$(new_repo staged-whitespace)
printf 'struct CardView { } \n' > "$whitespace_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
(
  cd "$whitespace_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_failure "combined diff check rejects staged whitespace" \
  bash -c "cd '$whitespace_repo' && git diff HEAD --check >/dev/null"

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
expect_success "manifest matches identical staged candidate" bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest' staged"
printf 'struct CardView { let spacing = 9 }\n' > "$green_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
expect_failure "same-path content edit invalidates evidence" bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest'"
expect_success "unstaged follow-up does not invalidate staged evidence" \
  bash -c "cd '$green_repo' && bash '$EVIDENCE' verify '$manifest' staged"

partial_repo=$(new_repo validated-partial-candidate)
printf 'struct SharedProvider {}\n' > "$partial_repo/Packages/FitnessUI/Sources/FitnessUI/SharedProvider.swift"
printf 'struct Consumer { let provider = SharedProvider() }\n' > "$partial_repo/Packages/FitnessUI/Sources/FitnessUI/Consumer.swift"
partial_manifest="$partial_repo/.claude/hooks/state/complete-candidate.tsv"
(
  cd "$partial_repo"
  bash "$EVIDENCE" write "$partial_manifest" worktree
  git add Packages/FitnessUI/Sources/FitnessUI/Consumer.swift
)
expect_failure "validated two-file candidate rejects staged dependent subset" \
  bash -c "cd '$partial_repo' && bash '$EVIDENCE' verify '$partial_manifest' staged"
(
  cd "$partial_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/SharedProvider.swift
)
expect_success "validated two-file candidate accepts exact staged candidate" \
  bash -c "cd '$partial_repo' && bash '$EVIDENCE' verify '$partial_manifest' staged"

valid_test_stamp="$TEMP_ROOT/test-execution-valid.stamp.md"
failed_test_stamp="$TEMP_ROOT/test-execution-failed.stamp.md"
misspelled_exit_stamp="$TEMP_ROOT/test-execution-misspelled-exit.stamp.md"
misspelled_metadata_stamp="$TEMP_ROOT/test-execution-misspelled-metadata.stamp.md"
wrong_domain_stamp="$TEMP_ROOT/test-execution-wrong-domain.stamp.md"
fixture_fingerprint=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
printf 'result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: medium\nexit_code: 0\nsource_fingerprint: %s\n' "$fixture_fingerprint" > "$valid_test_stamp"
printf 'result: FAIL # expected result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: medium\nexit_code: 0\nsource_fingerprint: %s\n' "$fixture_fingerprint" > "$failed_test_stamp"
printf 'result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: medium\nbad_exit_code: 0\nsource_fingerprint: %s\n' "$fixture_fingerprint" > "$misspelled_exit_stamp"
printf 'result: PASS\nbad_verified_by: tester-subagent\nbad_mode: verify\nexit_code: 0\nbad_source_fingerprint: %s\n' "$fixture_fingerprint" > "$misspelled_metadata_stamp"
printf 'result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: low\nexit_code: 0\nsource_fingerprint: %s\n' "$fixture_fingerprint" > "$wrong_domain_stamp"
expect_success "tester success contract accepts canonical PASS stamp" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$valid_test_stamp'"
expect_failure "tester success contract rejects embedded PASS comment" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$failed_test_stamp'"
expect_failure "tester success contract rejects misspelled exit field" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$misspelled_exit_stamp'"
expect_failure "tester success contract rejects misspelled metadata fields" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$misspelled_metadata_stamp'"
expect_failure "tester domain contract rejects stale domain tier" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$wrong_domain_stamp' high"
expect_success "tester domain contract accepts a justified higher tier" \
  bash -c "source '$EVIDENCE'; test_execution_stamp_has_required_fields '$valid_test_stamp' low"

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
cp "$TEMP_ROOT/infra-state/agent-infrastructure.manifest.tsv" \
  "$infra_repo/.claude/hooks/state/agent-infrastructure.manifest.tsv"
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

# A delete paired with a similar add is what git reports as a rename, and
# `--name-only` then prints only the destination. Before `--no-renames`, the
# deletion dropped out of the manifest entirely and was left unbound: its
# content could change without moving the fingerprint. This is the regression
# that motivated the flag, and nothing else in this suite covers it.
rename_repo=$(new_repo rename-pairing)
(
  cd "$rename_repo"
  mkdir -p Assets/old.imageset Assets/new.imageset
  printf '{ "images": [], "info": { "version": 1 } }\n' > Assets/old.imageset/Contents.json
  git add Assets/old.imageset/Contents.json
  git -c user.email=workflow@example.com -c user.name=Workflow commit -qm "asset"
  git rm -q Assets/old.imageset/Contents.json
  printf '{ "images": [], "info": { "version": 1 } }\n' > Assets/new.imageset/Contents.json
  git add Assets/new.imageset/Contents.json
)
# Assertions deliberately outside a subshell: `expect_equal` exits on failure
# and increments the counter, and a subshell would swallow both — the check
# would report nothing and pass silently.
rename_paths=$(cd "$rename_repo" && bash "$EVIDENCE" paths staged)
expect_equal "1" "$(printf '%s\n' "$rename_paths" | grep -c 'Assets/new.imageset/Contents.json')" \
  "rename destination is in the candidate"
expect_equal "1" "$(printf '%s\n' "$rename_paths" | grep -c 'Assets/old.imageset/Contents.json')" \
  "rename source deletion is in the candidate"

prestage_repo=$(new_repo pre-stage-validation)
printf 'struct CardView { let spacing = 12 }\n' > "$prestage_repo/Packages/FitnessUI/Sources/FitnessUI/CardView.swift"
write_fixture_evidence "$prestage_repo" green main-agent main-agent
(
  cd "$prestage_repo"
  git add Packages/FitnessUI/Sources/FitnessUI/CardView.swift
)
expect_success "pre-commit accepts evidence created before git add" \
  bash -c "cd '$prestage_repo' && bash '$PRE_COMMIT'"

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

# Negative cases for the xcresult contract. The positive fixture above only
# proves a good stamp is accepted; without these the contract could be deleted,
# or defeated by trailing whitespace, with the suite still green.
xcresult_stamp() {
  local repo="$1"
  local value="$2"
  local fingerprint=""

  fingerprint=$(
    cd "$repo" &&
      bash "$EVIDENCE" fingerprint .claude/hooks/state/test-execution.manifest.tsv
  )
  if [ -n "$value" ]; then
    printf 'result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: blocker\ncommand: focused fixture\ntests: 1/1\nexit_code: 0\nxcresult: %s\nsource_fingerprint: %s\n' \
      "$value" "$fingerprint" > "$repo/.claude/hooks/state/test-execution.stamp.md"
  else
    printf 'result: PASS\nverified_by: tester-subagent\nmode: verify\ndomain_risk: blocker\ncommand: focused fixture\ntests: 1/1\nexit_code: 0\nsource_fingerprint: %s\n' \
      "$fingerprint" > "$repo/.claude/hooks/state/test-execution.stamp.md"
  fi
}

xcresult_stamp "$yellow_hook_repo" "n/a"
expect_failure "blocker rejects a tester stamp naming no result bundle" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

xcresult_stamp "$yellow_hook_repo" "n/a "
expect_failure "blocker rejects 'n/a' with trailing whitespace" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

xcresult_stamp "$yellow_hook_repo" ""
expect_failure "blocker rejects a tester stamp with no xcresult field" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

# Shape, not just non-emptiness: without the `*.xcresult` check any word passes
# as "named a bundle".
xcresult_stamp "$yellow_hook_repo" "yes"
expect_failure "blocker rejects a value that is not a result bundle" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null 2>&1"

xcresult_stamp "$yellow_hook_repo" "fixture/pre-merge.xcresult"
expect_success "blocker accepts a named result bundle" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null"

# The trailing-whitespace strip is load-bearing for a *valid* path: without it
# this stamp is wrongly rejected. The `n/a ` case above no longer covers the
# strip, because the shape check rejects it first.
xcresult_stamp "$yellow_hook_repo" "fixture/pre-merge.xcresult "
expect_success "blocker accepts a named bundle with trailing whitespace" \
  bash -c "cd '$yellow_hook_repo' && bash '$PRE_COMMIT' >/dev/null"

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

coordinator_behavior_repo=$(new_repo coordinator-behavior)
printf 'final class TrainingCoordinator { func edit() { } }\n' > "$coordinator_behavior_repo/Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift"
(
  cd "$coordinator_behavior_repo"
  git add Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift
)
write_fixture_evidence "$coordinator_behavior_repo" red reviewer-subagent tester-subagent
expect_success "private coordinator behavior does not require architecture documentation" \
  bash -c "cd '$coordinator_behavior_repo' && bash '$PRE_COMMIT' >/dev/null"

expect_success "runtime adapters are synchronized" "$REPO_ROOT/scripts/sync-agent-runtime.sh" --check
expect_success "public Views alone do not mandate snapshots" \
  grep -q 'A `public View` alone does not require a snapshot' "$REPO_ROOT/.claude/skills/create-feature/SKILL.md"
expect_success "review workflow checks staged and unstaged whitespace" \
  grep -q 'git diff HEAD --check' "$REPO_ROOT/.claude/skills/reviewing-code-changes/SKILL.md"
expect_success "validate command checks staged and unstaged whitespace" \
  grep -q 'git diff HEAD --check' "$REPO_ROOT/.claude/commands/validate.md"
expect_success "subagent gate remains valid shell" bash -n "$REPO_ROOT/.claude/hooks/subagent-gate.sh"

# Prose-only rules: one assertion per rule, each red if the sentence is deleted.
expect_success "reviewer caps review rounds" \
  grep -q 'At most three review rounds per candidate' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "verifier caps verification rounds" \
  grep -q 'At most three verification rounds per candidate' "$REPO_ROOT/.claude/agents/verifier.md"
expect_success "tester caps test rounds" \
  grep -q 'At most three test rounds per candidate' "$REPO_ROOT/.claude/agents/tester.md"
expect_success "nits never start a round of their own" \
  grep -q 'Nits are non-blocking and never start a round of their own' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "re-reviews are scoped to the diff" \
  grep -q 'From round 2 on, inspect the paths changed since your previous report' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "fresh reviewers are justified, not just mandated" \
  grep -q 'confirmation bias' "$REPO_ROOT/.claude/skills/reviewing-code-changes/SKILL.md"
expect_success "mutating checkers are serialized" \
  grep -q 'Reviewers run one after another, never in parallel' "$REPO_ROOT/.claude/skills/reviewing-code-changes/SKILL.md"
expect_success "the round counter is read before it is overwritten" \
  grep -q 'survives only if you read the' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "handoff carries open findings, not cleared verdicts" \
  grep -q 'Do not record which files you cleared' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "Bug severity requires a falsifiable failure scenario" \
  grep -q 'must name a concrete failure scenario' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "the base review does not authorize a test run" \
  grep -q 'Do not run the test suite' "$REPO_ROOT/.claude/skills/reviewing-code-changes/references/base-review.md"
expect_success "the base review no longer tells the reviewer to run tests" \
  bash -c '! grep -q "Run or verify the smallest complete test set" "'"$REPO_ROOT"'/.claude/skills/reviewing-code-changes/references/base-review.md"'
expect_success "the orchestrator owns the round cap" \
  grep -q 'do not spawn a fourth' "$REPO_ROOT/.claude/skills/reviewing-code-changes/SKILL.md"
expect_success "the round counter is documented as a hint, not a bound fact" \
  grep -q 'self-reported hint, not a bound fact' "$REPO_ROOT/.claude/agents/reviewer.md"
expect_success "diff scoping does not narrow across public declarations" \
  grep -q 'protocol conformance, do not narrow' "$REPO_ROOT/.claude/agents/reviewer.md"

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

# `--result-bundle` guards its argument. These run without Xcode because a bad
# argument exits during parsing, long before any destination or toolchain is
# touched — the rest of the script stays outside this hermetic suite by design.
TEST_PACKAGES="$REPO_ROOT/scripts/test-affected-packages.sh"

# Asserting on the message, not merely on failure: without the guard the run
# still fails, but inside `mkdir` with `illegal option -- -`, which names the
# wrong problem. A plain `expect_failure` here passes either way and proves
# nothing — measured, after a first version of these checks did exactly that.
expect_equal "1" \
  "$(cd "$REPO_ROOT" && bash "$TEST_PACKAGES" --result-bundle --list FitnessUI 2>&1 |
      grep -c 'ERROR: --result-bundle needs a directory.')" \
  "--result-bundle names the real problem when handed a flag"

expect_equal "0" \
  "$(cd "$REPO_ROOT" && bash "$TEST_PACKAGES" --result-bundle --list FitnessUI 2>&1 |
      grep -c 'illegal option')" \
  "--result-bundle fails before mkdir sees the flag"

expect_success "--list still resolves a schedule without touching Xcode" \
  bash -c "cd '$REPO_ROOT' && bash '$TEST_PACKAGES' --list FitnessUI >/dev/null 2>&1"

echo "PASS: $pass_count workflow fixture checks"
