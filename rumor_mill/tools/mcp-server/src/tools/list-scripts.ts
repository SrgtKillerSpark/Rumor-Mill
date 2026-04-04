/**
 * MCP tool handler: list_scripts
 *
 * Globs all .gd files in the project and extracts high-level metadata
 * from each: class_name, extends, @export variables, and signal declarations.
 */

import * as fs from 'fs';
import * as path from 'path';
import { globProject } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface ScriptInfo {
  file: string;
  className: string | null;
  extends: string | null;
  signals: string[];
  exports: string[];
}

interface ListScriptsArgs {
  projectPath: string;
  pattern?: string;
}

// ── Regex patterns ────────────────────────────────────────────────────────────

const CLASS_NAME_RE = /^class_name\s+(\w+)/m;
const EXTENDS_RE = /^extends\s+(\S+)/m;
const SIGNAL_RE = /^signal\s+(\w+)/gm;
const EXPORT_RE = /^@export(?:\s+\w+)?\s+var\s+(\w+)/gm;

function extractScriptInfo(content: string, relPath: string): ScriptInfo {
  const classNameMatch = CLASS_NAME_RE.exec(content);
  const extendsMatch = EXTENDS_RE.exec(content);

  const signals: string[] = [];
  let m: RegExpExecArray | null;
  SIGNAL_RE.lastIndex = 0;
  while ((m = SIGNAL_RE.exec(content)) !== null) {
    signals.push(m[1]!);
  }

  const exports: string[] = [];
  EXPORT_RE.lastIndex = 0;
  while ((m = EXPORT_RE.exec(content)) !== null) {
    exports.push(m[1]!);
  }

  return {
    file: relPath,
    className: classNameMatch ? classNameMatch[1]! : null,
    extends: extendsMatch ? extendsMatch[1]! : null,
    signals,
    exports,
  };
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'list_scripts';

export const description =
  'List all GDScript (.gd) files in the project and extract their class_name, extends, signals, and @export variables.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
    pattern: {
      type: 'string',
      description: 'Glob pattern relative to project root. Defaults to "**/*.gd".',
    },
  },
  required: ['projectPath'],
};

export async function handler(args: ListScriptsArgs): Promise<ToolResult> {
  const { projectPath, pattern = '**/*.gd' } = args;

  const resolvedRoot = path.resolve(projectPath);

  let files: string[];
  try {
    files = globProject(resolvedRoot, pattern);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Failed to glob scripts: ${message}` }], isError: true };
  }

  const scripts: ScriptInfo[] = [];

  for (const absFilePath of files) {
    let content: string;
    try {
      content = fs.readFileSync(absFilePath, 'utf8');
    } catch {
      continue;
    }
    const relPath = path.relative(resolvedRoot, absFilePath).split(path.sep).join('/');
    scripts.push(extractScriptInfo(content, relPath));
  }

  const report = {
    scriptCount: scripts.length,
    scripts,
  };

  return {
    content: [{ type: 'text', text: JSON.stringify(report, null, 2) }],
  };
}
