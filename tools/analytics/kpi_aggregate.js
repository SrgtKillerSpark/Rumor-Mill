#!/usr/bin/env node
/**
 * kpi_aggregate.js — Slice B evidence-economy aggregation queries.
 *
 * Reads one or more NDJSON event logs and produces 8 named KPI queries:
 *
 *   A1: Acquisition rate by evidence_type × scenario_id × difficulty
 *   A2: Acquisition timing histogram by evidence_type × day
 *   A3: Source distribution by evidence_type × source_action
 *   U1: Usage rate by evidence_type × scenario_id × difficulty
 *   U2: Claim affinity cross-tab evidence_type × claim_id
 *   U3: Target preference cross-tab evidence_type × seed_target
 *   U4: Usage timing histogram by evidence_type × day
 *   U5: Hoarding ratio COUNT(evidence_used) / COUNT(evidence_acquired) per evidence_type
 *
 * With --json also emits session-level KPIs used by the phase1 digest:
 *   kpi1_completion_rate, kpi2_day_of_quit, kpi3_session_duration,
 *   watchlist metrics, evidence_used_per_run (SPA-2092).
 *
 * Usage:
 *   node kpi_aggregate.js [--json] [ndjson_file ...]
 *
 * Default ndjson_file: ./fixtures/smoke_capture_phase2.ndjson
 */

"use strict";

const fs = require("fs");
const path = require("path");

// ── CLI parsing ───────────────────────────────────────────────────────────────

const argv = process.argv.slice(2);
let jsonMode = false;
const inputFiles = [];

for (const arg of argv) {
  if (arg === "--json") { jsonMode = true; continue; }
  inputFiles.push(arg);
}

if (inputFiles.length === 0) {
  inputFiles.push(path.join(__dirname, "fixtures", "smoke_capture_phase2.ndjson"));
}

// Legacy single-file alias for text-mode backward compat.
const ndjsonFile = inputFiles[0];

// ── Loaders ───────────────────────────────────────────────────────────────────

function loadEvents(filepath) {
  if (!fs.existsSync(filepath)) {
    console.error(`Event log not found: ${filepath}`);
    process.exit(1);
  }
  return fs
    .readFileSync(filepath, "utf-8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function loadEventsFromFiles(filepaths) {
  const all = [];
  for (const fp of filepaths) {
    if (!fs.existsSync(fp)) {
      process.stderr.write(`Event log not found: ${fp}\n`);
      process.exit(1);
    }
    const lines = fs.readFileSync(fp, "utf-8").split("\n");
    for (const line of lines) {
      if (!line.trim()) continue;
      try { all.push(JSON.parse(line)); } catch { /* skip malformed */ }
    }
  }
  return all;
}

// ── Session grouping ──────────────────────────────────────────────────────────

function groupSessions(events) {
  const sessions = [];
  let cur = null;
  let idx = 0;
  for (const ev of events) {
    if (ev.type === "scenario_selected") {
      if (cur) sessions.push(cur);
      cur = {
        id: `session_${idx++}`,
        scenario_id: ev.scenario_id || "(unknown)",
        difficulty: ev.difficulty || "(unknown)",
        events: [ev],
        ended: false,
        outcome: null,
        day_reached: null,
        duration_sec: null,
      };
    } else if (cur) {
      cur.events.push(ev);
      if (ev.type === "scenario_ended") {
        cur.ended   = true;
        cur.outcome = ev.outcome || null;
        cur.day_reached  = ev.day_reached != null ? ev.day_reached : null;
        cur.duration_sec = ev.duration_sec != null ? ev.duration_sec : null;
        sessions.push(cur);
        cur = null;
      }
    }
  }
  if (cur) sessions.push(cur);
  return sessions;
}

// ── Stats helpers ─────────────────────────────────────────────────────────────

function median(sorted) {
  if (!sorted.length) return null;
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function p90(sorted) {
  if (!sorted.length) return null;
  const idx = Math.ceil(sorted.length * 0.9) - 1;
  return sorted[Math.max(0, idx)];
}

function mean(arr) {
  if (!arr.length) return null;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

// ── helpers ──────────────────────────────────────────────────────────────────

function groupBy3(events, k1, k2, k3) {
  const out = {};
  for (const e of events) {
    const key = `${e[k1] || "(unknown)"} | ${e[k2] || "(unknown)"} | ${e[k3] || "(unknown)"}`;
    out[key] = (out[key] || 0) + 1;
  }
  return out;
}

function buildCrossTab(events, rowKey, colKey) {
  const tab = {};
  for (const e of events) {
    const row = e[rowKey] || "(unknown)";
    const col = e[colKey] || "(unknown)";
    if (!tab[row]) tab[row] = {};
    tab[row][col] = (tab[row][col] || 0) + 1;
  }
  return tab;
}

function buildHistogramByType(events, field) {
  const out = {};
  for (const e of events) {
    const etype = e.evidence_type || "(unknown)";
    const val = String(e[field]);
    if (!out[etype]) out[etype] = {};
    out[etype][val] = (out[etype][val] || 0) + 1;
  }
  return out;
}

// ── printers ─────────────────────────────────────────────────────────────────

function printFlat3(title, table, h1, h2, h3) {
  console.log(`\n## ${title}`);
  console.log(`${h1} | ${h2} | ${h3} | count`);
  console.log("-".repeat(70));
  for (const [key, count] of Object.entries(table).sort()) {
    console.log(`${key} | ${count}`);
  }
}

function printHistogramByType(title, hist) {
  console.log(`\n## ${title}`);
  for (const etype of Object.keys(hist).sort()) {
    const bins = hist[etype];
    const keys = Object.keys(bins).sort((a, b) => Number(a) - Number(b));
    console.log(`  ${etype}:`);
    for (const k of keys) {
      console.log(`    day=${k}: ${bins[k]}`);
    }
  }
}

function printCrossTab(title, tab) {
  console.log(`\n## ${title}`);
  const allCols = new Set();
  for (const row of Object.values(tab)) {
    for (const col of Object.keys(row)) allCols.add(col);
  }
  const cols = [...allCols].sort();
  const colW = 20;
  const header = ["".padEnd(colW), ...cols.map((c) => c.padEnd(colW))].join(" | ");
  console.log(header);
  console.log("-".repeat(header.length));
  for (const row of Object.keys(tab).sort()) {
    const cells = [row.padEnd(colW)];
    for (const col of cols) {
      cells.push(String(tab[row][col] || 0).padEnd(colW));
    }
    console.log(cells.join(" | "));
  }
}

function printSourceDistribution(title, acquired) {
  console.log(`\n## ${title}`);
  const types = [...new Set(acquired.map((e) => e.evidence_type || "(unknown)"))].sort();
  for (const etype of types) {
    const subset = acquired.filter((e) => e.evidence_type === etype);
    const total = subset.length;
    const actions = {};
    for (const e of subset) {
      const a = e.source_action || "(unknown)";
      actions[a] = (actions[a] || 0) + 1;
    }
    console.log(`  ${etype} (n=${total}):`);
    for (const [action, count] of Object.entries(actions).sort()) {
      console.log(`    ${action}: ${count} (${((count / total) * 100).toFixed(1)}%)`);
    }
  }
}

// ── JSON mode: session-level KPIs (used by phase1_digest.js) ─────────────────

function computeSessionKpis(allEvents, filepaths) {
  const sessions = groupSessions(allEvents);
  const completed = sessions.filter((s) => s.ended);

  // ── KPI 1: Completion rate per scenario × difficulty ──
  const kpi1Map = {};
  for (const s of sessions) {
    const key = `${s.scenario_id}|${s.difficulty}`;
    if (!kpi1Map[key]) kpi1Map[key] = { scenario_id: s.scenario_id, difficulty: s.difficulty, selected: 0, won: 0 };
    kpi1Map[key].selected++;
    if (s.outcome === "WON") kpi1Map[key].won++;
  }
  const kpi1 = Object.values(kpi1Map).sort((a, b) =>
    a.scenario_id.localeCompare(b.scenario_id) || a.difficulty.localeCompare(b.difficulty));

  // ── KPI 2: Day-of-quit histogram (failed sessions) ──
  const kpi2 = {};
  for (const s of completed.filter((s) => s.outcome === "FAILED")) {
    const day = String(s.day_reached != null ? s.day_reached : "?");
    if (!kpi2[s.scenario_id]) kpi2[s.scenario_id] = {};
    kpi2[s.scenario_id][day] = (kpi2[s.scenario_id][day] || 0) + 1;
  }

  // ── KPI 3: Session duration per scenario × outcome ──
  const kpi3Map = {};
  for (const s of completed) {
    if (s.duration_sec == null) continue;
    const key = `${s.scenario_id}_${s.outcome}`;
    if (!kpi3Map[key]) kpi3Map[key] = { scenario_id: s.scenario_id, outcome: s.outcome, vals: [] };
    kpi3Map[key].vals.push(s.duration_sec);
  }
  const kpi3 = {};
  for (const [key, entry] of Object.entries(kpi3Map)) {
    const sorted = [...entry.vals].sort((a, b) => a - b);
    kpi3[key] = {
      scenario_id: entry.scenario_id, outcome: entry.outcome,
      count: sorted.length, med: median(sorted), p90: p90(sorted),
    };
  }

  // ── Watchlist metrics ──
  const s2Failed = completed.filter((s) => s.scenario_id === "scenario_2" && s.outcome === "FAILED");
  const marenFails = s2Failed.filter((s) =>
    s.events.some((e) => e.type === "scenario_fail_trigger" && e.trigger_npc_id === "maren")).length;
  const watchlist = {
    maren_fail: {
      ratio: s2Failed.length > 0 ? (marenFails / s2Failed.length) * 100 : null,
      marenFails,
      total: s2Failed.length,
    },
    calder_day15: (function() {
      const snaps = allEvents.filter(
        (e) => e.type === "reputation_snapshot" && e.npc_id === "calder" && e.day === 15);
      if (!snaps.length) return { med: null, above65: 0, samples: 0 };
      const scores = snaps.map((e) => e.score).sort((a, b) => a - b);
      return { med: median(scores), above65: scores.filter((s) => s > 65).length, samples: scores.length };
    })(),
    s3_mid_quit: (function() {
      const s3f = completed.filter((s) => s.scenario_id === "scenario_3" && s.outcome === "FAILED");
      const midQuit = s3f.filter((s) => s.day_reached >= 15 && s.day_reached <= 19).length;
      return {
        ratio: s3f.length > 0 ? (midQuit / s3f.length) * 100 : null,
        midQuit, total: s3f.length,
      };
    })(),
  };

  // ── Red flags ──
  const red_flags = [];
  for (const row of kpi1) {
    if (row.difficulty === "normal" && row.selected >= 5) {
      const rate = row.won / row.selected;
      if (rate < 0.25) red_flags.push(`${row.scenario_id} Normal completion < 25% (${(rate * 100).toFixed(0)}%)`);
    }
  }

  // ── SPA-2092: evidence_used_per_run ──────────────────────────────────────
  // Count evidence_used events per session, grouped by scenario_id.
  // Reports mean/median/p90 across sessions for each scenario.
  const evidencePerRunMap = {}; // scenario_id → number[]
  for (const s of sessions) {
    const count = s.events.filter((e) => e.type === "evidence_used").length;
    if (!evidencePerRunMap[s.scenario_id]) evidencePerRunMap[s.scenario_id] = [];
    evidencePerRunMap[s.scenario_id].push(count);
  }
  const evidence_used_per_run = {};
  for (const [scen, counts] of Object.entries(evidencePerRunMap)) {
    const sorted = [...counts].sort((a, b) => a - b);
    evidence_used_per_run[scen] = {
      mean:   mean(sorted) != null ? parseFloat(mean(sorted).toFixed(2)) : null,
      median: median(sorted),
      p90:    p90(sorted),
      n:      sorted.length,
    };
  }

  return {
    input: {
      files: filepaths.length,
      sessions: sessions.length,
      completedSessions: completed.length,
      events: allEvents.length,
    },
    kpi1_completion_rate: kpi1,
    kpi2_day_of_quit: kpi2,
    kpi3_session_duration: kpi3,
    watchlist,
    red_flags,
    evidence_used_per_run,
  };
}

// ── main ─────────────────────────────────────────────────────────────────────

function main() {
  if (jsonMode) {
    const all = loadEventsFromFiles(inputFiles);
    const result = computeSessionKpis(all, inputFiles);
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
    return;
  }

  const all = loadEvents(ndjsonFile);
  const acquired = all.filter((e) => e.type === "evidence_acquired");
  const used = all.filter((e) => e.type === "evidence_used");

  console.log(`Reading events from: ${ndjsonFile}`);
  console.log(
    `Loaded: ${all.length} total events (${acquired.length} evidence_acquired, ${used.length} evidence_used)\n`
  );

  // A1: Acquisition rate by evidence_type × scenario_id × difficulty
  printFlat3(
    "A1: Acquisition rate — evidence_type × scenario_id × difficulty",
    groupBy3(acquired, "evidence_type", "scenario_id", "difficulty"),
    "evidence_type",
    "scenario_id",
    "difficulty"
  );

  // A2: Acquisition timing histogram by evidence_type × day
  printHistogramByType(
    "A2: Acquisition timing histogram — evidence_type × day",
    buildHistogramByType(acquired, "day")
  );

  // A3: Source distribution by evidence_type × source_action
  printSourceDistribution(
    "A3: Source distribution — evidence_type × source_action",
    acquired
  );

  // U1: Usage rate by evidence_type × scenario_id × difficulty
  printFlat3(
    "U1: Usage rate — evidence_type × scenario_id × difficulty",
    groupBy3(used, "evidence_type", "scenario_id", "difficulty"),
    "evidence_type",
    "scenario_id",
    "difficulty"
  );

  // U2: Claim affinity cross-tab evidence_type × claim_id
  printCrossTab(
    "U2: Claim affinity — evidence_type × claim_id",
    buildCrossTab(used, "evidence_type", "claim_id")
  );

  // U3: Target preference cross-tab evidence_type × seed_target
  printCrossTab(
    "U3: Target preference — evidence_type × seed_target",
    buildCrossTab(used, "evidence_type", "seed_target")
  );

  // U4: Usage timing histogram by evidence_type × day
  printHistogramByType(
    "U4: Usage timing histogram — evidence_type × day",
    buildHistogramByType(used, "day")
  );

  // U5: Hoarding ratio COUNT(evidence_used) / COUNT(evidence_acquired) per evidence_type
  console.log("\n## U5: Hoarding ratio — COUNT(evidence_used) / COUNT(evidence_acquired)");
  console.log(
    `${"evidence_type".padEnd(25)} | ${"acquired".padEnd(8)} | ${"used".padEnd(8)} | ratio`
  );
  console.log("-".repeat(65));
  const acqByType = {};
  for (const e of acquired) {
    const t = e.evidence_type || "(unknown)";
    acqByType[t] = (acqByType[t] || 0) + 1;
  }
  const usedByType = {};
  for (const e of used) {
    const t = e.evidence_type || "(unknown)";
    usedByType[t] = (usedByType[t] || 0) + 1;
  }
  const allTypes = new Set([...Object.keys(acqByType), ...Object.keys(usedByType)]);
  for (const etype of [...allTypes].sort()) {
    const a = acqByType[etype] || 0;
    const u = usedByType[etype] || 0;
    const ratio = a > 0 ? (u / a).toFixed(3) : "N/A";
    console.log(
      `${etype.padEnd(25)} | ${String(a).padEnd(8)} | ${String(u).padEnd(8)} | ${ratio}`
    );
  }

  console.log("\n---");
  console.log("kpi_aggregate complete.");
  console.log(`Total events processed: ${all.length}`);
}

main();
