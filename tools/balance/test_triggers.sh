#!/usr/bin/env bash
# test_triggers.sh — Smoke tests for trigger_detector.js
#
# Runs each NDJSON fixture through the detector (two cycles, to satisfy the
# 2-consecutive-cycle fire rule) and asserts the expected exit code.
#
# Exit codes from trigger_detector.js:
#   0 — no triggers fired
#   1 — one or more triggers fired
#   2 — usage / input error
#
# Usage:
#   bash tools/balance/test_triggers.sh
#
# Issue: SPA-1527

set -uo pipefail

DETECTOR="$(cd "$(dirname "$0")" && pwd)/trigger_detector.js"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures"

PASS=0
FAIL=0

# run_test <name> <expected_exit_code> <state_file> <fixture_path>
#   Runs the fixture twice (two review cycles). On the second run the detector
#   reads the primed state and applies the consecutive-cycle rule.
run_test() {
  local name="$1"
  local expected="$2"
  local state_file="$3"
  local fixture="$4"
  local actual=0

  # Cycle 1 — prime state (may exit 0 or 1; we ignore the code here)
  node "$DETECTOR" --state "$state_file" "$fixture" > /dev/null 2>&1 || true

  # Cycle 2 — final evaluation
  node "$DETECTOR" --state "$state_file" "$fixture" > /dev/null 2>&1 || actual=$?

  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $name (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# Also validate evalThreshold unit tests
echo "--- evalThreshold unit tests ---"
node "$DETECTOR" --test || { echo "FAIL: evalThreshold self-tests failed"; FAIL=$((FAIL + 1)); }
echo ""

# Create a temp dir for per-test state files
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

echo "--- fixture smoke tests ---"

# trigger_2a_fires: Maren fail ratio 70% (>60%) → trigger 2-A should fire → exit 1
run_test "trigger_2a_fires" 1 "$TMPDIR_LOCAL/state_2a.json" "$FIXTURES/trigger_2a_fires.ndjson"

# trigger_3a_fires: Calder >65 at day 15 in 93% of S3 wins (≥90%) → trigger 3-A should fire → exit 1
run_test "trigger_3a_fires" 1 "$TMPDIR_LOCAL/state_3a.json" "$FIXTURES/trigger_3a_fires.ndjson"

# all_clear: balanced data, no trigger fires → exit 0
run_test "all_clear" 0 "$TMPDIR_LOCAL/state_clear.json" "$FIXTURES/all_clear.ndjson"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
