/**
 * MCP tool handler: launch_headless
 *
 * Spawns the Godot project in headless mode, optionally targeting a specific
 * scene, and returns the full stdout/stderr output plus crash/exit info.
 */

import { runHeadless } from '../lib/godot-runner.js';
import type { GodotRunResult } from '../lib/godot-runner.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface LaunchHeadlessArgs {
  projectPath: string;
  scene?: string;
  timeoutMs?: number;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'launch_headless';

export const description =
  'Launch the Godot project in headless mode (optionally with a specific scene) and return stdout, stderr, exit code, and crash status.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
    scene: {
      type: 'string',
      description: 'Optional res:// path to the scene to run (e.g. "res://scenes/Main.tscn").',
    },
    timeoutMs: {
      type: 'number',
      description: 'Process timeout in milliseconds. Defaults to 30000.',
    },
  },
  required: ['projectPath'],
};

export async function handler(args: LaunchHeadlessArgs): Promise<ToolResult> {
  const { projectPath, scene, timeoutMs } = args;

  const extraArgs: string[] = scene ? [scene] : [];

  let result: GodotRunResult;
  try {
    result = await runHeadless(projectPath, { timeoutMs, extraArgs });
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
    stdout: result.stdout,
    stderr: result.stderr,
    errors: result.errors,
    warnings: result.warnings,
  };

  return {
    content: [{ type: 'text', text: JSON.stringify(report, null, 2) }],
    isError: result.crashed,
  };
}
