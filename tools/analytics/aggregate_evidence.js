#!/usr/bin/env node
/**
 * aggregate_evidence.js — Cross-tab aggregation for Phase 2 evidence telemetry.
 *
 * Reads NDJSON event files and produces the cross-tabs specified in
 * SPA-1522 (Phase 2 Evidence Telemetry Spec):
 *
 *   1. Acquisition counts: evidence_type × scenario_id × difficulty
 *   2. Day histogram per evidence type
 *   3. Source-action ratio per evidence type
 *   4. Usage counts: evidence_type × scenario_id × difficulty
 *   5. evidence_type × claim_id cross-tab
 *   6. evidence_type × seed_target cross-tab
 *   7. Acquisition-to-use ratio per evidence type
 *
 * Usage:
 *   node aggregate_evidence.js [fixtures_dir]
 *
 * Default fixtures_dir: ./fixtures
 */

const fs = require("fs");
const path = require("path");

const fixturesDir = process.argv[2] || path.join(__dirname, "fixtures");

function readNdjson(filename) {
  const filepath = path.join(fixturesDir, filename);
  if (!fs.existsSync(filepath)) {
    console.error(`File not found: ${filepath}`);
    process.exit(1);
  }
  return fs
    .readFileSync(filepath, "utf-8")
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line));
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

function buildHistogram(events, key) {
  const hist = {};
  for (const e of events) {
    const val = String(e[key]);
    hist[val] = (hist[val] || 0) + 1;
  }
  return hist;
}

function printCrossTab(title, tab, colLabel) {
  console.log(`\n## ${title}`);
  const allCols = new Set();
  for (const row of Object.keys(tab)) {
    for (const col of Object.keys(tab[row])) allCols.add(col);
  }
  const cols = [...allCols].sort();
  const header = ["", ...cols].map((c) => c.padEnd(20)).join(" | ");
  console.log(header);
  console.log("-".repeat(header.length));
  for (const row of Object.keys(tab).sort()) {
    const cells = [row.padEnd(20)];
    for (const col of cols) {
      cells.push(String(tab[row][col] || 0).padEnd(20));
    }
    console.log(cells.join(" | "));
  }
}

function printHistogramByType(title, events, field) {
  console.log(`\n## ${title}`);
  const types = [...new Set(events.map((e) => e.evidence_type))].sort();
  for (const etype of types) {
    const subset = events.filter((e) => e.evidence_type === etype);
    const hist = buildHistogram(subset, field);
    const keys = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
    console.log(`  ${etype}:`);
    for (const k of keys) {
      console.log(`    ${field}=${k}: ${hist[k]}`);
    }
  }
}

function main() {
  console.log(`Reading fixtures from: ${fixturesDir}\n`);

  const acquired = readNdjson("sample_evidence_acquired.ndjson");
  const used = readNdjson("sample_evidence_used.ndjson");
  const ended = readNdjson("sample_scenario_ended.ndjson");

  console.log(`Loaded: ${acquired.length} acquired, ${used.length} used, ${ended.length} scenario_ended`);

  // 1. Acquisition counts: evidence_type × scenario_id × difficulty
  console.log("\n## 1. Acquisition Counts: evidence_type × scenario_id × difficulty");
  const acqByTypeScenDiff = {};
  for (const e of acquired) {
    const key = `${e.evidence_type} | ${e.scenario_id} | ${e.difficulty}`;
    acqByTypeScenDiff[key] = (acqByTypeScenDiff[key] || 0) + 1;
  }
  console.log("evidence_type | scenario_id | difficulty | count");
  console.log("-".repeat(70));
  for (const [key, count] of Object.entries(acqByTypeScenDiff).sort()) {
    console.log(`${key} | ${count}`);
  }

  // 2. Day histogram per evidence type
  printHistogramByType("2. Day Histogram per Evidence Type", acquired, "day");

  // 3. Source-action ratio per evidence type
  console.log("\n## 3. Source-Action Ratio per Evidence Type");
  const types = [...new Set(acquired.map((e) => e.evidence_type))].sort();
  for (const etype of types) {
    const subset = acquired.filter((e) => e.evidence_type === etype);
    const actions = buildHistogram(subset, "source_action");
    const total = subset.length;
    console.log(`  ${etype} (n=${total}):`);
    for (const [action, count] of Object.entries(actions).sort()) {
      console.log(`    ${action}: ${count} (${((count / total) * 100).toFixed(1)}%)`);
    }
  }

  // 4. Usage counts: evidence_type × scenario_id × difficulty
  console.log("\n## 4. Usage Counts: evidence_type × scenario_id × difficulty");
  const useByTypeScenDiff = {};
  for (const e of used) {
    const key = `${e.evidence_type} | ${e.scenario_id} | ${e.difficulty}`;
    useByTypeScenDiff[key] = (useByTypeScenDiff[key] || 0) + 1;
  }
  console.log("evidence_type | scenario_id | difficulty | count");
  console.log("-".repeat(70));
  for (const [key, count] of Object.entries(useByTypeScenDiff).sort()) {
    console.log(`${key} | ${count}`);
  }

  // 5. evidence_type × claim_id cross-tab
  const typeClaim = buildCrossTab(used, "evidence_type", "claim_id");
  printCrossTab("5. Evidence Type × Claim ID", typeClaim, "claim_id");

  // 6. evidence_type × seed_target cross-tab
  const typeTarget = buildCrossTab(used, "evidence_type", "seed_target");
  printCrossTab("6. Evidence Type × Seed Target", typeTarget, "seed_target");

  // 7. Acquisition-to-use ratio per evidence type
  console.log("\n## 7. Acquisition-to-Use Ratio per Evidence Type");
  const acqCounts = buildHistogram(acquired, "evidence_type");
  const useCounts = buildHistogram(used, "evidence_type");
  console.log("evidence_type | acquired | used | ratio");
  console.log("-".repeat(60));
  for (const etype of types) {
    const a = acqCounts[etype] || 0;
    const u = useCounts[etype] || 0;
    const ratio = a > 0 ? (u / a).toFixed(2) : "N/A";
    console.log(`${etype.padEnd(25)} | ${String(a).padEnd(8)} | ${String(u).padEnd(4)} | ${ratio}`);
  }

  // Summary
  console.log("\n---");
  console.log("Aggregation complete.");
  console.log(`Total events processed: ${acquired.length + used.length + ended.length}`);
}

main();
