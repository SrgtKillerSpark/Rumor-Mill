#!/usr/bin/env node
// validate_dialogue.js — checks npc_dialogue.json for completeness against npcs.json.
// Run from the rumor_mill/ directory:  node tools/validate_dialogue.js
// Exits 0 on success, 1 if any issues are found.

const fs   = require('fs');
const path = require('path');

const DATA_DIR      = path.join(__dirname, '..', 'data');
const NPCS_PATH     = path.join(DATA_DIR, 'npcs.json');
const DIALOGUE_PATH = path.join(DATA_DIR, 'npc_dialogue.json');

const REQUIRED_STATES = [
  'ambient',
  'hear',
  'believe',
  'reject',
  'spread',
  'act',
  'defending',
  'observe',
  'eavesdrop',
];

// ── Load files ────────────────────────────────────────────────────────────────
let npcs, dialogueRoot;
try {
  npcs         = JSON.parse(fs.readFileSync(NPCS_PATH,     'utf8'));
  dialogueRoot = JSON.parse(fs.readFileSync(DIALOGUE_PATH, 'utf8'));
} catch (e) {
  console.error('ERROR: could not parse data files:', e.message);
  process.exit(1);
}

const dialogue  = dialogueRoot.npc_dialogue;
const npcIds    = npcs.map(n => n.id);
const dlgIds    = Object.keys(dialogue);
const issues    = [];

// ── Cross-check: npcs.json vs npc_dialogue.json ───────────────────────────────
for (const id of npcIds) {
  if (!dialogue[id]) {
    issues.push(`[${id}] missing from npc_dialogue.json entirely`);
    continue;
  }
  for (const state of REQUIRED_STATES) {
    const lines = dialogue[id][state];
    if (!lines) {
      issues.push(`[${id}] missing state: "${state}"`);
    } else if (!Array.isArray(lines) || lines.length === 0) {
      issues.push(`[${id}] state "${state}" has no lines (empty array)`);
    } else {
      lines.forEach((line, idx) => {
        if (typeof line !== 'string' || line.trim() === '') {
          issues.push(`[${id}] state "${state}"[${idx}] is empty or not a string`);
        }
      });
    }
  }
  // Warn about unknown states (not an error, but worth flagging)
  for (const state of Object.keys(dialogue[id])) {
    if (!REQUIRED_STATES.includes(state)) {
      issues.push(`[${id}] unexpected state key: "${state}" (not in REQUIRED_STATES)`);
    }
  }
}

// ── Orphan entries: dialogue keys with no matching NPC ───────────────────────
for (const id of dlgIds) {
  if (!npcIds.includes(id)) {
    issues.push(`[${id}] found in npc_dialogue.json but not in npcs.json`);
  }
}

// ── Report ────────────────────────────────────────────────────────────────────
if (issues.length === 0) {
  console.log(`OK — all ${npcIds.length} NPCs validated across ${REQUIRED_STATES.length} states. No issues found.`);
  process.exit(0);
} else {
  console.error(`FAIL — ${issues.length} issue(s) found in NPC dialogue data:\n`);
  issues.forEach(msg => console.error('  •', msg));
  process.exit(1);
}
