#!/usr/bin/env node
/**
 * test_check_gdscript_static.js — regression tests for check_gdscript_static.js
 *
 * SPA-1560: locks down Check 5 (SPA-1543 backslash-continuation pattern).
 *
 * Tests:
 *   1. Check 5 fires on the fixtures/check5_regression fixture.
 *   2. The real rumor_mill project is clean (no false positives).
 *
 * No external test framework — uses Node's built-in `assert` module.
 * Run directly:  node rumor_mill/tools/test_check_gdscript_static.js
 * Or via:        bash rumor_mill/tools/test_static_checks.sh
 */
'use strict';

const assert      = require('assert');
const path        = require('path');
const { spawnSync } = require('child_process');

const CHECKER          = path.resolve(__dirname, 'check_gdscript_static.js');
const FIXTURE_DIR      = path.resolve(__dirname, 'fixtures', 'check5_regression');
const REAL_PROJECT_DIR = path.resolve(__dirname, '..');

function runChecker(projectPath) {
  return spawnSync(
    process.execPath,
    [CHECKER, '--project', projectPath],
    { encoding: 'utf8' }
  );
}

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  PASS  ${name}`);
    passed++;
  } catch (e) {
    console.error(`  FAIL  ${name}`);
    console.error(`        ${e.message}`);
    failed++;
  }
}

// ── Test 1: Check 5 fires on the regression fixture ──────────────────────────
// Expects exit 1 and the specific Check 5 diagnostic for bad_continuation.gd.
test('Check 5 flags var := with backslash continuation (SPA-1543 fixture)', () => {
  const r = runChecker(FIXTURE_DIR);
  assert.strictEqual(
    r.status, 1,
    `Expected exit code 1 (errors found), got ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`
  );
  assert.ok(
    r.stdout.includes('uses inferred type with backslash continuation'),
    `Expected Check 5 diagnostic message in output.\nActual stdout:\n${r.stdout}`
  );
  assert.ok(
    r.stdout.includes('bad_continuation.gd'),
    `Expected fixture filename 'bad_continuation.gd' in output.\nActual stdout:\n${r.stdout}`
  );
});

// ── Test 2: Real project is clean — no false positives ───────────────────────
// Guards against accidentally shipping code that re-introduces the pattern.
// Also guards against Check 5 creating new false positives in existing scripts.
test('No Check 5 false positives on real project scripts (SPA-1560 regression guard)', () => {
  const r = runChecker(REAL_PROJECT_DIR);
  assert.strictEqual(
    r.status, 0,
    `Static checker found issue(s) in the real project — should be clean.\n` +
    `stdout:\n${r.stdout}\nstderr:\n${r.stderr}`
  );
});

// ── Summary ───────────────────────────────────────────────────────────────────
console.log('');
console.log(`check_gdscript_static: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
