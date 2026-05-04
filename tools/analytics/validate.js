#!/usr/bin/env node
/**
 * validate.js — Smoke-test the aggregation script against golden output.
 *
 * Regenerates fixtures, runs aggregation, and diffs against golden_output.txt.
 * Exit 0 = pass, Exit 1 = mismatch.
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const dir = __dirname;
const fixturesDir = path.join(dir, "fixtures");
const goldenPath = path.join(fixturesDir, "golden_output.txt");

console.log("1. Regenerating fixtures...");
execSync(`node "${path.join(dir, "generate_fixtures.js")}"`, { stdio: "pipe" });

console.log("2. Running aggregation...");
const actual = execSync(`node "${path.join(dir, "aggregate_evidence.js")}"`, {
  encoding: "utf-8",
});

console.log("3. Comparing with golden output...");
if (!fs.existsSync(goldenPath)) {
  console.error(`Golden output not found: ${goldenPath}`);
  console.log("Creating golden output for next run...");
  fs.writeFileSync(goldenPath, actual);
  console.log("PASS (golden output created)");
  process.exit(0);
}

const expected = fs.readFileSync(goldenPath, "utf-8");

if (actual.replace(/\r\n/g, "\n") === expected.replace(/\r\n/g, "\n")) {
  console.log("PASS — output matches golden snapshot.");
  process.exit(0);
} else {
  console.error("FAIL — output differs from golden snapshot.");
  const actualLines = actual.split("\n");
  const expectedLines = expected.split("\n");
  let diffCount = 0;
  for (let i = 0; i < Math.max(actualLines.length, expectedLines.length); i++) {
    if (actualLines[i] !== expectedLines[i]) {
      if (diffCount < 5) {
        console.error(`  Line ${i + 1}:`);
        console.error(`    expected: ${expectedLines[i] || "(missing)"}`);
        console.error(`    actual:   ${actualLines[i] || "(missing)"}`);
      }
      diffCount++;
    }
  }
  if (diffCount > 5) console.error(`  ... and ${diffCount - 5} more differences`);
  process.exit(1);
}
