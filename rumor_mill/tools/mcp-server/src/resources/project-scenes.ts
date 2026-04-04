/**
 * MCP resource handler: godot://project/scenes
 *
 * Globs all .tscn files in the project and returns, for each scene,
 * the root node type and the script attached to the root node (if any).
 * Only the first ~30 lines of each file are read for efficiency.
 */

import * as fs from 'fs';
import * as path from 'path';
import { findProjectRoot, globProject } from '../lib/project-paths.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ResourceResult {
  contents: Array<{
    uri: string;
    mimeType: string;
    text: string;
  }>;
}

interface SceneSummary {
  file: string;
  rootType: string | null;
  rootScript: string | null;
}

// ── Scene extraction ──────────────────────────────────────────────────────────

const EXT_RESOURCE_RE = /^\[ext_resource\s+[^\]]*type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"/;
const NODE_RE = /^\[node\s+([^\]]*)\]/;
const ATTR_RE = /(\w+)="([^"]*)"/g;
const SCRIPT_PROP_RE = /^script\s*=\s*ExtResource\("([^"]+)"\)/;

/**
 * Extract root node type and root script path from the first ~50 lines of
 * a .tscn file without doing a full parse.
 */
function extractSceneSummary(content: string, relPath: string): SceneSummary {
  const lines = content.split(/\r?\n/).slice(0, 80);

  // Build id -> path map for Script ext_resources
  const scriptById = new Map<string, string>();
  for (const line of lines) {
    const m = EXT_RESOURCE_RE.exec(line);
    if (m) {
      scriptById.set(m[2]!, m[1]!);
    }
  }

  // Find root node (first [node ...] section, which has no parent attribute)
  let rootType: string | null = null;
  let rootScript: string | null = null;
  let inRootNode = false;

  for (const line of lines) {
    if (line.startsWith('[node')) {
      const nodeMatch = NODE_RE.exec(line);
      if (!nodeMatch) continue;
      const attrsStr = nodeMatch[1]!;
      const attrs: Record<string, string> = {};
      let m: RegExpExecArray | null;
      ATTR_RE.lastIndex = 0;
      while ((m = ATTR_RE.exec(attrsStr)) !== null) {
        attrs[m[1]!] = m[2]!;
      }
      // Root node has no `parent` attribute
      if (!('parent' in attrs)) {
        rootType = attrs['type'] ?? null;
        inRootNode = true;
      } else {
        inRootNode = false;
      }
    } else if (inRootNode) {
      const scriptMatch = SCRIPT_PROP_RE.exec(line.trim());
      if (scriptMatch) {
        const id = scriptMatch[1]!;
        rootScript = scriptById.get(id) ?? null;
        break;
      }
      // Stop reading root node properties at the next section
      if (line.startsWith('[')) {
        break;
      }
    }
  }

  return { file: relPath, rootType, rootScript };
}

// ── Resource definition ───────────────────────────────────────────────────────

export const uri = 'godot://project/scenes';
export const name = 'project-scenes';
export const description =
  'List of all .tscn scene files in the project with each scene\'s root node type and attached script.';
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

  let tscnFiles: string[];
  try {
    tscnFiles = globProject(projectRoot, '**/*.tscn');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      contents: [{ uri, mimeType: 'text/plain', text: `Error globbing .tscn files: ${message}` }],
    };
  }

  const scenes: SceneSummary[] = [];

  for (const absPath of tscnFiles) {
    let content: string;
    try {
      // Read only first 4 KB — enough to cover ext_resources and root node
      const fd = fs.openSync(absPath, 'r');
      const buf = Buffer.alloc(4096);
      const bytesRead = fs.readSync(fd, buf, 0, 4096, 0);
      fs.closeSync(fd);
      content = buf.slice(0, bytesRead).toString('utf8');
    } catch {
      continue;
    }
    const relPath = path.relative(projectRoot, absPath).split(path.sep).join('/');
    scenes.push(extractSceneSummary(content, relPath));
  }

  const report = {
    sceneCount: scenes.length,
    scenes,
  };

  return {
    contents: [{ uri, mimeType, text: JSON.stringify(report, null, 2) }],
  };
}
