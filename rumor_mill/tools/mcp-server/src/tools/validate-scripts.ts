/**
 * MCP tool handler: validate_scripts
 *
 * Runs the Godot project in headless mode and returns a structured report
 * of all GDScript errors and warnings detected during the run.
 */

import { runHeadless } from '../lib/godot-runner.js';
import type { GodotRunResult } from '../lib/godot-runner.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface ValidateScriptsArgs {
  projectPath: string;
  timeoutMs?: number;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'validate_scripts';

export const description =
  'Run the Godot project headless and return a structured report of all GDScript errors and warnings.';

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
  },
  required: ['projectPath'],
};

export async function handler(args: ValidateScriptsArgs): Promise<ToolResult> {
  const { projectPath, timeoutMs } = args;

  let result: GodotRunResult;
  try {
    result = await runHeadless(projectPath, { timeoutMs });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [{ type: 'text', text: `Error running Godot: ${message}` }],
      isError: true,
    };
  }

  const report: Record<string, unknown> = {
    exitCode: result.exitCode,
    crashed: result.crashed,
    duration_ms: result.duration_ms,
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
