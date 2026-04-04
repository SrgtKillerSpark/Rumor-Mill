/**
 * Godot headless runner for MCP server integration.
 * Spawns the Godot binary in headless mode, captures output, and parses
 * structured error/warning information from stdout + stderr.
 */

import { spawn, spawnSync } from 'child_process';
import { existsSync } from 'fs';
import { homedir } from 'os';
import * as path from 'path';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ParsedError {
  file: string;
  line: number | null;
  message: string;
  raw: string;
}

export interface ParsedWarning {
  file: string;
  line: number | null;
  message: string;
  raw: string;
}

export interface GodotRunResult {
  exitCode: number;
  crashed: boolean;
  stdout: string;
  stderr: string;
  errors: ParsedError[];
  warnings: ParsedWarning[];
  duration_ms: number;
}

export interface RunHeadlessOpts {
  /** Process timeout in milliseconds. Defaults to 30 000. */
  timeoutMs?: number;
  /** Additional CLI arguments passed after --headless --path <project>. */
  extraArgs?: string[];
}

// ── Binary discovery ──────────────────────────────────────────────────────────

/** Ordered list of candidate binary names / paths to probe. */
function getBinaryCandidates(): string[] {
  const envBin = process.env['GODOT_BIN'];
  const defaults = [
    'godot4',
    'godot',
    '/usr/local/bin/godot4',
    '/usr/bin/godot4',
    '/Applications/Godot.app/Contents/MacOS/Godot',
    'C:/Program Files/Godot/Godot_v4.x_stable/Godot_v4.x_stable_win64.exe',
    path.join(homedir(), '.local', 'share', 'godot', 'bin', 'godot4'),
  ];
  return envBin ? [envBin, ...defaults] : defaults;
}

/** Returns true if the given binary name/path resolves to an executable. */
function canExec(bin: string): boolean {
  // Absolute or relative path with directory component — check existence.
  if (path.isAbsolute(bin) || bin.includes('/') || bin.includes('\\')) {
    return existsSync(bin);
  }
  // Short name (e.g. "godot4") — probe via PATH using which / where.
  const whichCmd = process.platform === 'win32' ? 'where' : 'which';
  const result = spawnSync(whichCmd, [bin], { encoding: 'utf8', timeout: 2_000 });
  return result.status === 0;
}

/**
 * Find an available Godot binary.
 * Checks `GODOT_BIN` env var first, then falls back to well-known candidates.
 * Returns the first usable path, or `null` if none found.
 */
export function findGodotBinary(): string | null {
  for (const candidate of getBinaryCandidates()) {
    if (canExec(candidate)) return candidate;
  }
  return null;
}

// ── Output parsing ────────────────────────────────────────────────────────────

/**
 * Patterns that match Godot engine noise that should be filtered out.
 * These lines appear in clean runs and carry no actionable information.
 */
const NOISE_PATTERNS: RegExp[] = [
  /^BUG:/,
  /Unreferenced static string/,
  /RID.*leak/i,
  /PagedAllocator/,
  /Thread.*cleanup/i,
  /^CLEANUP:/,
  /servers being freed/i,
];

/**
 * Patterns that indicate a Godot crash (non-structured fatal failure).
 */
const CRASH_PATTERNS: RegExp[] = [
  /SIGSEGV/,
  /Segmentation fault/i,
  /unhandled exception/i,
  /ACCESS_VIOLATION/i,
  /Godot Engine has crashed/i,
];

const ERROR_RE = /^(ERROR|SCRIPT ERROR).*res:\/\/|^Parse error:/;
const WARNING_RE = /^WARNING:.*res:\/\//;

function isNoise(line: string): boolean {
  return NOISE_PATTERNS.some(p => p.test(line));
}

function isCrash(line: string): boolean {
  return CRASH_PATTERNS.some(p => p.test(line));
}

/**
 * Extract structured fields from a Godot error/warning line.
 *
 * Expected formats:
 *   ERROR: res://scripts/foo.gd:42 - Parse error: msg
 *   SCRIPT ERROR: res://scripts/foo.gd:42 - msg
 *   Parse error: res://scripts/foo.gd:42 - msg
 *   WARNING: res://scripts/foo.gd:10 - msg
 */
function extractFileInfo(raw: string): { file: string; line: number | null; message: string } {
  // With line number: res://path/to/file.gd:LINE - message
  const withLine = raw.match(/res:\/\/([^:\s]+):(\d+)\s*[-–]\s*(.+)$/);
  if (withLine) {
    return {
      file: 'res://' + withLine[1],
      line: parseInt(withLine[2], 10),
      message: withLine[3].trim(),
    };
  }
  // Without line number: res://path/to/file.gd - message
  const withoutLine = raw.match(/res:\/\/([^\s:]+)\s*[-–]\s*(.+)$/);
  if (withoutLine) {
    return { file: 'res://' + withoutLine[1], line: null, message: withoutLine[2].trim() };
  }
  return { file: '', line: null, message: raw };
}

function parseLines(text: string): { errors: ParsedError[]; warnings: ParsedWarning[]; crashed: boolean } {
  const errors: ParsedError[] = [];
  const warnings: ParsedWarning[] = [];
  let crashed = false;

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    if (!line) continue;

    if (isCrash(line)) crashed = true;
    if (isNoise(line)) continue;

    if (ERROR_RE.test(line)) {
      const { file, line: lineNum, message } = extractFileInfo(line);
      errors.push({ file, line: lineNum, message, raw: line });
    } else if (WARNING_RE.test(line)) {
      const { file, line: lineNum, message } = extractFileInfo(line);
      warnings.push({ file, line: lineNum, message, raw: line });
    }
  }

  return { errors, warnings, crashed };
}

// ── Headless runner ───────────────────────────────────────────────────────────

/**
 * Spawn Godot in headless mode against the given project path.
 *
 * Stdout and stderr are captured separately. Both streams are scanned for
 * structured errors/warnings. A timeout (default 30 s) kills the process if
 * Godot does not exit on its own — this is expected behaviour for projects
 * that run indefinitely.
 *
 * @param projectPath  Absolute path to the Godot project directory (must
 *                     contain a `project.godot` file).
 * @param opts         Optional configuration (timeoutMs, extraArgs).
 */
export async function runHeadless(
  projectPath: string,
  opts: RunHeadlessOpts = {},
): Promise<GodotRunResult> {
  const timeoutMs = opts.timeoutMs ?? 30_000;
  const extraArgs = opts.extraArgs ?? [];

  const godotBin = findGodotBinary();
  if (!godotBin) {
    throw new Error(
      'Godot binary not found. Set the GODOT_BIN environment variable or install Godot 4.',
    );
  }

  const args = ['--headless', '--path', projectPath, ...extraArgs];
  const startedAt = Date.now();

  return new Promise((resolve, reject) => {
    let timedOut = false;
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];

    const child = spawn(godotBin, args, { stdio: ['ignore', 'pipe', 'pipe'] });

    child.stdout.on('data', (chunk: Buffer) => stdoutChunks.push(chunk));
    child.stderr.on('data', (chunk: Buffer) => stderrChunks.push(chunk));

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
      // Escalate to SIGKILL after a short grace period if still alive.
      setTimeout(() => child.kill('SIGKILL'), 2_000);
    }, timeoutMs);

    child.on('error', (err) => {
      clearTimeout(timer);
      reject(new Error(`Failed to spawn Godot (${godotBin}): ${err.message}`));
    });

    child.on('close', (code) => {
      clearTimeout(timer);
      const duration_ms = Date.now() - startedAt;

      const stdout = Buffer.concat(stdoutChunks).toString('utf8');
      const stderr = Buffer.concat(stderrChunks).toString('utf8');

      // When timed out, treat exit as clean (Godot ran long enough to validate).
      const exitCode = timedOut ? 0 : (code ?? 0);

      const combined = stdout + '\n' + stderr;
      const { errors, warnings, crashed } = parseLines(combined);

      resolve({ exitCode, crashed, stdout, stderr, errors, warnings, duration_ms });
    });
  });
}
