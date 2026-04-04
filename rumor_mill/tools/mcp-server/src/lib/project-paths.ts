/**
 * Godot project path utilities for the MCP server.
 * Handles res:// resolution, path safety checks, project-root discovery,
 * res:// reference scanning, and in-project glob matching.
 *
 * All operations are cross-platform (Windows + Unix).
 */

import * as fs from 'fs';
import * as path from 'path';

// ── res:// resolution ─────────────────────────────────────────────────────────

/**
 * Convert a `res://` path to an absolute filesystem path.
 *
 * @param resPath     A Godot resource path, e.g. `res://scripts/npc.gd`.
 * @param projectRoot Absolute path to the Godot project directory
 *                    (the folder that contains `project.godot`).
 */
export function resolveResPath(resPath: string, projectRoot: string): string {
  if (!resPath.startsWith('res://')) {
    throw new Error(`resolveResPath: expected a res:// path, got: ${resPath}`);
  }
  // Strip the scheme, then join with the project root.
  const relative = resPath.slice('res://'.length);
  // Godot always uses forward slashes; normalise for the host OS.
  const nativeRelative = relative.split('/').join(path.sep);
  return path.resolve(projectRoot, nativeRelative);
}

/**
 * Convert an absolute filesystem path back to a `res://` path.
 *
 * @param absPath     An absolute filesystem path inside the project.
 * @param projectRoot Absolute path to the Godot project directory.
 */
export function toResPath(absPath: string, projectRoot: string): string {
  const resolvedProject = path.resolve(projectRoot);
  const resolvedAbs = path.resolve(absPath);
  const rel = path.relative(resolvedProject, resolvedAbs);
  if (rel.startsWith('..')) {
    throw new Error(
      `toResPath: path "${absPath}" is outside the project root "${projectRoot}"`,
    );
  }
  // Godot uses forward slashes regardless of platform.
  return 'res://' + rel.split(path.sep).join('/');
}

// ── Path safety ───────────────────────────────────────────────────────────────

/**
 * Return `true` when `requestedPath` resolves to a location inside
 * `projectRoot`, preventing path-traversal attacks.
 *
 * Accepts both absolute paths and `res://` paths.
 */
export function isPathSafe(requestedPath: string, projectRoot: string): boolean {
  const resolvedProject = path.resolve(projectRoot);

  let resolvedRequested: string;
  if (requestedPath.startsWith('res://')) {
    try {
      resolvedRequested = resolveResPath(requestedPath, projectRoot);
    } catch {
      return false;
    }
  } else {
    resolvedRequested = path.resolve(requestedPath);
  }

  // A path is safe when it starts with the project root (with a trailing
  // separator to avoid prefix collisions like /foo/bar vs /foo/barbaz).
  const normalizedProject = resolvedProject.endsWith(path.sep)
    ? resolvedProject
    : resolvedProject + path.sep;

  return (
    resolvedRequested === resolvedProject ||
    resolvedRequested.startsWith(normalizedProject)
  );
}

// ── Project root discovery ────────────────────────────────────────────────────

/**
 * Walk up the directory tree from `startDir` (defaults to `process.cwd()`)
 * until a directory containing `project.godot` is found.
 *
 * Throws if no project root is found.
 */
export function findProjectRoot(startDir?: string): string {
  let current = path.resolve(startDir ?? process.cwd());

  while (true) {
    if (fs.existsSync(path.join(current, 'project.godot'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      // Reached the filesystem root.
      throw new Error(
        'findProjectRoot: no directory containing "project.godot" found' +
          (startDir ? ` starting from "${startDir}"` : ''),
      );
    }
    current = parent;
  }
}

// ── res:// reference scanner ──────────────────────────────────────────────────

/** A single `res://` reference extracted from file content. */
export interface ResReference {
  path: string;
  line: number;
}

/**
 * Scan `fileContent` and return every `res://` reference found, with its
 * 1-based line number.
 *
 * The regex captures the path up to the first whitespace, quote, bracket,
 * or end-of-line to avoid false positives.
 */
export function scanResReferences(fileContent: string): ResReference[] {
  const results: ResReference[] = [];
  const lines = fileContent.split(/\r?\n/);
  // Matches res:// followed by any non-whitespace, non-quote, non-bracket chars.
  const RE = /res:\/\/[^\s"'<>)\],;]*/g;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    let match: RegExpExecArray | null;
    RE.lastIndex = 0;
    while ((match = RE.exec(line)) !== null) {
      results.push({ path: match[0], line: i + 1 });
    }
  }

  return results;
}

// ── In-project glob ───────────────────────────────────────────────────────────

/**
 * Convert a glob pattern to a `RegExp` that can be tested against POSIX-style
 * relative paths. Supports `*`, `**`, and `?`.
 */
function globToRegExp(pattern: string): RegExp {
  // Normalise to forward slashes.
  const normalised = pattern.split(path.sep).join('/');
  let reStr = '';
  let i = 0;
  while (i < normalised.length) {
    const ch = normalised[i]!;
    if (ch === '*') {
      if (normalised[i + 1] === '*') {
        // `**` — match zero or more path segments.
        reStr += '.*';
        i += 2;
        // Consume optional trailing slash after `**`.
        if (normalised[i] === '/') i++;
      } else {
        // `*` — match anything except a path separator.
        reStr += '[^/]*';
        i++;
      }
    } else if (ch === '?') {
      reStr += '[^/]';
      i++;
    } else if ('.+^${}()|[]\\'.includes(ch)) {
      reStr += '\\' + ch;
      i++;
    } else {
      reStr += ch;
      i++;
    }
  }
  return new RegExp('^' + reStr + '$');
}

/**
 * Recursively collect all files under `dir`, returning POSIX-style paths
 * relative to `root`.
 */
function collectFiles(dir: string, root: string): string[] {
  const results: string[] = [];
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return results;
  }
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...collectFiles(fullPath, root));
    } else if (entry.isFile()) {
      const rel = path.relative(root, fullPath).split(path.sep).join('/');
      results.push(rel);
    }
  }
  return results;
}

/**
 * Glob files within `projectRoot` matching `pattern`.
 *
 * Returns absolute filesystem paths. Supports `*`, `**`, and `?` wildcards.
 * Only files within the project root are returned (path-safe by construction).
 *
 * @param projectRoot Absolute path to the Godot project directory.
 * @param pattern     Glob pattern relative to the project root, e.g. `**\/*.gd`.
 */
export function globProject(projectRoot: string, pattern: string): string[] {
  const resolvedRoot = path.resolve(projectRoot);
  const re = globToRegExp(pattern);
  const allFiles = collectFiles(resolvedRoot, resolvedRoot);
  return allFiles
    .filter(rel => re.test(rel))
    .map(rel => path.join(resolvedRoot, rel.split('/').join(path.sep)));
}
