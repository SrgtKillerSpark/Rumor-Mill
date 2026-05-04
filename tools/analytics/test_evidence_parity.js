#!/usr/bin/env node
/**
 * test_evidence_parity.js — Phase 2 telemetry regression: evidence_acquired ↔ evidence_used
 *
 * Asserts evidence-economy event integrity against fixture NDJSON files (SPA-1593).
 *
 * For each fixture, across every run (scenario_selected … scenario_ended):
 *   1. Every evidence_used has a matching *prior* evidence_acquired with the same
 *      evidence_type in the same run (orphan check).
 *   2. No evidence_acquired appears more than once for the same
 *      (evidence_type, day, scenario_id, source_action) tuple (save-load double-fire guard).
 *   3. Acquisition count >= used count per evidence_type (can't use what you didn't acquire).
 *
 * Run directly:  node tools/analytics/test_evidence_parity.js
 * Or via:        bash tools/analytics/test_kpi_aggregate.sh
 */
'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');

const FIXTURES_DIR     = path.resolve(__dirname, 'fixtures');
const TARGET_FIXTURES  = [
  'day7_s2_normal.ndjson',
  'day7_s4_normal.ndjson',
  'day6_s4_apprentice.ndjson',
];

// ── helpers ──────────────────────────────────────────────────────────────────

function loadNDJSON(filePath) {
  return fs.readFileSync(filePath, 'utf8')
    .split('\n')
    .filter(l => l.trim())
    .reduce((acc, line) => {
      try { acc.push(JSON.parse(line)); } catch (_) { /* skip malformed */ }
      return acc;
    }, []);
}

/**
 * Segment events into runs.  A run begins at scenario_selected and ends at
 * scenario_ended.  An open-ended trailing run (no closing scenario_ended) is
 * also collected so save-load mid-scenario sessions are tested.
 */
function segmentRuns(events) {
  const runs = [];
  let current = null;
  for (const ev of events) {
    if (ev.type === 'scenario_selected') {
      current = { events: [], runIdx: runs.length + 1 };
    }
    if (current) current.events.push(ev);
    if (ev.type === 'scenario_ended' && current) {
      runs.push(current);
      current = null;
    }
  }
  if (current && current.events.length > 0) runs.push(current);
  return runs;
}

/**
 * Check the three parity assertions for a single run.
 * Throws a descriptive Error on any violation.
 */
function assertRunParity(run, fixtureName) {
  const { events, runIdx } = run;
  const prefix = `[${fixtureName}] run ${runIdx}`;

  // Build per-type counts and detect orphaned evidence_used in document order.
  const acquiredByType = {}; // evidence_type → count seen so far (in order)

  for (const ev of events) {
    if (ev.type === 'evidence_acquired') {
      const t = ev.evidence_type || 'unknown';
      acquiredByType[t] = (acquiredByType[t] || 0) + 1;
    }

    if (ev.type === 'evidence_used') {
      const t = ev.evidence_type || 'unknown';
      // Assertion 1: prior evidence_acquired with same type must exist
      if (!acquiredByType[t]) {
        throw new Error(
          `${prefix}: orphaned evidence_used — type "${t}" ` +
          `(claim_id=${ev.claim_id ?? 'n/a'}, day=${ev.day ?? 'n/a'}) ` +
          `has no prior evidence_acquired with the same evidence_type in this run`
        );
      }
    }
  }

  const acquired = events.filter(e => e.type === 'evidence_acquired');
  const used     = events.filter(e => e.type === 'evidence_used');

  // Assertion 2: no duplicate (evidence_type, day, scenario_id, source_action) tuple
  const seen = new Map();
  for (const ev of acquired) {
    const key = `${ev.evidence_type}|${ev.day}|${ev.scenario_id}|${ev.source_action}`;
    if (seen.has(key)) {
      throw new Error(
        `${prefix}: duplicate evidence_acquired — ` +
        `type="${ev.evidence_type}" day=${ev.day} scenario_id=${ev.scenario_id} ` +
        `source_action=${ev.source_action} (possible save-load double-fire)`
      );
    }
    seen.set(key, true);
  }

  // Assertion 3: acquisition count >= used count per evidence_type
  const acqCount  = {};
  const usedCount = {};
  for (const ev of acquired) {
    const t = ev.evidence_type || 'unknown';
    acqCount[t] = (acqCount[t] || 0) + 1;
  }
  for (const ev of used) {
    const t = ev.evidence_type || 'unknown';
    usedCount[t] = (usedCount[t] || 0) + 1;
  }
  for (const [t, uc] of Object.entries(usedCount)) {
    const ac = acqCount[t] || 0;
    if (ac < uc) {
      throw new Error(
        `${prefix}: evidence_type "${t}" used ${uc}× but only acquired ${ac}× ` +
        `(can't use what you didn't acquire)`
      );
    }
  }
}

// ── test runner ───────────────────────────────────────────────────────────────

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

// ── per-fixture tests ─────────────────────────────────────────────────────────

for (const fixture of TARGET_FIXTURES) {
  const filePath = path.join(FIXTURES_DIR, fixture);
  console.log(`\n${fixture}`);

  let events;
  test(`${fixture}: loads without error`, () => {
    events = loadNDJSON(filePath);
    assert.ok(events.length > 0, `fixture is empty: ${filePath}`);
  });

  if (!events) continue; // load failed; skip rest for this fixture

  const runs = segmentRuns(events);

  test(`${fixture}: has at least one run (scenario_selected…scenario_ended)`, () => {
    assert.ok(runs.length > 0, 'no runs found');
  });

  const evidenceRuns = runs.filter(r =>
    r.events.some(e => e.type === 'evidence_acquired' || e.type === 'evidence_used')
  );

  test(`${fixture}: at least one run contains evidence events`, () => {
    assert.ok(
      evidenceRuns.length > 0,
      'no runs with evidence_acquired or evidence_used found — fixture may need updating'
    );
  });

  for (const run of evidenceRuns) {
    test(`${fixture} run ${run.runIdx}: parity (orphan check, no double-fire, acq≥used)`, () => {
      assertRunParity(run, fixture);
    });
  }
}

// ── result ────────────────────────────────────────────────────────────────────

console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
