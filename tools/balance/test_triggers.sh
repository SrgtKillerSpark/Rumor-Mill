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
echo "--- phase1_digest smoke tests ---"

DIGEST="$(cd "$(dirname "$0")" && pwd)/phase1_digest.js"
ANALYTICS_FIXTURES="$(cd "$(dirname "$0")/../analytics/fixtures" && pwd)"

# Digest runs on watchlist smoke fixture and produces markdown output
DIGEST_OUT="$TMPDIR_LOCAL/digest_smoke.md"
node "$DIGEST" --out "$DIGEST_OUT" "$ANALYTICS_FIXTURES/watchlist_smoke.ndjson" 2>/dev/null
DIGEST_EXIT=$?

# Should exit 0 (no triggers fired — sample sizes too small for smoke data)
if [ "$DIGEST_EXIT" -eq 0 ]; then
  echo "PASS: digest_watchlist_smoke exit 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: digest_watchlist_smoke (expected exit 0, got $DIGEST_EXIT)"
  FAIL=$((FAIL + 1))
fi

# Verify digest contains expected sections
for section in "Phase 1 Balance Digest" "Watchlist Trigger Summary" "Notable Signals" "Per-Lane KPI Table" "Volume"; do
  if grep -q "$section" "$DIGEST_OUT"; then
    echo "PASS: digest contains '$section'"
    PASS=$((PASS + 1))
  else
    echo "FAIL: digest missing '$section'"
    FAIL=$((FAIL + 1))
  fi
done

# Verify trigger IDs from the spec appear in the digest
for tid in "2-A" "2-B" "3-A" "3-B" "GEN-WALL" "GEN-COMP"; do
  if grep -q "$tid" "$DIGEST_OUT"; then
    echo "PASS: digest references trigger $tid"
    PASS=$((PASS + 1))
  else
    echo "FAIL: digest missing trigger $tid"
    FAIL=$((FAIL + 1))
  fi
done

# Verify digest runs on day6 fixture too
node "$DIGEST" "$ANALYTICS_FIXTURES/day6_s2_apprentice.ndjson" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "PASS: digest_day6_s2_apprentice exit 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: digest_day6_s2_apprentice unexpected failure"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
