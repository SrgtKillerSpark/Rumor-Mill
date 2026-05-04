#!/usr/bin/env node
/**
 * kpi_aggregate.js — Rumor Mill telemetry KPI aggregation
 *
 * Usage:
 *   node tools/analytics/kpi_aggregate.js <file.ndjson> [file2.ndjson ...]
 *   node tools/analytics/kpi_aggregate.js tools/analytics/fixtures/*.ndjson
 *
 * Output: Markdown digest to stdout covering all 12 KPIs and a Red Flags
 * section keyed to the thresholds in docs/post-launch-telemetry-plan.md
 * (SPA-1140).
 *
 * KPI 11 aggregates tutorial_step_completed events (wired in SPA-1553).
 * KPI 12 aggregates settings_changed events (wired in SPA-1553).
 *
 * No external dependencies — stdlib only.
 */

'use strict';

const fs = require('fs');

// ── Statistics helpers ────────────────────────────────────────────────────────

function median(arr) {
  if (!arr.length) return null;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

function percentile(arr, p) {
  if (!arr.length) return null;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.max(0, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[idx];
}

function fmtSec(sec) {
  if (sec == null) return 'N/A';
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return `${m}m ${s}s`;
}

// ── Scenario ID normalisation ────────────────────────────────────────────────
//
// Fixtures emit both short ("S2") and long ("scenario_2") formats.
// Normalise to the short uppercase form ("S2") at load time so all downstream
// regex patterns, dictionary lookups, and watchlist filters match consistently.

function normaliseScenarioId(id) {
  if (id == null) return id;
  const s = String(id);
  const m = s.match(/^scenario[_\s-]?(\d+)$/i);
  if (m) return `S${m[1]}`;
  return s;
}

// ── Event loading ─────────────────────────────────────────────────────────────

function loadFiles(filePaths) {
  const events = [];
  for (const fp of filePaths) {
    const raw = fs.readFileSync(fp, 'utf8');
    const lines = raw.split('\n').filter(l => l.trim());
    for (const line of lines) {
      try {
        const ev = JSON.parse(line);
        ev._source = fp;
        if (ev.scenario_id != null) ev.scenario_id = normaliseScenarioId(ev.scenario_id);
        events.push(ev);
      } catch {
        // skip malformed lines silently
      }
    }
  }
  return events;
}

// ── Session grouping ──────────────────────────────────────────────────────────
//
// Each analytics file represents one player. A session begins at each
// `scenario_selected` event and ends at `scenario_ended`. A file may
// contain multiple back-to-back sessions.

function groupSessions(events) {
  const byFile = {};
  for (const ev of events) {
    if (!byFile[ev._source]) byFile[ev._source] = [];
    byFile[ev._source].push(ev);
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
          duration_sec: null,
        };
      } else if (cur) {
        cur.events.push(ev);
        if (ev.type === 'scenario_ended') {
          cur.ended = true;
          cur.outcome = ev.outcome;
          cur.day_reached = ev.day_reached;
          cur.duration_sec = ev.duration_sec;
          if (ev.scenario_id) cur.scenario_id = ev.scenario_id;
          sessions.push(cur);
          cur = null;
        }
      }
    }
    if (cur) sessions.push(cur); // incomplete/open session
  }

  return sessions;
}

// ── KPI 1: Per-Scenario Completion Rate ───────────────────────────────────────

function kpi1(sessions) {
  const map = {};
  for (const s of sessions) {
    const key = `${s.scenario_id}|${s.difficulty}`;
    if (!map[key]) map[key] = { scenario_id: s.scenario_id, difficulty: s.difficulty, selected: 0, won: 0 };
    map[key].selected++;
    if (s.outcome === 'WON') map[key].won++;
  }
  return Object.values(map).sort(
    (a, b) => a.scenario_id.localeCompare(b.scenario_id) || a.difficulty.localeCompare(b.difficulty)
  );
}

// ── KPI 2: Day-of-Quit Histogram ──────────────────────────────────────────────

function kpi2(sessions) {
  const byScen = {};
  for (const s of sessions) {
    if (s.outcome !== 'FAILED' || s.day_reached == null) continue;
    if (!byScen[s.scenario_id]) byScen[s.scenario_id] = {};
    const d = String(s.day_reached);
    byScen[s.scenario_id][d] = (byScen[s.scenario_id][d] || 0) + 1;
  }
  return byScen;
}

// ── KPI 3: Session Duration by Outcome ────────────────────────────────────────

function kpi3(sessions) {
  const map = {};
  for (const s of sessions) {
    if (!s.ended || s.duration_sec == null) continue;
    const key = `${s.scenario_id}|${s.outcome}`;
    if (!map[key]) map[key] = { scenario_id: s.scenario_id, outcome: s.outcome, durations: [] };
    map[key].durations.push(s.duration_sec);
  }
  const result = {};
  for (const [k, v] of Object.entries(map)) {
    result[k] = {
      scenario_id: v.scenario_id,
      outcome: v.outcome,
      count: v.durations.length,
      med: median(v.durations),
      p90: percentile(v.durations, 90),
    };
  }
  return result;
}

// ── KPI 4: Rumor Seed-to-First-Believer Time ──────────────────────────────────
//
// Matches rumor_seeded.claim_id → npc_state_changed.rumor_id (same value in
// the logger — claim_id is the rumor identifier used in both events).

function kpi4(sessions) {
  const byScen = {};
  for (const s of sessions) {
    const seeds = {};      // claim_id -> seed day
    const believes = {};   // rumor_id -> [days of BELIEVE transitions]

    for (const ev of s.events) {
      if (ev.type === 'rumor_seeded' && ev.claim_id != null) {
        if (!(ev.claim_id in seeds)) seeds[ev.claim_id] = ev.day;
      } else if (ev.type === 'npc_state_changed' && ev.new_state === 'BELIEVE') {
        if (!believes[ev.rumor_id]) believes[ev.rumor_id] = [];
        believes[ev.rumor_id].push(ev.day);
      }
    }

    for (const [claimId, seedDay] of Object.entries(seeds)) {
      if (!believes[claimId]) continue;
      const firstBelieve = Math.min(...believes[claimId]);
      const gap = firstBelieve - seedDay;
      if (!byScen[s.scenario_id]) byScen[s.scenario_id] = [];
      byScen[s.scenario_id].push(gap);
    }
  }

  const result = {};
  for (const [scen, gaps] of Object.entries(byScen)) {
    result[scen] = { med: median(gaps), count: gaps.length };
  }
  return result;
}

// ── KPI 5: Rumor Adoption Funnel ──────────────────────────────────────────────
//
// Counts unique NPCs reaching each state per (scenario, rumor).
// REJECT is counted independently (an NPC can reject before or instead of believing).

function kpi5(events) {
  // Per (scenario_id, rumor_id): track which states each NPC reached
  const byRumor = {};
  for (const ev of events) {
    if (ev.type !== 'npc_state_changed') continue;
    const key = `${ev.scenario_id}|${ev.rumor_id}`;
    if (!byRumor[key]) byRumor[key] = { scenario_id: ev.scenario_id, npcStates: {} };
    if (!byRumor[key].npcStates[ev.npc_name]) byRumor[key].npcStates[ev.npc_name] = new Set();
    byRumor[key].npcStates[ev.npc_name].add(ev.new_state);
  }

  const byScen = {};
  for (const v of Object.values(byRumor)) {
    const s = v.scenario_id;
    if (!byScen[s]) byScen[s] = { believe: 0, spread: 0, act: 0, reject: 0 };
    for (const states of Object.values(v.npcStates)) {
      if (states.has('BELIEVE')) byScen[s].believe++;
      if (states.has('SPREAD'))  byScen[s].spread++;
      if (states.has('ACT'))     byScen[s].act++;
      if (states.has('REJECT'))  byScen[s].reject++;
    }
  }
  return byScen;
}

// ── KPI 6: Recon Action Rate per Day ─────────────────────────────────────────

function kpi6(sessions) {
  const byScen = {};
  for (const s of sessions) {
    if (!s.ended) continue;
    const byDay = {};
    for (const ev of s.events) {
      if (ev.type !== 'evidence_interaction') continue;
      byDay[ev.day] = (byDay[ev.day] || 0) + 1;
    }
    const dayCount = Object.keys(byDay).length;
    if (!dayCount) continue;
    const total = Object.values(byDay).reduce((a, b) => a + b, 0);
    if (!byScen[s.scenario_id]) byScen[s.scenario_id] = [];
    byScen[s.scenario_id].push(total / dayCount);
  }

  const result = {};
  for (const [scen, rates] of Object.entries(byScen)) {
    const avg = rates.reduce((a, b) => a + b, 0) / rates.length;
    result[scen] = { avg, sessions: rates.length };
  }
  return result;
}

// ── KPI 7: Recon Success Rate ─────────────────────────────────────────────────

function kpi7(events) {
  const map = {};
  for (const ev of events) {
    if (ev.type !== 'evidence_interaction') continue;
    const key = `${ev.scenario_id}|${ev.action_type}`;
    if (!map[key]) map[key] = { scenario_id: ev.scenario_id, action_type: ev.action_type, total: 0, success: 0 };
    map[key].total++;
    if (ev.success) map[key].success++;
  }
  return Object.values(map).sort(
    (a, b) => a.scenario_id.localeCompare(b.scenario_id) || a.action_type.localeCompare(b.action_type)
  );
}

// ── KPI 8: Reputation Volatility Index ────────────────────────────────────────

function kpi8(sessions) {
  const byScen = {};
  for (const s of sessions) {
    if (!s.ended) continue;
    const deltas = s.events
      .filter(e => e.type === 'reputation_delta')
      .map(e => Math.abs(e.delta));
    if (!deltas.length) continue;
    const meanAbs = deltas.reduce((a, b) => a + b, 0) / deltas.length;
    if (!byScen[s.scenario_id]) byScen[s.scenario_id] = { shifts: [], meanAbsDeltas: [] };
    byScen[s.scenario_id].shifts.push(deltas.length);
    byScen[s.scenario_id].meanAbsDeltas.push(meanAbs);
  }

  const result = {};
  for (const [scen, v] of Object.entries(byScen)) {
    result[scen] = {
      avgShifts: v.shifts.reduce((a, b) => a + b, 0) / v.shifts.length,
      avgMeanAbs: v.meanAbsDeltas.reduce((a, b) => a + b, 0) / v.meanAbsDeltas.length,
    };
  }
  return result;
}

// ── KPI 9: Scenario Attempt Sequence ─────────────────────────────────────────

function scenarioNumber(id) {
  // Accept "S1", "scenario_1", "1", etc.
  const m = String(id).match(/(\d+)/);
  return m ? parseInt(m[1], 10) : 0;
}

function kpi9(sessions) {
  const byFile = {};
  for (const s of sessions) {
    if (!byFile[s.file]) byFile[s.file] = [];
    byFile[s.file].push(s.scenario_id);
  }

  let maxRetries = 0;
  let maxRetriesScen = null;
  let filesReachingS3Plus = 0;

  for (const [, seq] of Object.entries(byFile)) {
    if (seq.some(id => scenarioNumber(id) >= 3)) filesReachingS3Plus++;

    let i = 0;
    while (i < seq.length) {
      const scen = seq[i];
      let run = 0;
      while (i < seq.length && seq[i] === scen) { run++; i++; }
      if (run > maxRetries) { maxRetries = run; maxRetriesScen = scen; }
    }
  }

  return {
    totalFiles: Object.keys(byFile).length,
    filesReachingS3Plus,
    maxRetries,
    maxRetriesScen,
  };
}

// ── KPI 10: Difficulty Distribution ──────────────────────────────────────────

function kpi10(sessions) {
  const byScen = {};
  for (const s of sessions) {
    if (!byScen[s.scenario_id]) byScen[s.scenario_id] = {};
    byScen[s.scenario_id][s.difficulty] = (byScen[s.scenario_id][s.difficulty] || 0) + 1;
  }

  const result = {};
  for (const [scen, diffs] of Object.entries(byScen)) {
    const total = Object.values(diffs).reduce((a, b) => a + b, 0);
    result[scen] = { _total: total };
    for (const [diff, count] of Object.entries(diffs)) {
      result[scen][diff] = { count, pct: (count / total * 100).toFixed(1) };
    }
  }
  return result;
}

// ── KPI 11: Tutorial Step Abandonment ────────────────────────────────────────
//
// Groups tutorial_step_completed events by scenario_id and step_id.
// Drop-off rate = (completions[step N-1] - completions[step N]) / completions[step N-1]

function stepNumber(id) {
  const m = String(id).match(/(\d+)/);
  return m ? parseInt(m[1], 10) : 0;
}

function kpi11(events) {
  const byScen = {};
  for (const ev of events) {
    if (ev.type !== 'tutorial_step_completed') continue;
    const scen = String(ev.scenario_id || 'unknown');
    if (!byScen[scen]) byScen[scen] = {};
    const step = String(ev.step_id);
    byScen[scen][step] = (byScen[scen][step] || 0) + 1;
  }

  const result = {};
  for (const [scen, stepCounts] of Object.entries(byScen)) {
    const steps = Object.keys(stepCounts).sort((a, b) => stepNumber(a) - stepNumber(b));
    const rows = [];
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const count = stepCounts[step];
      const prevCount = i > 0 ? stepCounts[steps[i - 1]] : count;
      const dropOff = i > 0 && prevCount > 0 ? (prevCount - count) / prevCount * 100 : null;
      rows.push({ step, count, dropOff });
    }
    result[scen] = rows;
  }
  return result;
}

// ── KPI 12: Settings-Touched Percentage ──────────────────────────────────────
//
// Counts scenario sessions containing at least one settings_changed event.
// Also tallies how many times each setting_key was changed.

function kpi12(sessions) {
  let touchedSessions = 0;
  const bySetting = {};
  for (const s of sessions) {
    let touched = false;
    for (const ev of s.events) {
      if (ev.type !== 'settings_changed') continue;
      touched = true;
      const key = String(ev.setting_key || 'unknown');
      bySetting[key] = (bySetting[key] || 0) + 1;
    }
    if (touched) touchedSessions++;
  }
  return {
    totalSessions: sessions.length,
    touchedSessions,
    pct: sessions.length > 0 ? touchedSessions / sessions.length * 100 : 0,
    bySetting,
  };
}

// ── Evidence Acquired Aggregation ────────────────────────────────────────────
//
// Processes `evidence_acquired` events (SPA-1530).
// Returns:
//   counts     – acquisition count per evidence_type × scenario_id × difficulty
//   dayHist    – histogram of day per evidence_type
//   sourceRatio – source_action breakdown per evidence_type

function evidenceAcquiredAgg(events) {
  const acqMap = {};
  const dayHistMap = {};
  const sourceMap = {};

  for (const ev of events) {
    if (ev.type !== 'evidence_acquired') continue;
    const t   = String(ev.evidence_type  || 'unknown');
    const s   = String(ev.scenario_id    || 'unknown');
    const d   = String(ev.difficulty     || 'unknown');
    const key = `${t}|${s}|${d}`;

    if (!acqMap[key]) acqMap[key] = { evidence_type: t, scenario_id: s, difficulty: d, count: 0 };
    acqMap[key].count++;

    if (!dayHistMap[t]) dayHistMap[t] = {};
    const day = String(ev.day ?? 'unknown');
    dayHistMap[t][day] = (dayHistMap[t][day] || 0) + 1;

    if (!sourceMap[t]) sourceMap[t] = {};
    const src = String(ev.source_action || 'unknown');
    sourceMap[t][src] = (sourceMap[t][src] || 0) + 1;
  }

  return {
    counts: Object.values(acqMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) ||
                a.scenario_id.localeCompare(b.scenario_id)     ||
                a.difficulty.localeCompare(b.difficulty)
    ),
    dayHist: dayHistMap,
    sourceRatio: sourceMap,
  };
}

// ── Evidence Used Aggregation ─────────────────────────────────────────────────
//
// Processes `evidence_used` events (SPA-1530).
// Returns:
//   counts        – usage count per evidence_type × scenario_id × difficulty
//   claimCrossTab – evidence_type × claim_id cross-tab
//   targetCrossTab– evidence_type × seed_target cross-tab
//   dayHist       – histogram of day per evidence_type
//   acqToUseRatio – COUNT(used) / COUNT(acquired) per type

function evidenceUsedAgg(events, acqResult) {
  const usedMap    = {};
  const claimMap   = {};
  const targetMap  = {};
  const dayHistMap = {};
  const usedCountByType = {};

  for (const ev of events) {
    if (ev.type !== 'evidence_used') continue;
    const t   = String(ev.evidence_type  || 'unknown');
    const s   = String(ev.scenario_id    || 'unknown');
    const d   = String(ev.difficulty     || 'unknown');
    const key = `${t}|${s}|${d}`;

    if (!usedMap[key]) usedMap[key] = { evidence_type: t, scenario_id: s, difficulty: d, count: 0 };
    usedMap[key].count++;

    const claimId  = String(ev.claim_id    || 'unknown');
    const claimKey = `${t}|${claimId}`;
    if (!claimMap[claimKey]) claimMap[claimKey] = { evidence_type: t, claim_id: claimId, count: 0 };
    claimMap[claimKey].count++;

    const target    = String(ev.seed_target || 'unknown');
    const targetKey = `${t}|${target}`;
    if (!targetMap[targetKey]) targetMap[targetKey] = { evidence_type: t, seed_target: target, count: 0 };
    targetMap[targetKey].count++;

    if (!dayHistMap[t]) dayHistMap[t] = {};
    const day = String(ev.day ?? 'unknown');
    dayHistMap[t][day] = (dayHistMap[t][day] || 0) + 1;

    usedCountByType[t] = (usedCountByType[t] || 0) + 1;
  }

  // Build per-type acquisition totals from already-computed acqResult
  const acqCountByType = {};
  for (const row of acqResult.counts) {
    acqCountByType[row.evidence_type] = (acqCountByType[row.evidence_type] || 0) + row.count;
  }

  const acqToUseRatio = {};
  const allTypes = new Set([...Object.keys(acqCountByType), ...Object.keys(usedCountByType)]);
  for (const t of allTypes) {
    const acq  = acqCountByType[t]  || 0;
    const used = usedCountByType[t] || 0;
    acqToUseRatio[t] = { acquired: acq, used, ratio: acq > 0 ? used / acq : null };
  }

  return {
    counts: Object.values(usedMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) ||
                a.scenario_id.localeCompare(b.scenario_id)     ||
                a.difficulty.localeCompare(b.difficulty)
    ),
    claimCrossTab: Object.values(claimMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) || a.claim_id.localeCompare(b.claim_id)
    ),
    targetCrossTab: Object.values(targetMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) || a.seed_target.localeCompare(b.seed_target)
    ),
    dayHist: dayHistMap,
    acqToUseRatio,
  };
}

// ── Phase 2: Evidence Decay Tick Aggregation ─────────────────────────────────
//
// Processes `evidence_decay_tick` events (SPA-1574).
// Returns:
//   ticksPerType   – count of decay ticks per evidence_type × scenario_id
//   avgDecayRate   – mean (prev_confidence - new_confidence) per type
//   dayDistribution – histogram of day when decay ticks fire per type

function evidenceDecayTickAgg(events) {
  const tickMap = {};
  const decayRates = {};
  const dayHistMap = {};

  for (const ev of events) {
    if (ev.type !== 'evidence_decay_tick') continue;
    const t   = String(ev.evidence_type || 'unknown');
    const s   = String(ev.scenario_id   || 'unknown');
    const key = `${t}|${s}`;

    if (!tickMap[key]) tickMap[key] = { evidence_type: t, scenario_id: s, count: 0 };
    tickMap[key].count++;

    if (!decayRates[t]) decayRates[t] = [];
    const rate = (ev.prev_confidence || 0) - (ev.new_confidence || 0);
    decayRates[t].push(rate);

    if (!dayHistMap[t]) dayHistMap[t] = {};
    const day = String(ev.day ?? 'unknown');
    dayHistMap[t][day] = (dayHistMap[t][day] || 0) + 1;
  }

  const avgDecayRate = {};
  for (const [t, rates] of Object.entries(decayRates)) {
    avgDecayRate[t] = rates.reduce((a, b) => a + b, 0) / rates.length;
  }

  return {
    ticksPerType: Object.values(tickMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) || a.scenario_id.localeCompare(b.scenario_id)
    ),
    avgDecayRate,
    dayDistribution: dayHistMap,
  };
}

// ── Phase 2: Evidence Threshold Cross Aggregation ────────────────────────────
//
// Processes `evidence_threshold_cross` events (SPA-1574).
// Returns:
//   crossings    – count per evidence_type × direction × scenario_id
//   thresholdHit – count per threshold value (which tier boundaries are crossed most)

function evidenceThresholdCrossAgg(events) {
  const crossMap = {};
  const thresholdHit = {};

  for (const ev of events) {
    if (ev.type !== 'evidence_threshold_cross') continue;
    const t   = String(ev.evidence_type || 'unknown');
    const dir = String(ev.direction     || 'unknown');
    const s   = String(ev.scenario_id   || 'unknown');
    const key = `${t}|${dir}|${s}`;

    if (!crossMap[key]) crossMap[key] = { evidence_type: t, direction: dir, scenario_id: s, count: 0 };
    crossMap[key].count++;

    const thresh = String(ev.threshold ?? 'unknown');
    thresholdHit[thresh] = (thresholdHit[thresh] || 0) + 1;
  }

  return {
    crossings: Object.values(crossMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) ||
                a.direction.localeCompare(b.direction) ||
                a.scenario_id.localeCompare(b.scenario_id)
    ),
    thresholdHit,
  };
}

// ── Phase 2: Evidence Target Shift Aggregation ───────────────────────────────
//
// Processes `evidence_target_shift` events (SPA-1574).
// Returns:
//   shifts       – count per evidence_type × scenario_id
//   flowPairs    – count per (from_target → to_target) pair

function evidenceTargetShiftAgg(events) {
  const shiftMap = {};
  const flowMap  = {};

  for (const ev of events) {
    if (ev.type !== 'evidence_target_shift') continue;
    const t   = String(ev.evidence_type || 'unknown');
    const s   = String(ev.scenario_id   || 'unknown');
    const key = `${t}|${s}`;

    if (!shiftMap[key]) shiftMap[key] = { evidence_type: t, scenario_id: s, count: 0 };
    shiftMap[key].count++;

    const from = String(ev.from_target || 'unknown');
    const to   = String(ev.to_target   || 'unknown');
    const flowKey = `${from}→${to}`;
    if (!flowMap[flowKey]) flowMap[flowKey] = { from_target: from, to_target: to, count: 0 };
    flowMap[flowKey].count++;
  }

  return {
    shifts: Object.values(shiftMap).sort(
      (a, b) => a.evidence_type.localeCompare(b.evidence_type) || a.scenario_id.localeCompare(b.scenario_id)
    ),
    flowPairs: Object.values(flowMap).sort((a, b) => b.count - a.count),
  };
}

// ── Watchlist: Maren-fail ratio (2-A / 2-B) ──────────────────────────────────
//
// A "Maren-fail" is an S2 FAILED session where Sister Maren caused the loss.
// Primary: scenario_fail_trigger.trigger_npc_id === 'npc_maren_nun' (direct attribution).
// Fallback: npc_state_changed REJECT on a Maren NPC (indirect, for pre-SPA-1454 data).

function wlMarenFail(sessions) {
  const s2Failed = sessions.filter(
    s => /^s2$/i.test(String(s.scenario_id)) && s.outcome === 'FAILED'
  );
  const marenFails = s2Failed.filter(s => {
    // Prefer direct attribution via scenario_fail_trigger
    if (s.events.some(ev => ev.type === 'scenario_fail_trigger' && ev.trigger_npc_id === 'npc_maren_nun'))
      return true;
    // Fallback: indirect correlation via npc_state_changed REJECT
    return s.events.some(
      ev => ev.type === 'npc_state_changed' &&
            /maren/i.test(ev.npc_name) &&
            ev.new_state === 'REJECT'
    );
  });
  return {
    total: s2Failed.length,
    marenFails: marenFails.length,
    ratio: s2Failed.length ? marenFails.length / s2Failed.length * 100 : null,
  };
}

// ── Watchlist: Calder day-15 reputation reconstruction (3-A) ─────────────────
//
// Primary: reputation_snapshot events on npc_id matching /calder/i at day ≤ 15.
// Emitted losslessly once per day per NPC (SPA-1417); uses the latest snapshot
// at or before day 15.
// Fallback: accumulate reputation_delta (lossy — only fires when |delta| ≥ 3).

function wlCalderDay15(sessions) {
  const s3Won = sessions.filter(
    s => /^s3$/i.test(String(s.scenario_id)) && s.outcome === 'WON'
  );
  const reps = [];
  let snapshotSamples = 0;
  for (const s of s3Won) {
    // Prefer lossless reputation_snapshot events
    const calderSnaps = s.events
      .filter(
        ev => ev.type === 'reputation_snapshot' &&
              /calder/i.test(String(ev.npc_id || '')) &&
              (ev.day || 0) <= 15
      )
      .sort((a, b) => (a.day || 0) - (b.day || 0));

    if (calderSnaps.length) {
      const snap = calderSnaps[calderSnaps.length - 1]; // latest at-or-before day 15
      const score = snap.score != null ? snap.score : snap.reputation;
      if (score != null) {
        reps.push(score);
        snapshotSamples++;
        continue;
      }
    }

    // Fallback: reconstruct from reputation_delta (lossy, ≥3pt threshold)
    const calderDeltas = s.events
      .filter(ev => ev.type === 'reputation_delta' && /calder/i.test(String(ev.npc_id || '')))
      .sort((a, b) => (a.day || 0) - (b.day || 0));
    if (!calderDeltas.length) continue;
    if (calderDeltas[0].from_score == null) continue;
    let rep = calderDeltas[0].from_score;
    for (const ev of calderDeltas) {
      if ((ev.day || 0) <= 15) rep += (ev.delta || 0);
    }
    reps.push(rep);
  }
  return {
    wonSessions: s3Won.length,
    samples: reps.length,
    snapshotSamples,
    above65: reps.filter(r => r > 65).length,
    med: reps.length ? median(reps) : null,
  };
}

// ── Watchlist: S3 mid-game disengagement — day 15–19 quits (3-B) ─────────────

function wlS3MidQuit(sessions) {
  const s3Failed = sessions.filter(
    s => /^s3$/i.test(String(s.scenario_id)) && s.outcome === 'FAILED'
  );
  const midQuit = s3Failed.filter(
    s => s.day_reached != null && s.day_reached >= 15 && s.day_reached <= 19
  );
  return {
    total: s3Failed.length,
    midQuit: midQuit.length,
    ratio: s3Failed.length ? midQuit.length / s3Failed.length * 100 : null,
  };
}

// ── Watchlist: per-NPC REJECT → fail correlation ──────────────────────────────
//
// For each NPC, the fraction of ended sessions where they rejected a rumor AND
// the session was FAILED.  High correlation = that NPC's rejection predicts loss.

function wlNpcRejectFail(sessions) {
  const byNpc = {};
  for (const s of sessions) {
    if (!s.ended) continue;
    const rejectingNpcs = new Set(
      s.events
        .filter(ev => ev.type === 'npc_state_changed' && ev.new_state === 'REJECT')
        .map(ev => ev.npc_name)
    );
    for (const npc of rejectingNpcs) {
      if (!byNpc[npc]) byNpc[npc] = { reject: 0, rejectAndFail: 0 };
      byNpc[npc].reject++;
      if (s.outcome === 'FAILED') byNpc[npc].rejectAndFail++;
    }
  }
  return Object.entries(byNpc)
    .map(([npc, v]) => ({
      npc,
      rejectSessions: v.reject,
      failedSessions: v.rejectAndFail,
      correlation: v.reject ? v.rejectAndFail / v.reject * 100 : 0,
    }))
    .sort((a, b) => b.correlation - a.correlation || b.rejectSessions - a.rejectSessions);
}

// ── Red Flags ─────────────────────────────────────────────────────────────────

function redFlags(k1r, k2r, k3r, k4r, k5r, k6r, k7r, k8r, k11r, sessions) {
  const flags = [];

  // KPI 1
  for (const e of k1r) {
    if (!e.selected) continue;
    const rate = e.won / e.selected * 100;
    if (e.difficulty === 'Normal' && rate < 25)
      flags.push(`🚨 **${e.scenario_id} Normal** completion ${rate.toFixed(1)}% < 25% (too hard)`);
    if (e.difficulty === 'Normal' && rate > 85)
      flags.push(`⚠️  **${e.scenario_id} Normal** completion ${rate.toFixed(1)}% > 85% (too easy)`);
  }

  // KPI 2: >40% of failures on a single day
  for (const [scen, hist] of Object.entries(k2r)) {
    const total = Object.values(hist).reduce((a, b) => a + b, 0);
    for (const [day, count] of Object.entries(hist)) {
      if (total && count / total > 0.40)
        flags.push(`🚨 **${scen}** day-${day} concentrates ${(count/total*100).toFixed(0)}% of failures (quit wall)`);
    }
  }

  // KPI 3: rage-quit / slog / trivial
  for (const v of Object.values(k3r)) {
    if (v.outcome === 'WON') {
      if (v.med != null && v.med < 240)
        flags.push(`⚠️  **${v.scenario_id} WON** median ${fmtSec(v.med)} < 4 min (trivial)`);
      if (v.med != null && v.med > 1800)
        flags.push(`⚠️  **${v.scenario_id} WON** median ${fmtSec(v.med)} > 30 min (slog)`);
    }
    if (v.outcome === 'FAILED' && v.med != null && v.med < 60)
      flags.push(`🚨 **${v.scenario_id} FAILED** median ${fmtSec(v.med)} < 1 min (rage-quit)`);
  }

  // KPI 4
  for (const [scen, v] of Object.entries(k4r)) {
    if (v.med > 4)
      flags.push(`⚠️  **${scen}** seed→believer median ${v.med.toFixed(1)} d > 4 (unresponsive)`);
    if (v.med === 0)
      flags.push(`⚠️  **${scen}** seed→believer median 0 d (instant)`);
  }

  // KPI 5
  for (const [scen, v] of Object.entries(k5r)) {
    if (!v.believe) continue;
    const spreadRatio = v.spread / v.believe;
    const rejectTotal = v.reject + v.believe;
    const rejectRate = rejectTotal ? v.reject / rejectTotal : 0;
    if (spreadRatio < 0.20)
      flags.push(`⚠️  **${scen}** SPREAD/BELIEVE ${(spreadRatio*100).toFixed(0)}% < 20% (rumors stall)`);
    if (rejectRate > 0.80)
      flags.push(`🚨 **${scen}** REJECT rate ${(rejectRate*100).toFixed(0)}% > 80% (powerless)`);
  }

  // KPI 6
  for (const [scen, v] of Object.entries(k6r)) {
    if (v.avg < 1)
      flags.push(`⚠️  **${scen}** avg recon/day ${v.avg.toFixed(1)} < 1 (ignoring recon)`);
    if (v.avg > 10)
      flags.push(`⚠️  **${scen}** avg recon/day ${v.avg.toFixed(1)} > 10 (spam-clicking)`);
  }

  // KPI 7
  for (const v of k7r) {
    const rate = v.total ? v.success / v.total * 100 : 0;
    if (rate < 30)
      flags.push(`🚨 **${v.scenario_id} ${v.action_type}** success ${rate.toFixed(1)}% < 30% (mechanic broken)`);
    if (rate > 95)
      flags.push(`⚠️  **${v.scenario_id} ${v.action_type}** success ${rate.toFixed(1)}% > 95% (no tension)`);
  }

  // KPI 8
  for (const [scen, v] of Object.entries(k8r)) {
    if (v.avgShifts > 10)
      flags.push(`⚠️  **${scen}** avg ${v.avgShifts.toFixed(1)} rep-shifts/session > 10 (chaotic)`);
    if (v.avgShifts < 1)
      flags.push(`⚠️  **${scen}** avg ${v.avgShifts.toFixed(1)} rep-shifts/session < 1 (static)`);
  }

  // KPI 11: tutorial step drop-off > 50%
  for (const [scen, rows] of Object.entries(k11r)) {
    for (const row of rows) {
      if (row.dropOff != null && row.dropOff > 50)
        flags.push(`🚨 **${scen} ${row.step}** tutorial drop-off ${row.dropOff.toFixed(0)}% > 50% (abandonment wall)`);
    }
  }

  // Rage-quit rate across all sessions (sessions < 60 s)
  const ended = sessions.filter(s => s.ended && s.duration_sec != null);
  if (ended.length) {
    const rageQuits = ended.filter(s => s.duration_sec < 60).length;
    const rageRate = rageQuits / ended.length * 100;
    if (rageRate > 10)
      flags.push(`🚨 Rage-quit rate (< 60 s) ${rageRate.toFixed(1)}% > 10% across all sessions`);
  }

  return flags;
}

// ── Markdown renderer ─────────────────────────────────────────────────────────

function buildDigest(events, sessions, filePaths) {
  const k1r  = kpi1(sessions);
  const k2r  = kpi2(sessions);
  const k3r  = kpi3(sessions);
  const k4r  = kpi4(sessions);
  const k5r  = kpi5(events);
  const k6r  = kpi6(sessions);
  const k7r  = kpi7(events);
  const k8r  = kpi8(sessions);
  const k9r  = kpi9(sessions);
  const k10r = kpi10(sessions);
  const k11r = kpi11(events);
  const k12r = kpi12(sessions);
  const evAcq  = evidenceAcquiredAgg(events);
  const evUsed = evidenceUsedAgg(events, evAcq);
  const evDecay     = evidenceDecayTickAgg(events);
  const evThreshold = evidenceThresholdCrossAgg(events);
  const evShift     = evidenceTargetShiftAgg(events);
  const flags = redFlags(k1r, k2r, k3r, k4r, k5r, k6r, k7r, k8r, k11r, sessions);
  const wlMaren  = wlMarenFail(sessions);
  const wlCalder = wlCalderDay15(sessions);
  const wlS3Quit = wlS3MidQuit(sessions);
  const wlNpc    = wlNpcRejectFail(sessions);

  const now = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
  const out = [];

  out.push(`# Rumor Mill — Telemetry Digest`);
  out.push(`\n_Generated: ${now}_  `);
  out.push(`_Input: ${filePaths.length} file(s) · ${sessions.length} sessions · ${events.length} events_\n`);
  out.push(`---\n`);

  // KPI 1
  out.push(`## KPI 1 — Per-Scenario Completion Rate\n`);
  out.push(`Healthy (Normal): 40–70% | Flags: < 25% (too hard) · > 85% (too easy)\n`);
  out.push(`| Scenario | Difficulty | Sessions | Won | Rate | Status |`);
  out.push(`|----------|------------|----------|-----|------|--------|`);
  for (const e of k1r) {
    const rate = e.selected ? e.won / e.selected * 100 : 0;
    let status = '';
    if (e.difficulty === 'Normal') {
      if (rate < 25) status = '🚨 too hard';
      else if (rate > 85) status = '⚠️ too easy';
      else if (rate >= 40 && rate <= 70) status = '✅ healthy';
      else status = '⚠️ watch';
    } else {
      status = '—';
    }
    out.push(`| ${e.scenario_id} | ${e.difficulty} | ${e.selected} | ${e.won} | ${rate.toFixed(1)}% | ${status} |`);
  }

  // KPI 2
  out.push(`\n## KPI 2 — Day-of-Quit Histogram\n`);
  out.push(`Flag: any single day > 40% of failures in a scenario\n`);
  for (const [scen, hist] of Object.entries(k2r)) {
    const total = Object.values(hist).reduce((a, b) => a + b, 0);
    out.push(`**${scen}** — ${total} failed session(s)`);
    const days = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
    for (const d of days) {
      const n = hist[d];
      const p = (n / total * 100).toFixed(0);
      const bar = '█'.repeat(Math.max(1, Math.round(n / total * 20)));
      const wall = n / total > 0.40 ? '  🚨 quit wall' : '';
      out.push(`  Day ${d.padEnd(3)} ${bar.padEnd(20)} ${String(p).padStart(3)}% (n=${n})${wall}`);
    }
    out.push('');
  }
  if (!Object.keys(k2r).length) out.push('_No failed sessions in dataset._\n');

  // KPI 3
  out.push(`## KPI 3 — Session Duration by Outcome\n`);
  out.push(`Healthy WON: 8–20 min | Flags: WON < 4 min (trivial), WON > 30 min (slog), FAILED < 1 min (rage-quit)\n`);
  out.push(`| Scenario | Outcome | n | Median | p90 | Status |`);
  out.push(`|----------|---------|---|--------|-----|--------|`);
  for (const v of Object.values(k3r).sort((a, b) => a.scenario_id.localeCompare(b.scenario_id) || a.outcome.localeCompare(b.outcome))) {
    let status = '✅';
    if (v.outcome === 'WON') {
      if (v.med != null && v.med < 240) status = '⚠️ trivial';
      else if (v.med != null && v.med > 1800) status = '⚠️ slog';
    } else if (v.outcome === 'FAILED' && v.med != null && v.med < 60) {
      status = '🚨 rage-quit';
    }
    out.push(`| ${v.scenario_id} | ${v.outcome} | ${v.count} | ${fmtSec(v.med)} | ${fmtSec(v.p90)} | ${status} |`);
  }

  // KPI 4
  out.push(`\n## KPI 4 — Rumor Seed-to-First-Believer Time\n`);
  out.push(`Healthy: 1–3 day gap | Flags: median > 4 d (unresponsive) · median = 0 d (instant)\n`);
  if (Object.keys(k4r).length) {
    out.push(`| Scenario | Median Gap (days) | Samples | Status |`);
    out.push(`|----------|-------------------|---------|--------|`);
    for (const [scen, v] of Object.entries(k4r)) {
      let status = '✅ healthy';
      if (v.med > 4) status = '⚠️ too slow';
      else if (v.med === 0) status = '⚠️ instant';
      out.push(`| ${scen} | ${v.med.toFixed(1)} | ${v.count} | ${status} |`);
    }
  } else {
    out.push(`_No matched seed→believe pairs found (check that claim_id in rumor_seeded matches rumor_id in npc_state_changed)._\n`);
  }

  // KPI 5
  out.push(`\n## KPI 5 — Rumor Adoption Funnel\n`);
  out.push(`Healthy: SPREAD/BELIEVE > 40%, REJECT < 60% | Flags: SPREAD/BELIEVE < 20% · REJECT > 80%\n`);
  out.push(`| Scenario | BELIEVE | SPREAD | SPREAD/BEL | ACT | REJECT | REJ rate | Status |`);
  out.push(`|----------|---------|--------|------------|-----|--------|----------|--------|`);
  for (const [scen, v] of Object.entries(k5r)) {
    const spreadRatio = v.believe ? (v.spread / v.believe * 100).toFixed(0) + '%' : 'N/A';
    const rejTotal = v.reject + v.believe;
    const rejRate  = rejTotal ? (v.reject / rejTotal * 100).toFixed(0) + '%' : 'N/A';
    let status = '✅';
    if (v.believe && v.spread / v.believe < 0.20) status = '⚠️ stalling';
    if (rejTotal && v.reject / rejTotal > 0.80) status = '🚨 rejected';
    out.push(`| ${scen} | ${v.believe} | ${v.spread} | ${spreadRatio} | ${v.act} | ${v.reject} | ${rejRate} | ${status} |`);
  }

  // KPI 6
  out.push(`\n## KPI 6 — Recon Action Rate per Day\n`);
  out.push(`Healthy: 2–6 actions/day | Flags: < 1 (ignoring recon) · > 10 (spam-clicking)\n`);
  out.push(`| Scenario | Avg Actions/Day | Sessions | Status |`);
  out.push(`|----------|-----------------|----------|--------|`);
  for (const [scen, v] of Object.entries(k6r)) {
    let status = '✅ healthy';
    if (v.avg < 1) status = '⚠️ too low';
    else if (v.avg > 10) status = '⚠️ spam';
    out.push(`| ${scen} | ${v.avg.toFixed(1)} | ${v.sessions} | ${status} |`);
  }

  // KPI 7
  out.push(`\n## KPI 7 — Recon Success Rate\n`);
  out.push(`Healthy: 50–80% | Flags: < 30% (broken) · > 95% (no tension)\n`);
  out.push(`| Scenario | Action Type | n | Success | Rate | Status |`);
  out.push(`|----------|-------------|---|---------|------|--------|`);
  for (const v of k7r) {
    const rate = v.total ? v.success / v.total * 100 : 0;
    let status = '✅ healthy';
    if (rate < 30) status = '🚨 broken';
    else if (rate > 95) status = '⚠️ trivial';
    out.push(`| ${v.scenario_id} | ${v.action_type} | ${v.total} | ${v.success} | ${rate.toFixed(1)}% | ${status} |`);
  }

  // KPI 8
  out.push(`\n## KPI 8 — Reputation Volatility Index\n`);
  out.push(`Healthy: 2–5 shifts/session, mean |Δ| 4–8 | Flags: > 10 shifts (chaotic) · < 1 shift (static)\n`);
  out.push(`| Scenario | Avg Shifts/Session | Avg Mean |Δ| | Status |`);
  out.push(`|----------|--------------------|-------------|--------|`);
  for (const [scen, v] of Object.entries(k8r)) {
    let status = '✅ healthy';
    if (v.avgShifts > 10) status = '⚠️ chaotic';
    else if (v.avgShifts < 1) status = '⚠️ static';
    out.push(`| ${scen} | ${v.avgShifts.toFixed(1)} | ${v.avgMeanAbs.toFixed(1)} | ${status} |`);
  }

  // KPI 9
  out.push(`\n## KPI 9 — Scenario Attempt Sequence (Progression)\n`);
  out.push(`Healthy: 1–3 retries per scenario, players reaching S3+ | Flags: > 5 retries (stuck)\n`);
  out.push(`| Metric | Value |`);
  out.push(`|--------|-------|`);
  out.push(`| Total player files | ${k9r.totalFiles} |`);
  out.push(`| Files reaching S3+ | ${k9r.filesReachingS3Plus} / ${k9r.totalFiles} |`);
  out.push(`| Max consecutive retries | ${k9r.maxRetries} (${k9r.maxRetriesScen || 'N/A'}) |`);
  if (k9r.maxRetries > 5)
    out.push(`\n🚨 Retry wall detected on **${k9r.maxRetriesScen}** (${k9r.maxRetries} consecutive attempts)\n`);

  // KPI 10
  out.push(`\n## KPI 10 — Difficulty Distribution\n`);
  out.push(`Healthy: Normal 50–70%, Easy 15–30%, Hard 10–25% | Flag: Easy > 50% (base game too hard)\n`);
  out.push(`| Scenario | Easy | Normal | Hard | Total | Status |`);
  out.push(`|----------|------|--------|------|-------|--------|`);
  for (const [scen, diffs] of Object.entries(k10r)) {
    const easy   = diffs['Easy']   || { pct: '0.0', count: 0 };
    const normal = diffs['Normal'] || { pct: '0.0', count: 0 };
    const hard   = diffs['Hard']   || { pct: '0.0', count: 0 };
    let status = '✅ healthy';
    if (parseFloat(easy.pct) > 50) status = '⚠️ Easy > 50%';
    out.push(`| ${scen} | ${easy.pct}% | ${normal.pct}% | ${hard.pct}% | ${diffs._total} | ${status} |`);
  }

  // KPI 11
  out.push(`\n## KPI 11 — Tutorial Step Abandonment\n`);
  out.push(`Flag: drop-off > 50% between consecutive steps\n`);
  if (!Object.keys(k11r).length) {
    out.push(`_No data — no \`tutorial_step_completed\` events in dataset._\n`);
  } else {
    out.push(`| Scenario | Step | Completions | Drop-off | Status |`);
    out.push(`|----------|------|-------------|----------|--------|`);
    for (const [scen, rows] of Object.entries(k11r).sort()) {
      for (const row of rows) {
        const dropStr = row.dropOff != null ? `${row.dropOff.toFixed(1)}%` : '—';
        let status = '✅';
        if (row.dropOff != null && row.dropOff > 50) status = '🚨 wall';
        else if (row.dropOff != null && row.dropOff > 25) status = '⚠️ high';
        else if (row.dropOff == null) status = '—';
        out.push(`| ${scen} | ${row.step} | ${row.count} | ${dropStr} | ${status} |`);
      }
    }
    out.push('');
  }

  // KPI 12
  out.push(`\n## KPI 12 — Settings-Touched Percentage\n`);
  if (!k12r.totalSessions) {
    out.push(`_No data — no sessions in dataset._\n`);
  } else {
    out.push(`Sessions touching settings: **${k12r.touchedSessions} / ${k12r.totalSessions}** (${k12r.pct.toFixed(1)}%)\n`);
    if (Object.keys(k12r.bySetting).length) {
      out.push(`| Setting Key | Changes |`);
      out.push(`|-------------|---------|`);
      const sorted = Object.entries(k12r.bySetting).sort((a, b) => b[1] - a[1]);
      for (const [key, count] of sorted) {
        out.push(`| ${key} | ${count} |`);
      }
      out.push('');
    } else {
      out.push(`_No \`settings_changed\` events in dataset._\n`);
    }
  }

  // Evidence Acquired
  out.push(`\n## Evidence Acquired\n`);
  out.push(`_New events from [SPA-1530](/SPA/issues/SPA-1530) — acquisition rate, day histogram, source breakdown._\n`);
  if (!evAcq.counts.length) {
    out.push(`_No \`evidence_acquired\` events in dataset._\n`);
  } else {
    out.push(`### Acquisition Rate (per type × scenario × difficulty)\n`);
    out.push(`| Evidence Type | Scenario | Difficulty | Count |`);
    out.push(`|---------------|----------|------------|-------|`);
    for (const row of evAcq.counts) {
      out.push(`| ${row.evidence_type} | ${row.scenario_id} | ${row.difficulty} | ${row.count} |`);
    }

    out.push(`\n### Day Histogram (when items are acquired)\n`);
    for (const [t, hist] of Object.entries(evAcq.dayHist)) {
      out.push(`**${t}**`);
      const days = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
      const total = Object.values(hist).reduce((s, n) => s + n, 0);
      for (const d of days) {
        const n = hist[d];
        const bar = '█'.repeat(Math.max(1, Math.round(n / total * 20)));
        out.push(`  Day ${String(d).padEnd(3)} ${bar.padEnd(20)} ${String((n / total * 100).toFixed(0)).padStart(3)}% (n=${n})`);
      }
      out.push('');
    }

    out.push(`### Source Action Ratio (per type)\n`);
    out.push(`| Evidence Type | Source Action | Count | Share |`);
    out.push(`|---------------|---------------|-------|-------|`);
    for (const [t, srcMap] of Object.entries(evAcq.sourceRatio)) {
      const total = Object.values(srcMap).reduce((s, n) => s + n, 0);
      const sorted = Object.entries(srcMap).sort((a, b) => b[1] - a[1]);
      for (const [src, n] of sorted) {
        out.push(`| ${t} | ${src} | ${n} | ${(n / total * 100).toFixed(1)}% |`);
      }
    }
    out.push('');
  }

  // Evidence Used
  out.push(`\n## Evidence Used\n`);
  out.push(`_New events from [SPA-1530](/SPA/issues/SPA-1530) — usage rate, claim/target cross-tabs, hoarding ratio._\n`);
  if (!evUsed.counts.length) {
    out.push(`_No \`evidence_used\` events in dataset._\n`);
  } else {
    out.push(`### Usage Count (per type × scenario × difficulty)\n`);
    out.push(`| Evidence Type | Scenario | Difficulty | Count |`);
    out.push(`|---------------|----------|------------|-------|`);
    for (const row of evUsed.counts) {
      out.push(`| ${row.evidence_type} | ${row.scenario_id} | ${row.difficulty} | ${row.count} |`);
    }

    out.push(`\n### Cross-tab: Evidence Type × Claim ID\n`);
    out.push(`| Evidence Type | Claim ID | Count |`);
    out.push(`|---------------|----------|-------|`);
    for (const row of evUsed.claimCrossTab) {
      out.push(`| ${row.evidence_type} | ${row.claim_id} | ${row.count} |`);
    }

    out.push(`\n### Cross-tab: Evidence Type × Seed Target\n`);
    out.push(`| Evidence Type | Seed Target | Count |`);
    out.push(`|---------------|-------------|-------|`);
    for (const row of evUsed.targetCrossTab) {
      out.push(`| ${row.evidence_type} | ${row.seed_target} | ${row.count} |`);
    }

    out.push(`\n### Day Histogram (when items are used)\n`);
    for (const [t, hist] of Object.entries(evUsed.dayHist)) {
      out.push(`**${t}**`);
      const days = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
      const total = Object.values(hist).reduce((s, n) => s + n, 0);
      for (const d of days) {
        const n = hist[d];
        const bar = '█'.repeat(Math.max(1, Math.round(n / total * 20)));
        out.push(`  Day ${String(d).padEnd(3)} ${bar.padEnd(20)} ${String((n / total * 100).toFixed(0)).padStart(3)}% (n=${n})`);
      }
      out.push('');
    }

    out.push(`### Acquisition-to-Use Ratio (hoarding indicator)\n`);
    out.push(`| Evidence Type | Acquired | Used | Ratio | Note |`);
    out.push(`|---------------|----------|------|-------|------|`);
    for (const [t, v] of Object.entries(evUsed.acqToUseRatio)) {
      const ratioStr = v.ratio != null ? (v.ratio * 100).toFixed(1) + '%' : 'N/A';
      const note = v.ratio == null ? '—' :
                   v.ratio < 0.33 ? '⚠️ hoarding' :
                   v.ratio > 0.90 ? '⚠️ spending all' : '✅';
      out.push(`| ${t} | ${v.acquired} | ${v.used} | ${ratioStr} | ${note} |`);
    }
    out.push('');
  }

  // Phase 2: Evidence Economy
  out.push(`\n## Phase 2 — Evidence Economy (SPA-1574)\n`);
  out.push(`_Decay ticks, threshold crossings, and target shifts._\n`);

  if (!evDecay.ticksPerType.length && !evThreshold.crossings.length && !evShift.shifts.length) {
    out.push(`_No Phase 2 evidence-economy events in dataset._\n`);
  } else {
    if (evDecay.ticksPerType.length) {
      out.push(`### Decay Ticks\n`);
      out.push(`| Evidence Type | Scenario | Ticks | Avg Decay/Tick |`);
      out.push(`|---------------|----------|-------|----------------|`);
      for (const row of evDecay.ticksPerType) {
        const avg = evDecay.avgDecayRate[row.evidence_type];
        out.push(`| ${row.evidence_type} | ${row.scenario_id} | ${row.count} | ${avg != null ? avg.toFixed(3) : 'N/A'} |`);
      }
      out.push('');
    }

    if (evThreshold.crossings.length) {
      out.push(`### Threshold Crossings\n`);
      out.push(`| Evidence Type | Direction | Scenario | Count |`);
      out.push(`|---------------|-----------|----------|-------|`);
      for (const row of evThreshold.crossings) {
        out.push(`| ${row.evidence_type} | ${row.direction} | ${row.scenario_id} | ${row.count} |`);
      }
      out.push(`\nThreshold hit counts: ${JSON.stringify(evThreshold.thresholdHit)}\n`);
    }

    if (evShift.shifts.length) {
      out.push(`### Target Shifts\n`);
      out.push(`| Evidence Type | Scenario | Shifts |`);
      out.push(`|---------------|----------|--------|`);
      for (const row of evShift.shifts) {
        out.push(`| ${row.evidence_type} | ${row.scenario_id} | ${row.count} |`);
      }
      if (evShift.flowPairs.length) {
        out.push(`\n**Flow pairs:**`);
        for (const fp of evShift.flowPairs) {
          out.push(`  ${fp.from_target} → ${fp.to_target}: ${fp.count}`);
        }
      }
      out.push('');
    }
  }

  // Red Flags
  out.push(`---\n\n## 🚩 Red Flags\n`);
  if (!flags.length) {
    out.push(`_No red flags. All measured metrics within healthy thresholds._\n`);
  } else {
    for (const f of flags) out.push(`- ${f}`);
    out.push('');
  }

  // ── Phase 1 Balance Watchlist ───────────────────────────────────────────────
  out.push(`---\n\n## Phase 1 Balance Watchlist\n`);
  out.push(`_Cross-reference: [phase1-balance-watchlist.md](../../docs/phase1-balance-watchlist.md)_\n`);

  out.push(`### Scenario 2 — Sister Maren Counter-Intelligence\n`);
  out.push(`| Row | Metric | Value | Threshold | Status |`);
  out.push(`|-----|--------|-------|-----------|--------|`);
  if (wlMaren.total === 0) {
    out.push(`| 2-A | Maren-fail ratio | — (no S2 failures) | >60% → reduce edge weights | — |`);
    out.push(`| 2-B | Maren ineffective | — (no S2 failures) | <10% → raise edge weights | — |`);
  } else {
    const ratio2 = wlMaren.ratio.toFixed(1);
    const s2a = wlMaren.ratio > 60 ? '🚨 reduce edge weights' :
                wlMaren.ratio < 10 ? '⚠️ check 2-B' : '✅ calibrated';
    const s2b = wlMaren.ratio < 10 ? '🚨 raise edge weights' : '✅';
    out.push(`| 2-A | Maren-fail ratio | ${ratio2}% (${wlMaren.marenFails}/${wlMaren.total} S2 fails) | >60% → reduce edge weights | ${s2a} |`);
    out.push(`| 2-B | Maren ineffective | ${ratio2}% | <10% → raise edge weights | ${s2b} |`);
  }
  // 2-C and 2-D reference other KPIs
  const s2cWall = (() => {
    const hist = k2r['S2'] || k2r['s2'] || null;
    if (!hist) return '— (no S2 failures)';
    const total = Object.values(hist).reduce((a, b) => a + b, 0);
    const wall  = Object.entries(hist).find(([, n]) => total && n / total > 0.40);
    return wall ? `🚨 day-${wall[0]} wall (${(wall[1]/total*100).toFixed(0)}%)` : '✅ no wall';
  })();
  const s2dGap = (() => {
    const v = k4r['S2'] || k4r['s2'] || null;
    if (!v) return '— (no data)';
    let status = '✅ healthy';
    if (v.med > 4) status = '⚠️ too slow';
    else if (v.med === 0) status = '⚠️ instant';
    return `median ${v.med.toFixed(1)} d (n=${v.count}) — ${status}`;
  })();
  out.push(`| 2-C | S2 quit-day wall | ${s2cWall} | single day >40% of fails | — |`);
  out.push(`| 2-D | S2 seed→believe gap | ${s2dGap} | 1–3 d healthy | — |`);

  out.push(`\n### Scenario 3 — Late-Phase Rival Pacing\n`);
  out.push(`| Row | Metric | Value | Threshold | Status |`);
  out.push(`|-----|--------|-------|-----------|--------|`);
  // 3-A
  if (wlCalder.samples === 0) {
    out.push(`| 3-A | Calder day-15 rep (S3 wins) | — (no calder rep data) | ≥90% of wins >65 → nerf cooldown | — |`);
  } else {
    const above65pct = (wlCalder.above65 / wlCalder.samples * 100).toFixed(0);
    const s3a = wlCalder.above65 / wlCalder.samples >= 0.90 ? '🚨 extend rival cooldown' : '✅';
    const method = wlCalder.snapshotSamples === wlCalder.samples ? 'lossless'
                 : wlCalder.snapshotSamples > 0 ? `${wlCalder.snapshotSamples}/${wlCalder.samples} lossless`
                 : 'lossy fallback';
    out.push(`| 3-A | Calder day-15 rep (S3 wins) | med ${wlCalder.med != null ? wlCalder.med.toFixed(0) : 'N/A'}, ${above65pct}% >65 (n=${wlCalder.samples}, ${method}) | ≥90% of wins >65 → nerf cooldown | ${s3a} |`);
  }
  // 3-B
  if (wlS3Quit.total === 0) {
    out.push(`| 3-B | S3 mid-game quit (d15–19) | — (no S3 failures) | >50% → disengagement | — |`);
  } else {
    const ratio3b = wlS3Quit.ratio != null ? wlS3Quit.ratio.toFixed(1) + '%' : 'N/A';
    const s3b = wlS3Quit.ratio != null && wlS3Quit.ratio > 50 ? '🚨 mid-game disengagement' : '✅';
    out.push(`| 3-B | S3 mid-game quit (d15–19) | ${ratio3b} (${wlS3Quit.midQuit}/${wlS3Quit.total} S3 fails) | >50% → disengagement | ${s3b} |`);
  }
  // 3-C references KPI 8
  const s3cShifts = (() => {
    const v = k8r['S3'] || k8r['s3'] || null;
    if (!v) return '— (no data)';
    let status = '✅ healthy';
    if (v.avgShifts > 10) status = '⚠️ chaotic';
    else if (v.avgShifts < 1) status = '⚠️ static';
    return `avg ${v.avgShifts.toFixed(1)} shifts/session — ${status}`;
  })();
  out.push(`| 3-C | S3 rep-delta frequency | ${s3cShifts} | 2–5 shifts/session healthy | — |`);
  out.push(`| 3-D | Spymaster completion (S3) | — | <5% after 500+ attempts → whisper floor | — |`);

  out.push(`\n### Cross-Scenario\n`);
  out.push(`| Row | Metric | Value | Threshold | Status |`);
  out.push(`|-----|--------|-------|-----------|--------|`);
  out.push(`| X-A | Spymaster completion (any) | — | <5% after 500+ attempts → floor | — |`);

  // per-NPC REJECT → fail correlation
  out.push(`\n### Per-NPC REJECT → Fail Correlation\n`);
  out.push(`_NPCs that, when they reject a rumor, correlate strongly with session failure. Informs rows 2-A, X-A._\n`);
  if (!wlNpc.length) {
    out.push(`_No REJECT events in dataset._\n`);
  } else {
    out.push(`| NPC | Sessions w/ REJECT | Also FAILED | Correlation | Note |`);
    out.push(`|-----|--------------------|-------------|-------------|------|`);
    for (const v of wlNpc) {
      const corr = v.correlation.toFixed(0) + '%';
      const note = v.correlation >= 80 ? '⚠️ strong predictor' :
                   v.correlation >= 50 ? '⚠️ moderate' : '—';
      out.push(`| ${v.npc} | ${v.rejectSessions} | ${v.failedSessions} | ${corr} | ${note} |`);
    }
    out.push('');
  }

  // Volume
  out.push(`---\n\n## Volume\n`);
  out.push(`| Metric | Count |`);
  out.push(`|--------|-------|`);
  out.push(`| Analytics files | ${filePaths.length} |`);
  out.push(`| Total sessions | ${sessions.length} |`);
  out.push(`| Completed sessions | ${sessions.filter(s => s.ended).length} |`);
  out.push(`| Incomplete/open sessions | ${sessions.filter(s => !s.ended).length} |`);
  out.push(`| Total events | ${events.length} |`);

  return out.join('\n');
}

// ── JSON builder ──────────────────────────────────────────────────────────────

function buildJson(events, sessions, filePaths) {
  const k1r  = kpi1(sessions);
  const k2r  = kpi2(sessions);
  const k3r  = kpi3(sessions);
  const k4r  = kpi4(sessions);
  const k5r  = kpi5(events);
  const k6r  = kpi6(sessions);
  const k7r  = kpi7(events);
  const k8r  = kpi8(sessions);
  const k9r  = kpi9(sessions);
  const k10r = kpi10(sessions);
  const k11r = kpi11(events);
  const k12r = kpi12(sessions);
  const evAcq  = evidenceAcquiredAgg(events);
  const evUsed = evidenceUsedAgg(events, evAcq);
  const evDecay     = evidenceDecayTickAgg(events);
  const evThreshold = evidenceThresholdCrossAgg(events);
  const evShift     = evidenceTargetShiftAgg(events);
  const flags = redFlags(k1r, k2r, k3r, k4r, k5r, k6r, k7r, k8r, k11r, sessions);
  const wlMaren  = wlMarenFail(sessions);
  const wlCalder = wlCalderDay15(sessions);
  const wlS3Quit = wlS3MidQuit(sessions);
  const wlNpc    = wlNpcRejectFail(sessions);

  return {
    generated: new Date().toISOString(),
    input: {
      files: filePaths.length,
      sessions: sessions.length,
      events: events.length,
      completedSessions: sessions.filter(s => s.ended).length,
      incompleteSessions: sessions.filter(s => !s.ended).length,
    },
    kpi1_completion_rate: k1r,
    kpi2_day_of_quit: k2r,
    kpi3_session_duration: k3r,
    kpi4_seed_to_believer: k4r,
    kpi5_adoption_funnel: k5r,
    kpi6_recon_action_rate: k6r,
    kpi7_recon_success_rate: k7r,
    kpi8_reputation_volatility: k8r,
    kpi9_attempt_sequence: k9r,
    kpi10_difficulty_distribution: k10r,
    kpi11_tutorial_abandonment: k11r,
    kpi12_settings_touched: k12r,
    evidence_acquired: evAcq,
    evidence_used: evUsed,
    evidence_decay_tick: evDecay,
    evidence_threshold_cross: evThreshold,
    evidence_target_shift: evShift,
    watchlist: {
      maren_fail: wlMaren,
      calder_day15: wlCalder,
      s3_mid_quit: wlS3Quit,
      npc_reject_fail: wlNpc,
    },
    red_flags: flags,
  };
}

// ── Entry point ───────────────────────────────────────────────────────────────

const rawArgs = process.argv.slice(2);
const jsonMode = rawArgs.includes('--json');
const args = rawArgs.filter(a => a !== '--json');

if (!args.length) {
  process.stderr.write(
    'Usage: node tools/analytics/kpi_aggregate.js [--json] <file.ndjson> [file2.ndjson ...]\n' +
    'Example: node tools/analytics/kpi_aggregate.js tools/analytics/fixtures/*.ndjson\n' +
    '         node tools/analytics/kpi_aggregate.js --json tools/analytics/fixtures/*.ndjson\n'
  );
  process.exit(1);
}

const events  = loadFiles(args);
const sessions = groupSessions(events);

if (jsonMode) {
  process.stdout.write(JSON.stringify(buildJson(events, sessions, args), null, 2) + '\n');
} else {
  process.stdout.write(buildDigest(events, sessions, args) + '\n');
}
