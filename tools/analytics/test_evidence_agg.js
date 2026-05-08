#!/usr/bin/env node
/**
 * test_evidence_agg.js — regression tests for evidence_acquired / evidence_used
 * aggregation in kpi_aggregate.js (SPA-1535).
 *
 * No external test framework — uses Node's built-in `assert` module.
 * Run directly:  node tools/analytics/test_evidence_agg.js
 * Or via:        bash tools/analytics/test_kpi_aggregate.sh
 */
'use strict';

const assert = require('assert');
const path   = require('path');
const { spawnSync } = require('child_process');

const SCRIPT   = path.resolve(__dirname, 'kpi_aggregate.js');
const FIXTURES = path.resolve(__dirname, 'fixtures');

function run(fixture) {
  const r = spawnSync(
    process.execPath,
    [SCRIPT, '--json', path.join(FIXTURES, fixture)],
    { encoding: 'utf8' }
  );
  if (r.status !== 0) {
    throw new Error(`kpi_aggregate.js exited ${r.status} for ${fixture}:\n${r.stderr}`);
  }
  return JSON.parse(r.stdout);
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

// ── Fixture 1: happy path ─────────────────────────────────────────────────────
// 2 evidence_acquired(forged_document) + 1 evidence_acquired(witness_account)
// 2 evidence_used(forged_document)     + 1 evidence_used(witness_account)
// All events have the full field set.

console.log('\nevidence_happy_path.ndjson — happy path: multiple acquired + used, full field set');
const hp     = run('evidence_happy_path.ndjson');
const hpAcq  = hp.evidence_acquired;
const hpUsed = hp.evidence_used;

test('acquired: 2 distinct type×scenario×difficulty rows', () =>
  assert.strictEqual(hpAcq.counts.length, 2));

test('acquired: forged_document count=2', () => {
  const row = hpAcq.counts.find(r => r.evidence_type === 'forged_document');
  assert.ok(row, 'row missing');
  assert.strictEqual(row.count, 2);
});

test('acquired: witness_account count=1', () => {
  const row = hpAcq.counts.find(r => r.evidence_type === 'witness_account');
  assert.ok(row, 'row missing');
  assert.strictEqual(row.count, 1);
});

test('acquired: total ties to fixture (3 events)', () => {
  const total = hpAcq.counts.reduce((s, r) => s + r.count, 0);
  assert.strictEqual(total, 3);
});

test('acquired: dayHist forged_document has days 3 and 5', () => {
  const h = hpAcq.dayHist.forged_document;
  assert.ok(h, 'dayHist entry missing');
  assert.strictEqual(h['3'], 1);
  assert.strictEqual(h['5'], 1);
});

test('acquired: sourceRatio forged_document observe_building=2', () => {
  const s = hpAcq.sourceRatio.forged_document;
  assert.ok(s, 'sourceRatio entry missing');
  assert.strictEqual(s['observe_building'], 2);
});

test('used: 2 distinct type×scenario×difficulty rows', () =>
  assert.strictEqual(hpUsed.counts.length, 2));

test('used: forged_document count=2', () => {
  const row = hpUsed.counts.find(r => r.evidence_type === 'forged_document');
  assert.ok(row, 'row missing');
  assert.strictEqual(row.count, 2);
});

test('used: total ties to fixture (3 events)', () => {
  const total = hpUsed.counts.reduce((s, r) => s + r.count, 0);
  assert.strictEqual(total, 3);
});

test('used: acqToUseRatio forged_document acquired=2 used=2 ratio=1', () => {
  const r = hpUsed.acqToUseRatio.forged_document;
  assert.ok(r, 'ratio entry missing');
  assert.strictEqual(r.acquired, 2);
  assert.strictEqual(r.used, 2);
  assert.strictEqual(r.ratio, 1);
});

test('used: acqToUseRatio witness_account acquired=1 used=1 ratio=1', () => {
  const r = hpUsed.acqToUseRatio.witness_account;
  assert.ok(r, 'ratio entry missing');
  assert.strictEqual(r.acquired, 1);
  assert.strictEqual(r.used, 1);
  assert.strictEqual(r.ratio, 1);
});

test('used: claimCrossTab forged_document has 2 entries (claim_a, claim_b)', () => {
  const rows = hpUsed.claimCrossTab.filter(r => r.evidence_type === 'forged_document');
  assert.strictEqual(rows.length, 2);
  const ids = rows.map(r => r.claim_id).sort();
  assert.deepStrictEqual(ids, ['claim_a', 'claim_b']);
});

test('used: targetCrossTab forged_document has 2 entries (npc_x, npc_y)', () => {
  const rows = hpUsed.targetCrossTab.filter(r => r.evidence_type === 'forged_document');
  assert.strictEqual(rows.length, 2);
  const targets = rows.map(r => r.seed_target).sort();
  assert.deepStrictEqual(targets, ['npc_x', 'npc_y']);
});

// ── Fixture 2: acquired-only (never used) ─────────────────────────────────────
// 2 evidence_acquired(forged_document) + 1 evidence_acquired(witness_account)
// 0 evidence_used events.
// Both types must appear in acqToUseRatio with used=0 and ratio=0.

console.log('\nevidence_acquired_only.ndjson — mixed: acquired but never used');
const ao     = run('evidence_acquired_only.ndjson');
const aoAcq  = ao.evidence_acquired;
const aoUsed = ao.evidence_used;

test('acquired: 2 rows (forged_document + witness_account)', () =>
  assert.strictEqual(aoAcq.counts.length, 2));

test('acquired: forged_document count=2', () => {
  const row = aoAcq.counts.find(r => r.evidence_type === 'forged_document');
  assert.ok(row, 'row missing');
  assert.strictEqual(row.count, 2);
});

test('acquired: witness_account count=1', () => {
  const row = aoAcq.counts.find(r => r.evidence_type === 'witness_account');
  assert.ok(row, 'row missing');
  assert.strictEqual(row.count, 1);
});

test('acquired: total ties to fixture (3 events)', () => {
  const total = aoAcq.counts.reduce((s, r) => s + r.count, 0);
  assert.strictEqual(total, 3);
});

test('used: counts is empty (nothing used)', () =>
  assert.strictEqual(aoUsed.counts.length, 0));

test('used: claimCrossTab is empty', () =>
  assert.strictEqual(aoUsed.claimCrossTab.length, 0));

test('used: acqToUseRatio forged_document used=0 ratio=0', () => {
  const r = aoUsed.acqToUseRatio.forged_document;
  assert.ok(r, 'ratio entry missing');
  assert.strictEqual(r.acquired, 2);
  assert.strictEqual(r.used, 0);
  assert.strictEqual(r.ratio, 0);
});

test('used: acqToUseRatio witness_account used=0 ratio=0', () => {
  const r = aoUsed.acqToUseRatio.witness_account;
  assert.ok(r, 'ratio entry missing');
  assert.strictEqual(r.acquired, 1);
  assert.strictEqual(r.used, 0);
  assert.strictEqual(r.ratio, 0);
});

// ── Fixture 3: malformed / missing fields ─────────────────────────────────────
// Line 1: valid forged_document acquisition
// Line 2: invalid JSON — silently skipped by loadFiles
// Line 3: evidence_acquired with missing evidence_type → falls back to 'unknown'
// Line 4: evidence_used with missing evidence_type/claim_id/seed_target → 'unknown'
// Line 5: evidence_acquired with missing day → day becomes 'unknown'

console.log('\nevidence_malformed.ndjson — edge: malformed / missing fields, no crash');
const mf     = run('evidence_malformed.ndjson');
const mfAcq  = mf.evidence_acquired;
const mfUsed = mf.evidence_used;

test('script exits 0 on malformed input (no crash)', () => {
  // spawnSync already enforced exit 0 inside run(); reaching here means pass.
  assert.ok(true);
});

test('acquired: known-good forged_document counted (count=1)', () => {
  const row = mfAcq.counts.find(r => r.evidence_type === 'forged_document');
  assert.ok(row, 'forged_document row missing');
  assert.strictEqual(row.count, 1);
});

test('acquired: missing evidence_type falls back to "unknown"', () => {
  const row = mfAcq.counts.find(r => r.evidence_type === 'unknown');
  assert.ok(row, '"unknown" row missing');
  assert.ok(row.count >= 1);
});

test('acquired: witness_account with missing day still counted', () => {
  const row = mfAcq.counts.find(r => r.evidence_type === 'witness_account');
  assert.ok(row, 'witness_account row missing');
  assert.strictEqual(row.count, 1);
});

test('acquired: dayHist witness_account has "unknown" day bucket', () => {
  const h = mfAcq.dayHist.witness_account;
  assert.ok(h, 'dayHist entry missing');
  assert.strictEqual(h['unknown'], 1);
});

test('used: missing-field event counted under "unknown" type', () => {
  const row = mfUsed.counts.find(r => r.evidence_type === 'unknown');
  assert.ok(row, '"unknown" used row missing');
  assert.ok(row.count >= 1);
});

// ── Result ────────────────────────────────────────────────────────────────────
console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
