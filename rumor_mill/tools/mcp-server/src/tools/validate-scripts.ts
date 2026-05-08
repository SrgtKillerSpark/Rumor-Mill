/**
 * MCP tool handler: validate_scripts
 *
 * Runs the Godot project in headless mode and returns a structured report
 * of all GDScript errors and warnings detected during the run.
 *
 * Coverage: all .gd files in the project tree are loaded and parsed, including
 * scripts that are not part of the autoload chain or main scene. A temporary
 * GDScript is written to the project directory, passed via --script, and
 * removed after validation completes.
 */

import { writeFileSync, unlinkSync } from 'fs';
import * as path from 'path';
import { runHeadless } from '../lib/godot-runner.js';
import type { GodotRunResult } from '../lib/godot-runner.js';

// ── Validator GDScript ────────────────────────────────────────────────────────

/**
 * Temporary GDScript injected into the project during validation.
 * Extends SceneTree so it can be run via `--script` in headless mode.
 * It recursively scans the project tree and calls load() on every .gd file,
 * which causes Godot to parse and compile each script and emit any parse
 * errors to stderr — exactly what the output parser already captures.
 *
 * Dot-prefixed entries (including the temp file itself, `.godot/`, `.git/`)
 * are skipped so the scanner never tries to load its own source.
 */
const VALIDATE_ALL_GD = `extends SceneTree

const _SKIP_DIRS: Array[String] = ["node_modules"]

func _initialize() -> void:
\t_scan("res://")
\tquit()

func _scan(base: String) -> void:
\tvar dir := DirAccess.open(base)
\tif dir == null:
\t\treturn
\tdir.list_dir_begin()
\tvar entry := dir.get_next()
\twhile entry != "":
\t\tif not entry.begins_with(".") and entry not in _SKIP_DIRS:
\t\t\tvar full := base.path_join(entry)
\t\t\tif dir.current_is_dir():
\t\t\t\t_scan(full)
\t\t\telif entry.ends_with(".gd"):
\t\t\t\tload(full)
\t\tentry = dir.get_next()
\tdir.list_dir_end()
`;

/** Filename used for the temporary validator script inside the project root. */
const VALIDATE_SCRIPT_FILENAME = '.mcp_validate_scripts.gd';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface ValidateScriptsArgs {
  projectPath: string;
  timeoutMs?: number;
  /** Skip the --import pre-pass. Faster but may return stale results if source files were edited in-session. */
  skipReimport?: boolean;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'validate_scripts';

export const description =
  'Run the Godot project headless, load every .gd file in the project tree (including scripts not in the autoload/main-scene), and return a structured report of all GDScript parse errors and warnings.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
    timeoutMs: {
      type: 'number',
      description: 'Process timeout in milliseconds. Defaults to 30000.',
    },
    skipReimport: {
      type: 'boolean',
      description:
        'Skip the --import pre-pass that flushes the Godot import cache before validation. ' +
        'Faster but may return stale results when source files have been edited in-session. ' +
        'Defaults to false (pre-pass runs by default).',
    },
  },
  required: ['projectPath'],
};

export async function handler(args: ValidateScriptsArgs): Promise<ToolResult> {
  const { projectPath, timeoutMs, skipReimport } = args;

  // Write the temporary validator script into the project root.
  // Using a dot-prefixed filename so DirAccess (which skips dot-entries) never
  // tries to load the script recursively during its own scan.
  const tempScriptPath = path.join(projectPath, VALIDATE_SCRIPT_FILENAME);
  try {
    writeFileSync(tempScriptPath, VALIDATE_ALL_GD, 'utf8');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [{ type: 'text', text: `Error writing validator script to project: ${message}` }],
      isError: true,
    };
  }

  let result: GodotRunResult;
  try {
    result = await runHeadless(projectPath, {
      timeoutMs,
      forceReimport: !skipReimport,
      extraArgs: ['--script', `res://${VALIDATE_SCRIPT_FILENAME}`],
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [{ type: 'text', text: `Error running Godot: ${message}` }],
      isError: true,
    };
  } finally {
    // Best-effort cleanup — do not throw if removal fails.
    try { unlinkSync(tempScriptPath); } catch { /* ignore */ }
  }

  const report: Record<string, unknown> = {
    exitCode: result.exitCode,
    crashed: result.crashed,
    duration_ms: result.duration_ms,
    validationCoverage: 'all_scripts',
    errorCount: result.errors.length,
    warningCount: result.warnings.length,
    errors: result.errors,
    warnings: result.warnings,
  };

  return {
    content: [{ type: 'text', text: JSON.stringify(report, null, 2) }],
    isError: result.crashed || result.errors.length > 0,
  };
}
