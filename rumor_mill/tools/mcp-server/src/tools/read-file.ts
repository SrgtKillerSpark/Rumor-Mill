/**
 * MCP tool handler: read_file
 *
 * Reads the contents of a file within the Godot project root.
 * Accepts both absolute filesystem paths and res:// paths.
 * Enforces a path-safety check to prevent traversal outside the project.
 */

import * as fs from 'fs';
import { isPathSafe, resolveResPath } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface ReadFileArgs {
  projectPath: string;
  filePath: string;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'read_file';

export const description =
  'Read the contents of a file inside the Godot project. Accepts res:// paths or absolute filesystem paths. Rejects paths outside the project root.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
    filePath: {
      type: 'string',
      description:
        'Path to read. Accepts a res:// path (e.g. "res://scripts/npc.gd") or an absolute filesystem path inside the project root.',
    },
  },
  required: ['projectPath', 'filePath'],
};

export async function handler(args: ReadFileArgs): Promise<ToolResult> {
  const { projectPath, filePath } = args;

  // Resolve res:// to an absolute path.
  let absPath: string;
  try {
    absPath = filePath.startsWith('res://')
      ? resolveResPath(filePath, projectPath)
      : filePath;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Path resolution error: ${message}` }], isError: true };
  }

  // Enforce project-root containment.
  if (!isPathSafe(absPath, projectPath)) {
    return {
      content: [{ type: 'text', text: `Access denied: "${filePath}" is outside the project root.` }],
      isError: true,
    };
  }

  // Read the file.
  let fileContent: string;
  try {
    fileContent = fs.readFileSync(absPath, 'utf8');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Failed to read file: ${message}` }], isError: true };
  }

  return {
    content: [{ type: 'text', text: fileContent }],
  };
}
