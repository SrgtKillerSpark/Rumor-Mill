#!/usr/bin/env node
/**
 * kpi_aggregate.js — Slice B evidence-economy aggregation queries.
 *
 * Reads a single combined NDJSON event log and produces 8 named KPI queries:
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
 * Usage:
 *   node kpi_aggregate.js [ndjson_file]
 *
 * Default ndjson_file: ./fixtures/smoke_capture_phase2.ndjson
 */

"use strict";

const fs = require("fs");
const path = require("path");

const ndjsonFile =
  process.argv[2] ||
  path.join(__dirname, "fixtures", "smoke_capture_phase2.ndjson");

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

// ── main ─────────────────────────────────────────────────────────────────────

function main() {
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
