#!/usr/bin/env node
/**
 * Generate synthetic NDJSON fixtures for evidence telemetry aggregation testing.
 *
 * Produces deterministic sample data covering:
 * - 3 evidence types × 3 scenarios × 2 difficulties × spread of days
 * - evidence_used with type × claim × target combos
 * - scenario_ended for win-rate joins
 *
 * Output: tools/analytics/fixtures/sample_*.ndjson
 */

const fs = require("fs");
const path = require("path");

const FIXTURES_DIR = path.join(__dirname, "fixtures");

const EVIDENCE_TYPES = ["forged_document", "incriminating_artifact", "witness_account"];
const SOURCE_ACTIONS = {
  forged_document: "observe_building",
  incriminating_artifact: "observe_building",
  witness_account: "eavesdrop_npc",
};
const SCENARIOS = ["scenario_2", "scenario_3", "scenario_4"];
const DIFFICULTIES = ["apprentice", "master"];
const CLAIMS = ["ACC-01", "SCA-01", "HER-01", "PRA-01", "VOU-01"];
const TARGETS = ["Alys", "Maren", "Aldous", "Vera", "Finn", "Calder"];
const SUBJECTS = ["Alys", "Maren", "Aldous", "Vera", "Finn", "Calder"];

const BASE_TS = new Date("2026-04-20T10:00:00Z");

function addHours(date, hours) {
  return new Date(date.getTime() + hours * 3600000);
}

function generateEvidenceAcquired() {
  const events = [];
  let idx = 0;
  for (const scenario of SCENARIOS) {
    for (const difficulty of DIFFICULTIES) {
      for (const etype of EVIDENCE_TYPES) {
        for (let i = 0; i < 5; i++) {
          const day = 1 + (idx % 14);
          const ts = addHours(BASE_TS, idx * 2).toISOString();
          events.push({
            ts,
            type: "evidence_acquired",
            evidence_type: etype,
            source_action: SOURCE_ACTIONS[etype],
            day,
            scenario_id: scenario,
            difficulty,
          });
          idx++;
        }
      }
    }
  }
  return events;
}

function generateEvidenceUsed() {
  const events = [];
  let idx = 0;
  for (const scenario of SCENARIOS) {
    for (const difficulty of DIFFICULTIES) {
      for (const etype of EVIDENCE_TYPES) {
        for (let i = 0; i < 3; i++) {
          const day = 3 + (idx % 12);
          const ts = addHours(BASE_TS, idx * 3 + 50).toISOString();
          const claim = CLAIMS[idx % CLAIMS.length];
          const target = TARGETS[idx % TARGETS.length];
          const subject = SUBJECTS[(idx + 2) % SUBJECTS.length];
          events.push({
            ts,
            type: "evidence_used",
            evidence_type: etype,
            claim_id: claim,
            seed_target: target,
            subject,
            day,
            scenario_id: scenario,
            difficulty,
          });
          idx++;
        }
      }
    }
  }
  return events;
}

function generateScenarioEnded() {
  const events = [];
  let idx = 0;
  const outcomes = ["WON", "FAILED"];
  for (const scenario of SCENARIOS) {
    for (const difficulty of DIFFICULTIES) {
      for (let i = 0; i < 6; i++) {
        const day_reached = 8 + (idx % 7);
        const duration_sec = 300 + idx * 45;
        const outcome = outcomes[idx % 2];
        const ts = addHours(BASE_TS, idx * 5 + 100).toISOString();
        events.push({
          ts,
          type: "scenario_ended",
          scenario_id: scenario,
          difficulty,
          outcome,
          day_reached,
          duration_sec,
        });
        idx++;
      }
    }
  }
  return events;
}

function writeNdjson(filename, events) {
  const filepath = path.join(FIXTURES_DIR, filename);
  const content = events.map((e) => JSON.stringify(e)).join("\n") + "\n";
  fs.writeFileSync(filepath, content);
  console.log(`  ${filename}: ${events.length} events`);
}

function main() {
  fs.mkdirSync(FIXTURES_DIR, { recursive: true });
  console.log("Generating fixtures:");
  writeNdjson("sample_evidence_acquired.ndjson", generateEvidenceAcquired());
  writeNdjson("sample_evidence_used.ndjson", generateEvidenceUsed());
  writeNdjson("sample_scenario_ended.ndjson", generateScenarioEnded());
  console.log("Done.");
}

main();
