#!/usr/bin/env bash
# test_gdscript_guard.sh — validates Check 6 (UID missing) and Check 7 (removed constant)
# Reproduces SPA-1677, SPA-1678, SPA-1684 regression conditions.
#
# Exit codes:
#   0 — all assertions pass
#   1 — one or more assertions failed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/check_gdscript_static.js"

passed=0
failed=0

pass() {
  echo "  PASS  $1"
  ((passed++)) || true
}

fail() {
  echo "  FAIL  $1"
  ((failed++)) || true
}

echo "═══════════════════════════════════════════════"
echo "  GDScript Guard — Regression Test Suite"
echo "═══════════════════════════════════════════════"
echo ""

# ── Test 1: Check 6 fires on missing .uid fixture (SPA-1677) ─────────────────
echo "── Check 6: UID missing (SPA-1677) ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/fixtures/check6_uid_missing" 2>&1)
exit_code=$?

if [ "$exit_code" = "1" ]; then pass "Check 6 returns exit 1 on missing .uid"; else fail "Check 6 returns exit 1 on missing .uid (got $exit_code)"; fi
if echo "$output" | grep -qF "SPA-1677"; then pass "Check 6 mentions SPA-1677"; else fail "Check 6 mentions SPA-1677"; fi
if echo "$output" | grep -qF "ui_layout_constants.gd"; then pass "Check 6 names the file"; else fail "Check 6 names the file"; fi
echo ""

# ── Test 2: Check 7 fires on removed constant (SPA-1678) ─────────────────────
echo "── Check 7: Removed constant (SPA-1678/1684) ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/fixtures/check7_removed_constant" 2>&1)
exit_code=$?

if [ "$exit_code" = "1" ]; then pass "Check 7 returns exit 1 on removed constant"; else fail "Check 7 returns exit 1 (got $exit_code)"; fi
if echo "$output" | grep -qF "MAX_DISRUPT_CHARGES"; then pass "Check 7 flags MAX_DISRUPT_CHARGES"; else fail "Check 7 flags MAX_DISRUPT_CHARGES"; fi
if echo "$output" | grep -qF "SPA-1678"; then pass "Check 7 mentions SPA-1678"; else fail "Check 7 mentions SPA-1678"; fi
# AGENT_NAME exists in the class, so it should NOT appear as an ERROR
if echo "$output" | grep -F "AGENT_NAME" | grep -q "ERROR"; then
  fail "Check 7 should not flag existing constant AGENT_NAME"
else
  pass "Check 7 does not flag existing constant AGENT_NAME"
fi
echo ""

# ── Test 3: Check 7 fires on var accessed as const (SPA-1867 category #1) ────
echo "── Check 7: var-vs-const static access (SPA-1867) ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/fixtures/check7_var_as_const" 2>&1)
exit_code=$?

if [ "$exit_code" = "1" ]; then pass "Check 7 returns exit 1 on var accessed statically"; else fail "Check 7 returns exit 1 on var accessed statically (got $exit_code)"; fi
if echo "$output" | grep -qF "STATE_RING_COLOR"; then pass "Check 7 flags STATE_RING_COLOR (var accessed as const)"; else fail "Check 7 flags STATE_RING_COLOR"; fi
if echo "$output" | grep -qF "SPA-1867"; then pass "Check 7 mentions SPA-1867"; else fail "Check 7 mentions SPA-1867"; fi
if echo "$output" | grep -qF "declared as 'var'"; then pass "Check 7 error says 'declared as var'"; else fail "Check 7 error says 'declared as var'"; fi
# RING_WIDTH is a real const — should NOT be flagged
if echo "$output" | grep -F "RING_WIDTH" | grep -q "ERROR"; then
  fail "Check 7 should not flag existing const RING_WIDTH"
else
  pass "Check 7 does not flag existing const RING_WIDTH"
fi
echo ""

# ── Test 4: Check 7 fires on _SCREAMING_CASE constant in test file (SPA-1867 category #2) ─
echo "── Check 7: underscore-prefixed missing constant (SPA-1867) ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/fixtures/check7_underscore_const" 2>&1)
exit_code=$?

if [ "$exit_code" = "1" ]; then pass "Check 7 returns exit 1 on _DEGRADE_MAP"; else fail "Check 7 returns exit 1 on _DEGRADE_MAP (got $exit_code)"; fi
if echo "$output" | grep -qF "_DEGRADE_MAP"; then pass "Check 7 flags _DEGRADE_MAP (underscore-prefixed)"; else fail "Check 7 flags _DEGRADE_MAP"; fi
if echo "$output" | grep -qF "SPA-1678"; then pass "Check 7 mentions SPA-1678 for missing constant"; else fail "Check 7 mentions SPA-1678"; fi
echo ""

# ── Test 5: Real project has no Check 7 false positives ──────────────────────
# Check 6 (UID) failures are pre-existing and tracked separately.
# This test verifies Check 7 (constant references) produces no false positives.
echo "── Real project: no Check 7 false positives ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/.." 2>&1)
check7_errors=$(echo "$output" | grep "ERROR" | grep -v "SPA-1677" | wc -l)

if [ "$check7_errors" = "0" ]; then pass "No Check 7 false positives on real project"; else fail "Check 7 produced $check7_errors error(s) on real project (expected 0)"; fi
echo ""

# ── Test 6: Existing Check 5 regression still passes ─────────────────────────
echo "── Check 5: existing regression (SPA-1543) ──"
output=$(node "$CHECKER" --project "$SCRIPT_DIR/fixtures/check5_regression" 2>&1)
exit_code=$?

if [ "$exit_code" = "1" ]; then pass "Check 5 still fires on backslash continuation fixture"; else fail "Check 5 fixture (got exit $exit_code)"; fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════"
echo "  Results: $passed passed, $failed failed"
echo "═══════════════════════════════════════════════"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
