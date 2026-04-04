/**
 * MCP tool handler: inspect_scene_tree
 *
 * Parses a Godot .tscn file and returns the full node tree structure,
 * including node types, scripts, instances, and properties.
 */

import * as fs from 'fs';
import { parseTscn } from '../lib/tscn-parser.js';
import { resolveResPath, isPathSafe } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface InspectSceneTreeArgs {
  projectPath: string;
  scenePath: string;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'inspect_scene_tree';

export const description =
  'Parse a Godot .tscn scene file and return the full node tree with types, scripts, instances, and properties.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
    scenePath: {
      type: 'string',
      description:
        'Path to the scene file. Accepts a res:// path (e.g. "res://scenes/Main.tscn") or an absolute filesystem path.',
    },
  },
  required: ['projectPath', 'scenePath'],
};

export async function handler(args: InspectSceneTreeArgs): Promise<ToolResult> {
  const { projectPath, scenePath } = args;

  // Resolve to absolute filesystem path.
  let absPath: string;
  try {
    absPath = scenePath.startsWith('res://')
      ? resolveResPath(scenePath, projectPath)
      : scenePath;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Path resolution error: ${message}` }], isError: true };
  }

  // Safety check — must be inside the project root.
  if (!isPathSafe(absPath, projectPath)) {
    return {
      content: [{ type: 'text', text: `Access denied: path is outside the project root.` }],
      isError: true,
    };
  }

  // Read the file.
  let content: string;
  try {
    content = fs.readFileSync(absPath, 'utf8');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Failed to read scene file: ${message}` }], isError: true };
  }

  // Parse the .tscn content.
  let parsed: ReturnType<typeof parseTscn>;
  try {
    parsed = parseTscn(content);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Failed to parse scene: ${message}` }], isError: true };
  }

  return {
    content: [{ type: 'text', text: JSON.stringify(parsed, null, 2) }],
  };
}
