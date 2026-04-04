/**
 * MCP resource handler: godot://project/data
 *
 * Lists JSON files in the project's `data/` directory. For each file,
 * returns a schema summary: top-level keys and, for arrays, their length.
 */

import * as fs from 'fs';
import * as path from 'path';
import { findProjectRoot } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ResourceResult {
  contents: Array<{
    uri: string;
    mimeType: string;
    text: string;
  }>;
}

interface FieldSummary {
  key: string;
  type: string;
  /** Length if the top-level value for this key is an array. */
  arrayLength?: number;
}

interface DataFileSummary {
  file: string;
  topLevelType: string;
  fields?: FieldSummary[];
  /** Length when the root value is an array. */
  arrayLength?: number;
}

// ── Schema extraction ─────────────────────────────────────────────────────────

function jsonType(value: unknown): string {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  return typeof value;
}

function summariseValue(value: unknown): Omit<FieldSummary, 'key'> {
  const type = jsonType(value);
  if (type === 'array') {
    return { type, arrayLength: (value as unknown[]).length };
  }
  return { type };
}

function summariseJson(parsed: unknown): Omit<DataFileSummary, 'file'> {
  const topLevelType = jsonType(parsed);

  if (topLevelType === 'object' && parsed !== null) {
    const fields: FieldSummary[] = Object.entries(parsed as Record<string, unknown>).map(
      ([key, val]) => ({ key, ...summariseValue(val) }),
    );
    return { topLevelType, fields };
  }

  if (topLevelType === 'array') {
    return { topLevelType, arrayLength: (parsed as unknown[]).length };
  }

  return { topLevelType };
}

// ── Resource definition ───────────────────────────────────────────────────────

export const uri = 'godot://project/data';
export const name = 'project-data';
export const description =
  'Schema summary of all JSON files in the project\'s data/ directory: top-level keys, types, and array lengths.';
export const mimeType = 'application/json';

export async function handler(): Promise<ResourceResult> {
  let projectRoot: string;
  try {
    projectRoot = findProjectRoot();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      contents: [{ uri, mimeType: 'text/plain', text: `Error: ${message}` }],
    };
  }

  const dataDir = path.join(projectRoot, 'data');

  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(dataDir, { withFileTypes: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      contents: [{ uri, mimeType: 'text/plain', text: `Error reading data/ directory: ${message}` }],
    };
  }

  const jsonFiles = entries
    .filter(e => e.isFile() && e.name.endsWith('.json'))
    .map(e => e.name)
    .sort();

  const summaries: DataFileSummary[] = [];

  for (const filename of jsonFiles) {
    const absPath = path.join(dataDir, filename);
    let parsed: unknown;
    try {
      const raw = fs.readFileSync(absPath, 'utf8');
      parsed = JSON.parse(raw);
    } catch {
      summaries.push({ file: filename, topLevelType: 'error' });
      continue;
    }
    summaries.push({ file: filename, ...summariseJson(parsed) });
  }

  const report = {
    fileCount: summaries.length,
    files: summaries,
  };

  return {
    contents: [{ uri, mimeType, text: JSON.stringify(report, null, 2) }],
  };
}
