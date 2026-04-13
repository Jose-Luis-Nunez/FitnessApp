#!/bin/bash
# Shared grind-loop logic for stop-hook checks.
#
# Usage:
#   source "$HOOKS_DIR/lib/grind-loop.sh"
#   run_grind_loop <scratchpad> <stamp_file> <diff_hash> <content_pattern> <followup_msg>
#
# Env (set by orchestrator): CONTENT, STATE_DIR, MAX_GRIND_ITERATIONS, HAS_QUESTION
#
# Behavior:
#   1. If agent is asking a question ($HAS_QUESTION > 0), skip silently.
#   2. If diff_hash changed since last run, reset iteration counter.
#   3. If stamp file is fresh (< 10 min) OR content matches pattern, mark done.
#   4. If iteration cap reached, mark cap_reached and stop retrying.
#   5. Otherwise, emit followup_msg and increment iteration.
#
# The scratchpad stays "done" as long as the diff_hash hasn't changed —
# a stale stamp alone does NOT trigger a re-validation. Only a new set of
# changed files (= new diff_hash) resets the loop.

run_grind_loop() {
  local scratchpad="$1"
  local stamp_file="$2"
  local diff_hash="$3"
  local content_pattern="$4"
  local followup_msg="$5"

  if [ "$HAS_QUESTION" -gt 0 ]; then
    return 0
  fi

  # Read scratchpad state
  local sp_status="pending"
  local sp_iteration=0
  local sp_diff_hash=""

  if [ -f "$scratchpad" ]; then
    sp_status=$(python3 -c "import json; print(json.load(open('$scratchpad')).get('status','pending'))" 2>/dev/null || echo "pending")
    sp_iteration=$(python3 -c "import json; print(json.load(open('$scratchpad')).get('iteration',0))" 2>/dev/null || echo "0")
    sp_diff_hash=$(python3 -c "import json; print(json.load(open('$scratchpad')).get('diff_hash',''))" 2>/dev/null || echo "")
  fi

  # Reset if file set changed (new diff_hash = new changes to validate)
  if [ "$diff_hash" != "$sp_diff_hash" ]; then
    sp_iteration=0
    sp_status="pending"
  fi

  # If already validated for this exact set of files, stay done
  if [ "$sp_status" = "done" ]; then
    return 0
  fi

  # Check for fresh stamp
  local has_stamp=false
  if [ -f "$stamp_file" ]; then
    local stamp_age
    stamp_age=$(python3 -c "
import os, time
try:
    age = time.time() - os.path.getmtime('$stamp_file')
    print('fresh' if age < 600 else 'stale')
except: print('stale')
" 2>/dev/null || echo "stale")
    if [ "$stamp_age" = "fresh" ]; then
      has_stamp=true
    fi
  fi

  # Check for validation output in agent content
  local ran_check=0
  ran_check=$(echo "$CONTENT" | grep -ciE "$content_pattern" || true)

  if [ "$has_stamp" = true ] || [ "$ran_check" -gt 0 ]; then
    python3 -c "
import json
data = {'status': 'done', 'iteration': $sp_iteration, 'diff_hash': '$diff_hash'}
json.dump(data, open('$scratchpad', 'w'), indent=2)
" 2>/dev/null
    return 0
  fi

  if [ "$sp_iteration" -ge "$MAX_GRIND_ITERATIONS" ]; then
    python3 -c "
import json
data = {'status': 'cap_reached', 'iteration': $sp_iteration, 'diff_hash': '$diff_hash'}
json.dump(data, open('$scratchpad', 'w'), indent=2)
" 2>/dev/null
    return 0
  fi

  local new_iter=$((sp_iteration + 1))
  python3 -c "
import json
data = {'status': 'pending', 'iteration': $new_iter, 'diff_hash': '$diff_hash'}
json.dump(data, open('$scratchpad', 'w'), indent=2)
" 2>/dev/null

  echo "[Grind Loop — Iteration ${new_iter}/${MAX_GRIND_ITERATIONS}] ${followup_msg}"
}
