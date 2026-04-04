/**
 * MCP resource handler: godot://project/config
 *
 * Parses `project.godot` (INI-like format) and returns structured JSON with:
 * name, version, main_scene, autoloads, display settings, and features.
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

interface ProjectConfig {
  name: string | null;
  description: string | null;
  version: string | null;
  main_scene: string | null;
  features: string[];
  autoloads: Record<string, string>;
  display: {
    viewport_width: number | null;
    viewport_height: number | null;
  };
}

// ── INI parser ────────────────────────────────────────────────────────────────

/**
 * Parse a Godot project.godot file (INI-like format).
 * Returns a nested map of section -> key -> value.
 */
function parseGodotIni(content: string): Record<string, Record<string, string>> {
  const result: Record<string, Record<string, string>> = {};
  let currentSection = '__global__';

  for (const raw of content.split(/\r?\n/)) {
    const line = raw.trim();

    // Skip comments and blank lines
    if (!line || line.startsWith(';') || line.startsWith('#')) continue;

    // Section header
    if (line.startsWith('[') && line.endsWith(']')) {
      currentSection = line.slice(1, -1).trim();
      if (!result[currentSection]) result[currentSection] = {};
      continue;
    }

    // Key=value
    const eqIdx = line.indexOf('=');
    if (eqIdx === -1) continue;
    const key = line.slice(0, eqIdx).trim();
    const value = line.slice(eqIdx + 1).trim();

    if (!result[currentSection]) result[currentSection] = {};
    result[currentSection]![key] = value;
  }

  return result;
}

/** Strip surrounding quotes from a string value, if present. */
function stripQuotes(value: string): string {
  if (value.startsWith('"') && value.endsWith('"')) {
    return value.slice(1, -1);
  }
  return value;
}

/**
 * Parse `PackedStringArray("a", "b", ...)` into string[].
 * Returns empty array for unrecognised formats.
 */
function parsePackedStringArray(value: string): string[] {
  const m = value.match(/^PackedStringArray\((.+)\)$/s);
  if (!m) return [];
  const inner = m[1]!.trim();
  const items: string[] = [];
  // Split on commas that are not inside quotes
  let current = '';
  let inQuote = false;
  for (let i = 0; i < inner.length; i++) {
    const ch = inner[i]!;
    if (ch === '"') {
      inQuote = !inQuote;
      current += ch;
    } else if (ch === ',' && !inQuote) {
      items.push(stripQuotes(current.trim()));
      current = '';
    } else {
      current += ch;
    }
  }
  if (current.trim()) items.push(stripQuotes(current.trim()));
  return items;
}

// ── Resource definition ───────────────────────────────────────────────────────

export const uri = 'godot://project/config';
export const name = 'project-config';
export const description =
  'Structured JSON summary of project.godot: name, version, main scene, autoloads, display settings, and features.';
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

  const godotFile = path.join(projectRoot, 'project.godot');
  let raw: string;
  try {
    raw = fs.readFileSync(godotFile, 'utf8');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      contents: [{ uri, mimeType: 'text/plain', text: `Error reading project.godot: ${message}` }],
    };
  }

  const ini = parseGodotIni(raw);

  const app = ini['application'] ?? {};
  const display = ini['display'] ?? {};
  const autoloadSection = ini['autoload'] ?? {};

  // Autoloads: strip the leading '*' from resource paths (singleton marker).
  const autoloads: Record<string, string> = {};
  for (const [key, value] of Object.entries(autoloadSection)) {
    autoloads[key] = stripQuotes(value).replace(/^\*/, '');
  }

  const config: ProjectConfig = {
    name: app['config/name'] ? stripQuotes(app['config/name']) : null,
    description: app['config/description'] ? stripQuotes(app['config/description']) : null,
    version: app['config/version'] ? stripQuotes(app['config/version']) : null,
    main_scene: app['run/main_scene'] ? stripQuotes(app['run/main_scene']) : null,
    features: app['config/features'] ? parsePackedStringArray(app['config/features']) : [],
    autoloads,
    display: {
      viewport_width: display['window/size/viewport_width']
        ? parseInt(display['window/size/viewport_width'], 10) || null
        : null,
      viewport_height: display['window/size/viewport_height']
        ? parseInt(display['window/size/viewport_height'], 10) || null
        : null,
    },
  };

  return {
    contents: [{ uri, mimeType, text: JSON.stringify(config, null, 2) }],
  };
}
