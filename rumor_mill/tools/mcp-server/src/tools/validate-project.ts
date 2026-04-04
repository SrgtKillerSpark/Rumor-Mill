/**
 * MCP tool handler: validate_project
 *
 * Scans all .tscn and .gd files in the project for res:// references,
 * then checks each referenced path exists on disk. Returns a report of
 * broken references grouped by source file.
 */

import * as fs from 'fs';
import * as path from 'path';
import { globProject, scanResReferences, resolveResPath } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ToolResult {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
}

interface BrokenReference {
  refPath: string;
  line: number;
}

interface FileReport {
  file: string;
  brokenReferences: BrokenReference[];
}

interface ValidateProjectArgs {
  projectPath: string;
}

// ── Tool definition ───────────────────────────────────────────────────────────

export const name = 'validate_project';

export const description =
  'Scan all .tscn and .gd files for res:// references and report any that point to missing files.';

export const inputSchema = {
  type: 'object',
  properties: {
    projectPath: {
      type: 'string',
      description: 'Absolute path to the Godot project directory (must contain project.godot).',
    },
  },
  required: ['projectPath'],
};

export async function handler(args: ValidateProjectArgs): Promise<ToolResult> {
  const { projectPath } = args;

  const resolvedRoot = path.resolve(projectPath);

  // Glob all .tscn and .gd files.
  let files: string[];
  try {
    const tscnFiles = globProject(resolvedRoot, '**/*.tscn');
    const gdFiles = globProject(resolvedRoot, '**/*.gd');
    files = [...tscnFiles, ...gdFiles];
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { content: [{ type: 'text', text: `Failed to glob project files: ${message}` }], isError: true };
  }

  const fileReports: FileReport[] = [];
  let totalBroken = 0;

  for (const absFilePath of files) {
    let content: string;
    try {
      content = fs.readFileSync(absFilePath, 'utf8');
    } catch {
      // Skip unreadable files silently.
      continue;
    }

    const refs = scanResReferences(content);
    const brokenReferences: BrokenReference[] = [];

    for (const ref of refs) {
      let refAbsPath: string;
      try {
        refAbsPath = resolveResPath(ref.path, resolvedRoot);
      } catch {
        brokenReferences.push({ refPath: ref.path, line: ref.line });
        continue;
      }

      if (!fs.existsSync(refAbsPath)) {
        brokenReferences.push({ refPath: ref.path, line: ref.line });
      }
    }

    if (brokenReferences.length > 0) {
      const relFile = path.relative(resolvedRoot, absFilePath).split(path.sep).join('/');
      fileReports.push({ file: relFile, brokenReferences });
      totalBroken += brokenReferences.length;
    }
  }

  const report = {
    scannedFiles: files.length,
    filesWithBrokenRefs: fileReports.length,
    totalBrokenReferences: totalBroken,
    details: fileReports,
  };

  return {
    content: [{ type: 'text', text: JSON.stringify(report, null, 2) }],
    isError: totalBroken > 0,
  };
}
