#!/usr/bin/env node
/**
 * trigger_detector.js — Phase 1 Balance Trigger Detector
 *
 * Consumes NDJSON telemetry (same format as kpi_aggregate.js) and evaluates
 * every trigger in docs/phase1-balance-watchlist.spec.yaml. Outputs a JSON
 * array of results: one entry per trigger with the computed metric value,
 * threshold, whether it fired, and whether min_sample was met.
 *
 * Usage:
 *   node tools/balance/trigger_detector.js <file.ndjson> [file2.ndjson ...]
 *   node tools/balance/trigger_detector.js --state state.json <files...>
 *
 * Options:
 *   --state <path>   Track consecutive-cycle state for the 2-cycle rule.
 *                     If omitted, evaluates a single cycle (no persistence).
 *   --pretty         Pretty-print JSON output.
 *
 * Exit codes:
 *   0 — no triggers fired
 *   1 — one or more triggers fired (threshold met + min_sample met)
 *   2 — usage / input error
 *
 * Issue: SPA-1520
 * Refs: SPA-1490, SPA-1514
 *
 * No external dependencies — stdlib only.
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ── NDJSON loader (shared pattern with kpi_aggregate.js) ─────────────────────

function loadEvents(filePaths) {
  const events = [];
  for (const fp of filePaths) {
    const raw = fs.readFileSync(fp, 'utf8');
    for (const line of raw.split('\n')) {
      if (!line.trim()) continue;
      try {
        const ev = JSON.parse(line);
        ev._source = fp;
        events.push(ev);
      } catch { /* skip malformed */ }
    }
  }
  return events;
}

// ── Session grouping (mirrors kpi_aggregate.js) ─────────────────────────────

function groupSessions(events) {
  const byFile = {};
  for (const ev of events) {
    (byFile[ev._source] || (byFile[ev._source] = [])).push(ev);
  }

  const sessions = [];
  let idx = 0;

  for (const [file, fileEvents] of Object.entries(byFile)) {
    let cur = null;
    for (const ev of fileEvents) {
      if (ev.type === 'scenario_selected') {
        if (cur) sessions.push(cur);
        cur = {
          id: `${file}#${idx++}`,
          file,
          scenario_id: ev.scenario_id,
          difficulty: ev.difficulty,
          events: [ev],
          ended: false,
          outcome: null,
          day_reached: null,
        };
      } else if (cur) {
        cur.events.push(ev);
        if (ev.type === 'scenario_ended') {
          cur.ended = true;
          cur.outcome = ev.outcome;
          cur.day_reached = ev.day_reached;
          if (ev.scenario_id) cur.scenario_id = ev.scenario_id;
          sessions.push(cur);
          cur = null;
        }
      }
    }
    if (cur) sessions.push(cur);
  }
  return sessions;
}

// ── Metric computers ─────────────────────────────────────────────────────────
// Each function returns { value, sample, details } where:
//   value  — the computed metric (number or object for compound metrics)
//   sample — the sample size to check against min_sample
//   details — optional human-readable context

function median(arr) {
  if (!arr.length) return null;
  const s = [...arr].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 === 0 ? (s[m - 1] + s[m]) / 2 : s[m];
}

function scenarioMatch(id, pattern) {
  // Match "scenario_2" or "S2" etc. against pattern like "scenario_2"
  if (!pattern) return true;
  const norm = s => String(s).toLowerCase().replace(/[^a-z0-9]/g, '');
  return norm(id) === norm(pattern);
}

function npcMatch(name, pattern) {
  // Pattern may be a regex string like "/maren/i"
  if (!pattern) return true;
  const m = String(pattern).match(/^\/(.+)\/([gimsuy]*)$/);
  if (m) return new RegExp(m[1], m[2]).test(String(name));
  return String(name).toLowerCase() === String(pattern).toLowerCase();
}

// ── Trigger 2-A / 2-B: Maren fail ratio ─────────────────────────────────────

function computeNpcFailRatio(sessions, scenarioId, npcPattern) {
  const failed = sessions.filter(
    s => scenarioMatch(s.scenario_id, scenarioId) && s.outcome === 'FAILED'
  );
  const npcFails = failed.filter(s =>
    s.events.some(ev =>
      ev.type === 'scenario_fail_trigger' &&
      npcMatch(ev.trigger_npc_id, npcPattern)
    ) ||
    s.events.some(ev =>
      ev.type === 'npc_state_changed' &&
      npcMatch(ev.npc_name, npcPattern) &&
      ev.new_state === 'REJECT'
    )
  );
  return {
    value: failed.length ? npcFails.length / failed.length : null,
    sample: failed.length,
    details: `${npcFails.length}/${failed.length} failed sessions`,
  };
}

// ── Trigger 2-C / GEN-WALL: difficulty wall ─────────────────────────────────

function computeMaxDayConcentration(sessions, scenarioId) {
  const failed = sessions.filter(
    s => (!scenarioId || scenarioMatch(s.scenario_id, scenarioId)) &&
         s.outcome === 'FAILED' && s.day_reached != null
  );
  if (!failed.length) return { value: null, sample: 0, details: 'no failures' };

  // Per scenario_id if scenarioId is null (GEN-WALL)
  if (!scenarioId) {
    const byScen = {};
    for (const s of failed) {
      (byScen[s.scenario_id] || (byScen[s.scenario_id] = [])).push(s);
    }
    let worstConc = 0;
    let worstScen = null;
    let worstDay = null;
    for (const [scen, scenSessions] of Object.entries(byScen)) {
      const hist = {};
      for (const s of scenSessions) hist[s.day_reached] = (hist[s.day_reached] || 0) + 1;
      for (const [day, count] of Object.entries(hist)) {
        const conc = count / scenSessions.length;
        if (conc > worstConc) { worstConc = conc; worstScen = scen; worstDay = day; }
      }
    }
    return {
      value: worstConc,
      sample: failed.length,
      details: `worst: ${worstScen} day ${worstDay} (${(worstConc * 100).toFixed(1)}%)`,
    };
  }

  const hist = {};
  for (const s of failed) hist[s.day_reached] = (hist[s.day_reached] || 0) + 1;
  let maxConc = 0;
  let maxDay = null;
  for (const [day, count] of Object.entries(hist)) {
    const conc = count / failed.length;
    if (conc > maxConc) { maxConc = conc; maxDay = day; }
  }
  return {
    value: maxConc,
    sample: failed.length,
    details: `day ${maxDay}: ${(maxConc * 100).toFixed(1)}%`,
  };
}

// ── Trigger 2-D: seed-to-believe gap + reject rate ──────────────────────────

function computeSeedToBelieve(sessions, scenarioId) {
  const gaps = [];
  let rejectCount = 0;
  let believeCount = 0;

  for (const s of sessions) {
    if (!scenarioMatch(s.scenario_id, scenarioId)) continue;

    const seeds = {};
    const believes = {};
    for (const ev of s.events) {
      if (ev.type === 'rumor_seeded' && ev.claim_id != null) {
        if (!(ev.claim_id in seeds)) seeds[ev.claim_id] = ev.day;
      } else if (ev.type === 'npc_state_changed') {
        if (ev.new_state === 'BELIEVE') {
          (believes[ev.rumor_id] || (believes[ev.rumor_id] = [])).push(ev.day);
          believeCount++;
        } else if (ev.new_state === 'REJECT') {
          rejectCount++;
        }
      }
    }

    for (const [claimId, seedDay] of Object.entries(seeds)) {
      if (!believes[claimId]) continue;
      gaps.push(Math.min(...believes[claimId]) - seedDay);
    }
  }

  const totalDecisions = believeCount + rejectCount;
  return {
    value: {
      seed_to_believe_median: gaps.length ? median(gaps) : null,
      reject_rate: totalDecisions ? rejectCount / totalDecisions : null,
    },
    sample: gaps.length,
    details: `${gaps.length} seed-believe pairs, reject rate ${totalDecisions ? (rejectCount / totalDecisions * 100).toFixed(1) : 'N/A'}%`,
  };
}

// ── Trigger 3-A: Calder day-15 rep in S3 wins ──────────────────────────────

function computeCalderDay15(sessions) {
  const s3Won = sessions.filter(
    s => scenarioMatch(s.scenario_id, 'scenario_3') && s.outcome === 'WON'
  );
  const reps = [];
  for (const s of s3Won) {
    // Prefer reputation_snapshot
    const snaps = s.events
      .filter(ev => ev.type === 'reputation_snapshot' && npcMatch(ev.npc_id, '/calder/i') && (ev.day || 0) <= 15)
      .sort((a, b) => (a.day || 0) - (b.day || 0));
    if (snaps.length) {
      const score = snaps[snaps.length - 1].score ?? snaps[snaps.length - 1].reputation;
      if (score != null) { reps.push(score); continue; }
    }
    // Fallback: reputation_delta
    const deltas = s.events
      .filter(ev => ev.type === 'reputation_delta' && npcMatch(ev.npc_id, '/calder/i'))
      .sort((a, b) => (a.day || 0) - (b.day || 0));
    if (!deltas.length || deltas[0].from_score == null) continue;
    let rep = deltas[0].from_score;
    for (const ev of deltas) {
      if ((ev.day || 0) <= 15) rep += (ev.delta || 0);
    }
    reps.push(rep);
  }
  const above65 = reps.filter(r => r > 65).length;
  return {
    value: reps.length ? above65 / reps.length : null,
    sample: reps.length,
    details: `${above65}/${reps.length} S3 wins with Calder >65 at day 15`,
  };
}

// ── Trigger 3-B: S3 mid-quit ratio ─────────────────────────────────────────

function computeS3MidQuit(sessions) {
  const s3Failed = sessions.filter(
    s => scenarioMatch(s.scenario_id, 'scenario_3') && s.outcome === 'FAILED'
  );
  const midQuit = s3Failed.filter(s => s.day_reached >= 15 && s.day_reached <= 19);
  return {
    value: s3Failed.length ? midQuit.length / s3Failed.length : null,
    sample: s3Failed.length,
    details: `${midQuit.length}/${s3Failed.length} S3 fails in days 15-19`,
  };
}

// ── Trigger 3-C: S3 phase-3 rival disruption ───────────────────────────────

function computeRivalDisruption(sessions) {
  const negDeltas = [];
  let sessionsReachingDay16 = 0;

  for (const s of sessions) {
    if (!scenarioMatch(s.scenario_id, 'scenario_3')) continue;
    const maxDay = Math.max(0, ...s.events.map(e => e.day || 0));
    if (maxDay < 16) continue;
    sessionsReachingDay16++;

    for (const ev of s.events) {
      if (ev.type === 'reputation_delta' &&
          (ev.day || 0) >= 16 && (ev.day || 0) <= 27 &&
          (ev.delta || 0) < 0) {
        negDeltas.push(Math.abs(ev.delta));
      }
    }
  }

  const meanNeg = negDeltas.length ? negDeltas.reduce((a, b) => a + b, 0) / negDeltas.length : 0;
  const perDay = negDeltas.length / 12; // days 16-27 = 12 days
  return {
    value: { mean_neg_delta: meanNeg, neg_events_per_day: perDay },
    sample: sessionsReachingDay16,
    details: `mean |neg delta| ${meanNeg.toFixed(1)}, ${perDay.toFixed(2)}/day across ${sessionsReachingDay16} sessions`,
  };
}

// ── Trigger 3-D / X-A: Spymaster completion rate ───────────────────────────

function computeSpymasterCompletion(sessions, scenarioId) {
  // If scenarioId is provided, filter to that scenario; else per-scenario
  const filter = scenarioId
    ? sessions.filter(s => scenarioMatch(s.scenario_id, scenarioId) && s.difficulty === 'spymaster')
    : sessions.filter(s => s.difficulty === 'spymaster');

  if (scenarioId) {
    const won = filter.filter(s => s.outcome === 'WON').length;
    return {
      value: filter.length ? won / filter.length : null,
      sample: filter.length,
      details: `${won}/${filter.length} spymaster completions`,
    };
  }

  // Per-scenario evaluation for X-A
  const byScen = {};
  for (const s of filter) {
    (byScen[s.scenario_id] || (byScen[s.scenario_id] = { total: 0, won: 0 }));
    byScen[s.scenario_id].total++;
    if (s.outcome === 'WON') byScen[s.scenario_id].won++;
  }

  // Find the worst-performing scenario that meets min_sample
  let worstRate = 1;
  let worstScen = null;
  for (const [scen, v] of Object.entries(byScen)) {
    if (v.total < 500) continue;
    const rate = v.won / v.total;
    if (rate < worstRate) { worstRate = rate; worstScen = scen; }
  }
  return {
    value: worstScen != null ? worstRate : null,
    sample: worstScen ? byScen[worstScen].total : 0,
    details: worstScen
      ? `${worstScen}: ${byScen[worstScen].won}/${byScen[worstScen].total}`
      : 'no scenario with 500+ spymaster attempts',
  };
}

// ── Trigger 4-A / 4-B: Finn fail ratio (same pattern as 2-A/2-B) ───────────

// Reuses computeNpcFailRatio with npc_name=/finn/i, scenario_4

// ── Trigger GEN-COMP: completion rate per scenario+difficulty ────────────────

function computeCompletionRate(sessions) {
  const byKey = {};
  for (const s of sessions) {
    if (!s.ended) continue;
    const key = `${s.scenario_id}|${s.difficulty}`;
    if (!byKey[key]) byKey[key] = { scenario_id: s.scenario_id, difficulty: s.difficulty, total: 0, won: 0 };
    byKey[key].total++;
    if (s.outcome === 'WON') byKey[key].won++;
  }

  // Find any bucket that violates thresholds.
  // Violation objects include `completion_rate` so evalThreshold can address the field generically.
  const violations = [];
  for (const v of Object.values(byKey)) {
    if (v.total < 30) continue;
    const completion_rate = v.won / v.total;
    if (v.difficulty === 'Normal' && completion_rate < 0.25) {
      violations.push({ ...v, completion_rate, issue: 'too hard' });
    }
    if (v.difficulty === 'Normal' && completion_rate > 0.85) {
      violations.push({ ...v, completion_rate, issue: 'too easy' });
    }
  }
  return {
    value: violations.length ? violations : null,
    sample: Object.values(byKey).reduce((a, v) => a + v.total, 0),
    details: violations.length
      ? violations.map(v => `${v.scenario_id} ${v.difficulty}: ${(v.completion_rate * 100).toFixed(1)}% (${v.issue})`).join('; ')
      : 'all within bounds',
  };
}

// ── Threshold evaluation ─────────────────────────────────────────────────────

function evalOp(actual, operator, threshold) {
  if (actual == null) return false;
  switch (operator) {
    case '>':  return actual > threshold;
    case '<':  return actual < threshold;
    case '>=': return actual >= threshold;
    case '<=': return actual <= threshold;
    case '==': return actual === threshold;
    default:   return false;
  }
}

// evalThreshold evaluates a full threshold spec object against a computed metric value.
// Handles simple (operator/value), compound (any_of / all_of), and array values
// (fires if any element fires — used by multi-bucket metrics like GEN-COMP).
function evalThreshold(thresholdSpec, value) {
  if (value == null) return false;
  // Array value: fire if any element satisfies the threshold (e.g. GEN-COMP violation list)
  if (Array.isArray(value)) {
    return value.length > 0 && value.some(item => evalThreshold(thresholdSpec, item));
  }
  if (thresholdSpec.any_of) {
    return thresholdSpec.any_of.some(cond => {
      const fieldVal = typeof value === 'object' ? value[cond.field] : value;
      return evalOp(fieldVal, cond.operator, cond.value);
    });
  }
  if (thresholdSpec.all_of) {
    return thresholdSpec.all_of.every(cond => {
      const fieldVal = typeof value === 'object' ? value[cond.field] : value;
      return evalOp(fieldVal, cond.operator, cond.value);
    });
  }
  return evalOp(value, thresholdSpec.operator, thresholdSpec.value);
}

// ── Self-tests for evalThreshold ─────────────────────────────────────────────

function runSelfTests() {
  let passed = 0; let failed = 0;
  function assert(label, actual, expected) {
    if (actual === expected) { process.stderr.write(`  PASS: ${label}\n`); passed++; }
    else { process.stderr.write(`  FAIL: ${label} — got ${actual}, expected ${expected}\n`); failed++; }
  }

  process.stderr.write('evalThreshold() unit tests\n');

  // Simple operators
  assert('simple > true',    evalThreshold({ operator: '>', value: 0.5 }, 0.7), true);
  assert('simple > false',   evalThreshold({ operator: '>', value: 0.5 }, 0.3), false);
  assert('simple >= equal',  evalThreshold({ operator: '>=', value: 0.9 }, 0.9), true);
  assert('simple < true',    evalThreshold({ operator: '<', value: 0.1 }, 0.05), true);
  assert('simple == true',   evalThreshold({ operator: '==', value: 42 }, 42), true);
  assert('simple null value', evalThreshold({ operator: '>', value: 0.5 }, null), false);

  // any_of
  assert('any_of first match', evalThreshold({
    any_of: [
      { field: 'seed_to_believe_median', operator: '>', value: 4 },
      { field: 'reject_rate', operator: '>', value: 0.80 },
    ]
  }, { seed_to_believe_median: 5, reject_rate: 0.5 }), true);

  assert('any_of second match', evalThreshold({
    any_of: [
      { field: 'seed_to_believe_median', operator: '>', value: 4 },
      { field: 'reject_rate', operator: '>', value: 0.80 },
    ]
  }, { seed_to_believe_median: 2, reject_rate: 0.9 }), true);

  assert('any_of no match', evalThreshold({
    any_of: [
      { field: 'seed_to_believe_median', operator: '>', value: 4 },
      { field: 'reject_rate', operator: '>', value: 0.80 },
    ]
  }, { seed_to_believe_median: 2, reject_rate: 0.5 }), false);

  // all_of
  assert('all_of both match', evalThreshold({
    all_of: [
      { field: 'mean_neg_delta', operator: '>', value: 6 },
      { field: 'neg_events_per_day', operator: '>', value: 1.0 },
    ]
  }, { mean_neg_delta: 8, neg_events_per_day: 1.5 }), true);

  assert('all_of one fails', evalThreshold({
    all_of: [
      { field: 'mean_neg_delta', operator: '>', value: 6 },
      { field: 'neg_events_per_day', operator: '>', value: 1.0 },
    ]
  }, { mean_neg_delta: 8, neg_events_per_day: 0.8 }), false);

  assert('all_of neither match', evalThreshold({
    all_of: [
      { field: 'mean_neg_delta', operator: '>', value: 6 },
      { field: 'neg_events_per_day', operator: '>', value: 1.0 },
    ]
  }, { mean_neg_delta: 4, neg_events_per_day: 0.5 }), false);

  // null field in compound
  assert('any_of null field', evalThreshold({
    any_of: [{ field: 'seed_to_believe_median', operator: '>', value: 4 }]
  }, { seed_to_believe_median: null }), false);

  // array value (GEN-COMP style)
  assert('array empty → false', evalThreshold(
    { any_of: [{ field: 'completion_rate', operator: '<', value: 0.25 }] },
    []
  ), false);
  assert('array with matching element → true', evalThreshold(
    { any_of: [{ field: 'completion_rate', operator: '<', value: 0.25 }] },
    [{ completion_rate: 0.20 }]
  ), true);
  assert('array no matching element → false', evalThreshold(
    { any_of: [{ field: 'completion_rate', operator: '<', value: 0.25 }] },
    [{ completion_rate: 0.50 }]
  ), false);

  process.stderr.write(`\n${passed} passed, ${failed} failed\n`);
  return failed;
}

// ── Trigger registry ─────────────────────────────────────────────────────────
// Maps trigger IDs to their compute functions. Each returns { value, sample, details }.

function buildRegistry(sessions) {
  return {
    '2-A': () => computeNpcFailRatio(sessions, 'scenario_2', '/maren/i'),
    '2-B': () => computeNpcFailRatio(sessions, 'scenario_2', '/maren/i'),
    '2-C': () => computeMaxDayConcentration(sessions, 'scenario_2'),
    '2-D': () => computeSeedToBelieve(sessions, 'scenario_2'),
    '3-A': () => computeCalderDay15(sessions),
    '3-B': () => computeS3MidQuit(sessions),
    '3-C': () => computeRivalDisruption(sessions),
    '3-D': () => computeSpymasterCompletion(sessions, 'scenario_3'),
    '4-A': () => computeNpcFailRatio(sessions, 'scenario_4', '/finn/i'),
    '4-B': () => computeNpcFailRatio(sessions, 'scenario_4', '/finn/i'),
    'X-A': () => computeSpymasterCompletion(sessions, null),
    'GEN-WALL': () => computeMaxDayConcentration(sessions, null),
    'GEN-COMP': () => computeCompletionRate(sessions),
  };
}

// ── Spec loader (minimal YAML subset) ────────────────────────────────────────
// Parses the trigger list from the phase1 watchlist YAML without any external
// dependency. Handles simple thresholds (operator/value) and compound blocks
// (any_of / all_of with per-condition field/operator/value entries).
//
// Expected indentation (spaces only, matching the spec file):
//   2  - id: "X"          ← trigger list item
//   4    name: "..."      ← trigger-level key:value
//   4    threshold:       ← bare block header
//   6      operator: "<"  ← simple threshold
//   6      any_of:        ← compound block header
//   8        - field: "f" ← compound condition list item
//  10          operator:  ← condition field
//   4    min_sample:      ← bare block header
//   6      min: 30        ← min_sample value

function parseSpecYaml(yamlText) {
  const triggers = [];
  const lines = yamlText.split('\n');
  let cur = null;
  // state: 'top' | 'threshold' | 'threshold_compound' | 'min_sample' | 'other_block'
  let state = 'top';
  let compoundKey = null;   // 'any_of' | 'all_of'
  let compoundItem = null;  // current { field, operator, value } being built

  for (const line of lines) {
    const indent = line.search(/\S/); // index of first non-space char
    if (indent === -1) continue;       // blank line
    const content = line.trim();
    if (content.startsWith('#')) continue; // comment

    // New trigger list item: exactly 2-space indent + "- id: ..."
    const triggerMatch = line.match(/^  - id:\s*"?([^"#]+?)"?\s*$/);
    if (triggerMatch) {
      if (cur) triggers.push(cur);
      cur = { id: triggerMatch[1].trim(), threshold: {}, _min_sample: 0, raw: {} };
      state = 'top'; compoundKey = null; compoundItem = null;
      continue;
    }
    if (!cur) continue;

    // 4-space bare block header (key followed only by ":" and optional whitespace)
    if (indent === 4 && /^\w+:\s*$/.test(content)) {
      const key = content.replace(/:.*/, '');
      if (key === 'threshold') {
        state = 'threshold'; compoundKey = null; compoundItem = null;
      } else if (key === 'min_sample') {
        state = 'min_sample';
      } else {
        state = 'other_block';
      }
      continue;
    }

    // 4-space key: value — resets state to top so subsequent 6-space lines
    // (from aggregation block scalars, etc.) don't leak into threshold parsing.
    if (indent === 4) {
      const kv = line.match(/^\s{4}(\w+):\s*(.+)$/);
      if (kv) {
        let val = kv[2].trim();
        if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
        cur.raw[kv[1]] = val;
        state = 'top';
        continue;
      }
    }

    // Inside simple/compound threshold block (6-space indent)
    if (state === 'threshold' && indent === 6) {
      if (/^(any_of|all_of):\s*$/.test(content)) {
        compoundKey = content.replace(/:.*/, '');
        cur.threshold[compoundKey] = [];
        state = 'threshold_compound';
        continue;
      }
      const op = content.match(/^operator:\s*"?([^"#]+?)"?\s*$/);
      if (op) { cur.threshold.operator = op[1].trim(); continue; }
      const val = content.match(/^value:\s*([0-9.]+)\s*$/);
      if (val) { cur.threshold.value = parseFloat(val[1]); continue; }
    }

    // Inside compound condition list (8-space list items, 10-space item fields)
    if (state === 'threshold_compound') {
      if (indent === 8 && content.startsWith('- ')) {
        const fm = content.match(/^- field:\s*"?([^"#]+?)"?\s*$/);
        if (fm) {
          compoundItem = { field: fm[1].trim() };
          cur.threshold[compoundKey].push(compoundItem);
        }
        continue;
      }
      if (indent === 10 && compoundItem) {
        const op = content.match(/^operator:\s*"?([^"#]+?)"?\s*$/);
        if (op) { compoundItem.operator = op[1].trim(); continue; }
        const val = content.match(/^value:\s*([0-9.]+)\s*$/);
        if (val) { compoundItem.value = parseFloat(val[1]); continue; }
        // 'context:' lines are informational — skip
      }
    }

    // Inside min_sample block (6-space indent)
    if (state === 'min_sample' && indent === 6) {
      const min = content.match(/^min:\s*(\d+)\s*$/);
      if (min) { cur._min_sample = parseInt(min[1], 10); continue; }
    }
  }
  if (cur) triggers.push(cur);

  return triggers.map(t => ({
    id: t.id,
    name: t.raw.name || t.id,
    metric: t.raw.metric || null,
    min_sample: t._min_sample || 0,
    threshold: t.threshold,
  }));
}

// ── Consecutive-cycle state ──────────────────────────────────────────────────

function loadState(statePath) {
  if (!statePath) return {};
  try {
    return JSON.parse(fs.readFileSync(statePath, 'utf8'));
  } catch {
    return {};
  }
}

function saveState(statePath, state) {
  if (!statePath) return;
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n');
}

// ── Main ─────────────────────────────────────────────────────────────────────

function main() {
  const argv = process.argv.slice(2);

  // Self-test mode: validate evalThreshold without loading any fixtures
  if (argv[0] === '--test') {
    process.exit(runSelfTests() > 0 ? 1 : 0);
  }

  let statePath = null;
  let pretty = false;
  const files = [];

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--state' && argv[i + 1]) { statePath = argv[++i]; continue; }
    if (argv[i] === '--pretty') { pretty = true; continue; }
    files.push(argv[i]);
  }

  if (!files.length) {
    process.stderr.write(
      'Usage: node tools/balance/trigger_detector.js [--state state.json] [--pretty] <file.ndjson> [...]\n'
    );
    process.exit(2);
  }

  const specPath = path.resolve(__dirname, '../../docs/phase1-balance-watchlist.spec.yaml');
  if (!fs.existsSync(specPath)) {
    process.stderr.write(`Spec not found: ${specPath}\n`);
    process.exit(2);
  }

  const specTriggers = parseSpecYaml(fs.readFileSync(specPath, 'utf8'));
  const events = loadEvents(files);
  const sessions = groupSessions(events);
  const registry = buildRegistry(sessions);
  const state = loadState(statePath);
  const now = new Date().toISOString();

  const results = [];
  let anyFired = false;

  for (const spec of specTriggers) {
    const compute = registry[spec.id];
    if (!compute) {
      results.push({
        id: spec.id,
        name: spec.name,
        status: 'unimplemented',
        message: `No compute function registered for trigger ${spec.id}`,
      });
      continue;
    }

    const { value, sample, details } = compute();
    const sampleMet = sample >= spec.min_sample;
    const thresholdMet = evalThreshold(spec.threshold, value);

    // Consecutive-cycle tracking
    const stateKey = spec.id;
    const prev = state[stateKey] || { consecutiveHits: 0, lastEval: null };
    const hit = sampleMet && thresholdMet;
    const consecutiveHits = hit ? prev.consecutiveHits + 1 : 0;
    const fired = consecutiveHits >= 2;

    state[stateKey] = { consecutiveHits, lastEval: now };

    if (fired) anyFired = true;

    results.push({
      id: spec.id,
      name: spec.name,
      status: fired ? 'FIRED' : hit ? 'WATCHING' : sampleMet ? 'OK' : 'INSUFFICIENT_DATA',
      metric: spec.metric,
      value,
      threshold: spec.threshold.operator
        ? `${spec.threshold.operator} ${spec.threshold.value}`
        : (spec.threshold.any_of ? 'any_of' : spec.threshold.all_of ? 'all_of' : 'compound'),
      sample,
      min_sample: spec.min_sample,
      sample_met: sampleMet,
      threshold_met: thresholdMet,
      consecutive_hits: consecutiveHits,
      fired,
      details,
      evaluated_at: now,
    });
  }

  saveState(statePath, state);

  const output = {
    generated: now,
    input: { files: files.length, sessions: sessions.length, events: events.length },
    summary: {
      total: results.length,
      fired: results.filter(r => r.fired).length,
      watching: results.filter(r => r.status === 'WATCHING').length,
      ok: results.filter(r => r.status === 'OK').length,
      insufficient_data: results.filter(r => r.status === 'INSUFFICIENT_DATA').length,
    },
    triggers: results,
  };

  process.stdout.write(JSON.stringify(output, null, pretty ? 2 : 0) + '\n');
  process.exit(anyFired ? 1 : 0);
}

main();
