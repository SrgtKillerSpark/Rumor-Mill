#!/usr/bin/env node
/**
 * phase1_digest.js — Phase 1 Daily Digest Runner
 *
 * Wires kpi_aggregate.js and trigger_detector.js into a single markdown
 * digest for Day-N balance reviews.
 *
 * Usage:
 *   node tools/balance/phase1_digest.js <file.ndjson> [file2.ndjson ...]
 *   node tools/balance/phase1_digest.js tools/analytics/fixtures/*.ndjson
 *   node tools/balance/phase1_digest.js --out digest.md tools/analytics/fixtures/*.ndjson
 *
 * Options:
 *   --out <path>   Write digest to a file instead of stdout.
 *
 * Exit codes:
 *   0 — digest produced, no triggers fired
 *   1 — digest produced, one or more triggers fired
 *   2 — usage / input error
 *
 * Issue: SPA-1534
 * Refs: SPA-1490, SPA-1520, SPA-1527, SPA-1532
 *
 * No external dependencies — stdlib only.
 */

'use strict';

const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// ── Resolve sibling tool paths ──────────────────────────────────────────────

const SCRIPT_DIR = __dirname;
const KPI_AGG = path.resolve(SCRIPT_DIR, '../analytics/kpi_aggregate.js');
const TRIGGER_DET = path.resolve(SCRIPT_DIR, 'trigger_detector.js');

// ── CLI parsing ─────────────────────────────────────────────────────────────

const argv = process.argv.slice(2);
let outPath = null;
const files = [];

for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--out' && argv[i + 1]) { outPath = argv[++i]; continue; }
  files.push(argv[i]);
}

if (!files.length) {
  process.stderr.write(
    'Usage: node tools/balance/phase1_digest.js [--out path.md] <file.ndjson> [...]\n' +
    'Example: node tools/balance/phase1_digest.js tools/analytics/fixtures/day6_s2_apprentice.ndjson\n'
  );
  process.exit(2);
}

// Validate inputs exist
for (const f of files) {
  if (!fs.existsSync(f)) {
    process.stderr.write(`File not found: ${f}\n`);
    process.exit(2);
  }
}

if (!fs.existsSync(KPI_AGG)) {
  process.stderr.write(`kpi_aggregate.js not found at: ${KPI_AGG}\n`);
  process.exit(2);
}
if (!fs.existsSync(TRIGGER_DET)) {
  process.stderr.write(`trigger_detector.js not found at: ${TRIGGER_DET}\n`);
  process.exit(2);
}

// ── Run analyzers ───────────────────────────────────────────────────────────

let kpiJson, triggerJson;

try {
  const kpiOut = execFileSync('node', [KPI_AGG, '--json', ...files], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  kpiJson = JSON.parse(kpiOut);
} catch (err) {
  process.stderr.write(`kpi_aggregate.js failed: ${err.message}\n`);
  process.exit(2);
}

try {
  // trigger_detector exits 1 when triggers fire — that's not an error for us
  const trigOut = execFileSync('node', [TRIGGER_DET, '--pretty', ...files], {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  triggerJson = JSON.parse(trigOut);
} catch (err) {
  // execFileSync throws on non-zero exit; stdout is still in err.stdout
  if (err.stdout) {
    try {
      triggerJson = JSON.parse(err.stdout);
    } catch {
      process.stderr.write(`trigger_detector.js output not parseable: ${err.message}\n`);
      process.exit(2);
    }
  } else {
    process.stderr.write(`trigger_detector.js failed: ${err.message}\n`);
    process.exit(2);
  }
}

// ── Build markdown digest ───────────────────────────────────────────────────

function buildDigest(kpi, trig) {
  const out = [];
  const now = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';

  // ── Header ──────────────────────────────────────────────────────────────
  out.push('# Phase 1 Balance Digest');
  out.push('');
  out.push(`_Generated: ${now}_`);

  // Derive scenarios covered
  const scenarios = new Set();
  for (const row of kpi.kpi1_completion_rate || []) {
    scenarios.add(row.scenario_id);
  }

  // Date window from events (use kpi.generated as proxy)
  out.push(`_Input: ${kpi.input.files} file(s) | ${kpi.input.sessions} sessions (${kpi.input.completedSessions} completed) | ${kpi.input.events} events_`);
  out.push(`_Scenarios: ${[...scenarios].sort().join(', ') || 'none'}_`);
  out.push('');
  out.push('---');
  out.push('');

  // ── Watchlist Trigger Summary (top) ─────────────────────────────────────
  out.push('## Watchlist Trigger Summary');
  out.push('');
  out.push('| ID | Hypothesis | Threshold | Actual | Sample | Status |');
  out.push('|----|------------|-----------|--------|--------|--------|');

  const firedTriggers = [];

  for (const t of trig.triggers) {
    let statusIcon;
    switch (t.status) {
      case 'FIRED':             statusIcon = '\u{1F534} fired'; firedTriggers.push(t); break;
      case 'WATCHING':          statusIcon = '\u26A0\uFE0F watch'; break;
      case 'OK':                statusIcon = '\u2705 within'; break;
      case 'INSUFFICIENT_DATA': statusIcon = '\u2796 insufficient data'; break;
      case 'unimplemented':     statusIcon = '\u2796 unimplemented'; break;
      default:                  statusIcon = t.status; break;
    }

    const threshStr = typeof t.threshold === 'string' ? t.threshold : JSON.stringify(t.threshold);
    const actualStr = formatValue(t.value);
    const sampleStr = t.sample != null ? `${t.sample}${t.sample_met ? '' : ` (need ${t.min_sample})`}` : '\u2014';

    out.push(`| ${t.id} | ${t.name} | ${threshStr} | ${actualStr} | ${sampleStr} | ${statusIcon} |`);
  }

  out.push('');

  // ── Notable Signals ─────────────────────────────────────────────────────
  out.push('## Notable Signals');
  out.push('');

  if (firedTriggers.length) {
    for (const t of firedTriggers) {
      out.push(`- \u{1F534} **${t.id} ${t.name}**: ${t.details || 'threshold met for 2+ consecutive cycles'}`);
    }
  }

  // Also pull red flags from KPI
  if (kpi.red_flags && kpi.red_flags.length) {
    for (const f of kpi.red_flags) {
      out.push(`- ${f}`);
    }
  }

  if (!firedTriggers.length && (!kpi.red_flags || !kpi.red_flags.length)) {
    out.push('_No triggers fired and no red flags detected._');
  }

  out.push('');
  out.push('---');
  out.push('');

  // ── Per-Lane KPI Table ──────────────────────────────────────────────────
  out.push('## Per-Lane KPI Table');
  out.push('');
  out.push('### Completion Rate (KPI 1)');
  out.push('');
  out.push('| Scenario | Difficulty | Sessions | Won | Rate |');
  out.push('|----------|------------|----------|-----|------|');
  for (const e of kpi.kpi1_completion_rate || []) {
    const rate = e.selected ? (e.won / e.selected * 100).toFixed(1) + '%' : 'N/A';
    out.push(`| ${e.scenario_id} | ${e.difficulty} | ${e.selected} | ${e.won} | ${rate} |`);
  }
  out.push('');

  // Day-of-quit histogram (KPI 2)
  out.push('### Day-of-Quit Histogram (KPI 2)');
  out.push('');
  const k2 = kpi.kpi2_day_of_quit || {};
  if (Object.keys(k2).length) {
    for (const [scen, hist] of Object.entries(k2)) {
      const total = Object.values(hist).reduce((a, b) => a + b, 0);
      out.push(`**${scen}** \u2014 ${total} failed session(s)`);
      const days = Object.keys(hist).sort((a, b) => Number(a) - Number(b));
      for (const d of days) {
        const n = hist[d];
        const p = (n / total * 100).toFixed(0);
        const bar = '\u2588'.repeat(Math.max(1, Math.round(n / total * 20)));
        const wall = n / total > 0.40 ? '  \u{1F6A8} quit wall' : '';
        out.push(`  Day ${String(d).padEnd(3)} ${bar.padEnd(20)} ${String(p).padStart(3)}% (n=${n})${wall}`);
      }
      out.push('');
    }
  } else {
    out.push('_No failed sessions in dataset._');
    out.push('');
  }

  // Session duration (KPI 3)
  out.push('### Session Duration (KPI 3)');
  out.push('');
  const k3 = kpi.kpi3_session_duration || {};
  if (Object.keys(k3).length) {
    out.push('| Scenario | Outcome | n | Median | p90 |');
    out.push('|----------|---------|---|--------|-----|');
    for (const v of Object.values(k3).sort((a, b) => a.scenario_id.localeCompare(b.scenario_id) || a.outcome.localeCompare(b.outcome))) {
      out.push(`| ${v.scenario_id} | ${v.outcome} | ${v.count} | ${fmtSec(v.med)} | ${fmtSec(v.p90)} |`);
    }
    out.push('');
  }

  // Watchlist metrics
  out.push('### Phase 1 Watchlist Metrics');
  out.push('');
  const wl = kpi.watchlist || {};
  if (wl.maren_fail) {
    const mf = wl.maren_fail;
    out.push(`- **Maren-fail ratio**: ${mf.ratio != null ? mf.ratio.toFixed(1) + '%' : 'N/A'} (${mf.marenFails}/${mf.total} S2 fails)`);
  }
  if (wl.calder_day15) {
    const cd = wl.calder_day15;
    const above = cd.samples ? (cd.above65 / cd.samples * 100).toFixed(0) + '%' : 'N/A';
    out.push(`- **Calder day-15 rep**: median ${cd.med != null ? cd.med : 'N/A'}, ${above} >65 (n=${cd.samples})`);
  }
  if (wl.s3_mid_quit) {
    const sq = wl.s3_mid_quit;
    out.push(`- **S3 mid-quit ratio**: ${sq.ratio != null ? sq.ratio.toFixed(1) + '%' : 'N/A'} (${sq.midQuit}/${sq.total} S3 fails in d15\u201319)`);
  }
  out.push('');

  // Volume
  out.push('---');
  out.push('');
  out.push('## Volume');
  out.push('');
  out.push(`| Metric | Count |`);
  out.push(`|--------|-------|`);
  out.push(`| Files | ${kpi.input.files} |`);
  out.push(`| Sessions | ${kpi.input.sessions} |`);
  out.push(`| Completed | ${kpi.input.completedSessions} |`);
  out.push(`| Events | ${kpi.input.events} |`);
  out.push(`| Triggers evaluated | ${trig.summary.total} |`);
  out.push(`| Triggers fired | ${trig.summary.fired} |`);
  out.push(`| Triggers watching | ${trig.summary.watching} |`);
  out.push('');

  return out.join('\n');
}

function formatValue(v) {
  if (v == null) return '\u2014';
  if (typeof v === 'number') return v.toFixed(3);
  if (typeof v === 'object' && !Array.isArray(v)) {
    return Object.entries(v).map(([k, val]) => `${k}=${val != null ? (typeof val === 'number' ? val.toFixed(3) : val) : 'N/A'}`).join(', ');
  }
  if (Array.isArray(v)) return `[${v.length} items]`;
  return String(v);
}

function fmtSec(sec) {
  if (sec == null) return 'N/A';
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return `${m}m ${s}s`;
}

// ── Output ──────────────────────────────────────────────────────────────────

const digest = buildDigest(kpiJson, triggerJson);

if (outPath) {
  fs.writeFileSync(outPath, digest + '\n');
  process.stderr.write(`Digest written to ${outPath}\n`);
} else {
  process.stdout.write(digest + '\n');
}

// Exit 1 if any triggers fired
const anyFired = triggerJson.summary && triggerJson.summary.fired > 0;
process.exit(anyFired ? 1 : 0);
