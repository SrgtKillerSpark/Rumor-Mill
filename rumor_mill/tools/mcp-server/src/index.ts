#!/usr/bin/env node
/**
 * Godot MCP Server — exposes Godot project tools to agents via the Model Context Protocol.
 * Transport: stdio
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import * as path from "path";
import * as fs from "fs";

import { parseTscn } from "./lib/tscn-parser.js";
import { runHeadless, findGodotBinary } from "./lib/godot-runner.js";
import {
  isPathSafe,
  scanResReferences,
  globProject,
  resolveResPath,
  findProjectRoot,
} from "./lib/project-paths.js";

// Resolve project root — env override, or walk up from cwd
const PROJECT_ROOT = process.env["GODOT_PROJECT_ROOT"]
  ? path.resolve(process.env["GODOT_PROJECT_ROOT"])
  : (() => {
      try {
        return findProjectRoot();
      } catch {
        // Fallback: three levels up from this file (tools/mcp-server/src -> rumor_mill)
        return path.resolve(import.meta.dirname, "..", "..", "..");
      }
    })();

const server = new McpServer({
  name: "godot-mcp",
  version: "0.1.0",
});

// ── Helper: parse project.godot ──────────────────────────────────────────

function parseProjectGodot(): Record<string, Record<string, string>> {
  const configPath = path.join(PROJECT_ROOT, "project.godot");
  if (!fs.existsSync(configPath)) return {};

  const content = fs.readFileSync(configPath, "utf-8");
  const sections: Record<string, Record<string, string>> = {};
  let currentSection = "";

  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith(";")) continue;

    const sectionMatch = trimmed.match(/^\[(.+)\]$/);
    if (sectionMatch) {
      currentSection = sectionMatch[1];
      if (!sections[currentSection]) sections[currentSection] = {};
      continue;
    }

    const kvMatch = trimmed.match(/^([^=]+)=(.+)$/);
    if (kvMatch && currentSection) {
      sections[currentSection][kvMatch[1].trim()] = kvMatch[2].trim();
    }
  }

  return sections;
}

interface AutoloadEntry {
  name: string;
  path: string;
  enabled: boolean;
}

function getAutoloads(): AutoloadEntry[] {
  const config = parseProjectGodot();
  const autoloadSection = config["autoload"] || {};
  const entries: AutoloadEntry[] = [];

  for (const [name, value] of Object.entries(autoloadSection)) {
    const cleaned = value.replace(/^"|"$/g, "");
    const enabled = cleaned.startsWith("*");
    const resPath = enabled ? cleaned.slice(1) : cleaned;
    entries.push({ name, path: resPath, enabled });
  }

  return entries;
}

// ── Tool: validate_scripts ──────────────────────────────────────────

server.tool(
  "validate_scripts",
  "Run GDScript parse validation across the project headlessly. Returns structured error report.",
  {
    timeout_seconds: z.number().optional().describe("Godot process timeout (default 60)"),
  },
  async ({ timeout_seconds }) => {
    const timeout = (timeout_seconds ?? 60) * 1000;
    const result = await runHeadless(PROJECT_ROOT, {
      timeoutMs: timeout,
      extraArgs: ["--quit-after", "1", "--check-only"],
    });
    const validation = {
      passed: result.errors.length === 0,
      errors: result.errors,
      warnings: result.warnings,
      errorCount: result.errors.length,
      warningCount: result.warnings.length,
      crashed: result.crashed,
      duration_ms: result.duration_ms,
    };
    return {
      content: [{ type: "text" as const, text: JSON.stringify(validation, null, 2) }],
    };
  },
);

// ── Tool: launch_headless ───────────────────────────────────────────

server.tool(
  "launch_headless",
  "Start the game in headless mode, capture stdout/stderr, detect crashes.",
  {
    timeout_seconds: z.number().optional().describe("Max runtime in seconds (default 30)"),
    scene: z.string().optional().describe("Scene path to run (e.g. res://scenes/Main.tscn)"),
  },
  async ({ timeout_seconds, scene }) => {
    const extraArgs: string[] = [];
    if (scene) extraArgs.push(scene);

    const result = await runHeadless(PROJECT_ROOT, {
      timeoutMs: (timeout_seconds ?? 30) * 1000,
      extraArgs,
    });
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              exitCode: result.exitCode,
              crashed: result.crashed,
              duration_ms: result.duration_ms,
              errors: result.errors,
              warnings: result.warnings,
              stdout: result.stdout.slice(0, 10_000),
              stderr: result.stderr.slice(0, 10_000),
            },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ── Tool: inspect_scene_tree ────────────────────────────────────────

server.tool(
  "inspect_scene_tree",
  "Parse a .tscn file and return the node hierarchy with scripts and properties.",
  {
    scene_path: z
      .string()
      .describe('Scene path (e.g. "scenes/Main.tscn" or "res://scenes/Main.tscn")'),
  },
  async ({ scene_path }) => {
    if (!isPathSafe(scene_path, PROJECT_ROOT)) {
      return {
        content: [{ type: "text" as const, text: "Error: path outside project root" }],
        isError: true,
      };
    }

    const absPath = scene_path.startsWith("res://")
      ? resolveResPath(scene_path, PROJECT_ROOT)
      : path.resolve(PROJECT_ROOT, scene_path);

    if (!fs.existsSync(absPath)) {
      return {
        content: [{ type: "text" as const, text: `Error: file not found: ${scene_path}` }],
        isError: true,
      };
    }

    const content = fs.readFileSync(absPath, "utf-8");
    const parsed = parseTscn(content);
    return {
      content: [{ type: "text" as const, text: JSON.stringify(parsed, null, 2) }],
    };
  },
);

// ── Tool: validate_project ──────────────────────────────────────────

server.tool(
  "validate_project",
  "Verify all referenced resources exist — checks .tscn, .gd, autoloads, and export presets for broken res:// references.",
  {},
  async () => {
    const extensions = [".tscn", ".gd", ".tres", ".cfg"];
    const missing: { source_file: string; referenced_path: string; line: number }[] = [];
    let totalChecked = 0;

    // Scan all relevant files for res:// references
    for (const ext of extensions) {
      const files = globProject(PROJECT_ROOT, `**/*${ext}`);
      for (const absFile of files) {
        let content: string;
        try {
          content = fs.readFileSync(absFile, "utf-8");
        } catch {
          continue;
        }

        const refs = scanResReferences(content);
        const relFile = path.relative(PROJECT_ROOT, absFile).split(path.sep).join("/");

        for (const ref of refs) {
          totalChecked++;
          const resolvedPath = resolveResPath(ref.path, PROJECT_ROOT);
          if (!fs.existsSync(resolvedPath)) {
            missing.push({
              source_file: relFile,
              referenced_path: ref.path,
              line: ref.line,
            });
          }
        }
      }
    }

    // Also check autoloads
    const autoloads = getAutoloads();
    for (const al of autoloads) {
      totalChecked++;
      const resolvedPath = resolveResPath(al.path, PROJECT_ROOT);
      if (!fs.existsSync(resolvedPath)) {
        missing.push({
          source_file: "project.godot",
          referenced_path: al.path,
          line: 0,
        });
      }
    }

    const result = {
      valid: missing.length === 0,
      missing,
      checked_count: totalChecked,
    };

    return {
      content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
    };
  },
);

// ── Tool: list_scripts ──────────────────────────────────────────────

server.tool(
  "list_scripts",
  "List all GDScript files with metadata (class_name, extends, signals, exports).",
  {
    filter: z.string().optional().describe('Glob filter (e.g. "*engine*")'),
  },
  async ({ filter }) => {
    const pattern = filter ? `**/${filter}.gd` : "**/*.gd";
    const files = globProject(PROJECT_ROOT, pattern);

    const scripts = files.map((absFile) => {
      const relPath = path.relative(PROJECT_ROOT, absFile).split(path.sep).join("/");
      let content: string;
      try {
        content = fs.readFileSync(absFile, "utf-8");
      } catch {
        return { path: relPath, error: "Could not read file" };
      }

      const lines = content.split(/\r?\n/);
      const classNameMatch = content.match(/^class_name\s+(\w+)/m);
      const extendsMatch = content.match(/^extends\s+(\w+)/m);
      const signals = lines
        .filter((l) => l.match(/^signal\s+/))
        .map((l) => l.replace(/^signal\s+/, "").trim());
      const exports = lines
        .filter((l) => l.match(/^@export/))
        .map((l) => l.trim());

      return {
        path: relPath,
        class_name: classNameMatch?.[1],
        extends: extendsMatch?.[1],
        signals,
        exports,
        line_count: lines.length,
      };
    });

    return {
      content: [{ type: "text" as const, text: JSON.stringify(scripts, null, 2) }],
    };
  },
);

// ── Tool: read_file ─────────────────────────────────────────────────

server.tool(
  "read_file",
  "Read any project file with optional line range. Restricted to project directory.",
  {
    path: z.string().describe("File path relative to project root or res:// path"),
    start_line: z.number().optional().describe("Start line (1-based)"),
    end_line: z.number().optional().describe("End line (1-based, inclusive)"),
  },
  async ({ path: filePath, start_line, end_line }) => {
    if (!isPathSafe(filePath, PROJECT_ROOT)) {
      return {
        content: [{ type: "text" as const, text: "Error: path outside project root" }],
        isError: true,
      };
    }

    const absPath = filePath.startsWith("res://")
      ? resolveResPath(filePath, PROJECT_ROOT)
      : path.resolve(PROJECT_ROOT, filePath);

    if (!fs.existsSync(absPath)) {
      return {
        content: [{ type: "text" as const, text: `Error: file not found: ${filePath}` }],
        isError: true,
      };
    }

    const content = fs.readFileSync(absPath, "utf-8");
    const allLines = content.split(/\r?\n/);
    const total = allLines.length;

    let output: string;
    if (start_line || end_line) {
      const start = Math.max(1, start_line ?? 1);
      const end = Math.min(total, end_line ?? total);
      output = allLines.slice(start - 1, end).join("\n");
    } else {
      output = content;
    }

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({ content: output, total_lines: total }, null, 2),
        },
      ],
    };
  },
);

// ── Resource: godot://project/config ────────────────────────────────

server.resource(
  "project-config",
  "godot://project/config",
  {
    description:
      "Parsed project.godot as structured JSON (name, version, main_scene, autoloads, display settings)",
    mimeType: "application/json",
  },
  async () => {
    const config = parseProjectGodot();
    const app = config["application"] || {};
    const display = config["display"] || {};
    const autoloads = getAutoloads();

    const result = {
      name: app["config/name"]?.replace(/^"|"$/g, ""),
      version: app["config/version"]?.replace(/^"|"$/g, ""),
      description: app["config/description"]?.replace(/^"|"$/g, ""),
      main_scene: app["run/main_scene"]?.replace(/^"|"$/g, ""),
      features: app["config/features"],
      display: {
        viewport_width: display["window/size/viewport_width"],
        viewport_height: display["window/size/viewport_height"],
      },
      autoloads,
    };

    return {
      contents: [
        {
          uri: "godot://project/config",
          mimeType: "application/json",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  },
);

// ── Resource: godot://project/scenes ────────────────────────────────

server.resource(
  "project-scenes",
  "godot://project/scenes",
  {
    description: "List of all .tscn files with root node type and script",
    mimeType: "application/json",
  },
  async () => {
    const files = globProject(PROJECT_ROOT, "**/*.tscn");
    const scenes = files.map((absFile) => {
      const relPath = path.relative(PROJECT_ROOT, absFile).split(path.sep).join("/");
      try {
        const content = fs.readFileSync(absFile, "utf-8");
        const parsed = parseTscn(content);
        return {
          path: relPath,
          root_name: parsed.root.name,
          root_type: parsed.root.type,
          root_script: parsed.root.script,
          node_count: countNodes(parsed.root),
          ext_resources: parsed.extResources.length,
        };
      } catch {
        return { path: relPath, error: "Failed to parse" };
      }
    });

    return {
      contents: [
        {
          uri: "godot://project/scenes",
          mimeType: "application/json",
          text: JSON.stringify(scenes, null, 2),
        },
      ],
    };
  },
);

function countNodes(node: { children: { children: any[] }[] }): number {
  return 1 + node.children.reduce((sum, c) => sum + countNodes(c), 0);
}

// ── Resource: godot://project/data ──────────────────────────────────

server.resource(
  "project-data",
  "godot://project/data",
  {
    description: "Inventory of data files (JSON) with schema summary",
    mimeType: "application/json",
  },
  async () => {
    const files = globProject(PROJECT_ROOT, "data/**/*.json");
    const inventory = files.map((absFile) => {
      const relPath = path.relative(PROJECT_ROOT, absFile).split(path.sep).join("/");
      try {
        const raw = fs.readFileSync(absFile, "utf-8");
        const parsed = JSON.parse(raw);
        const topKeys = Object.keys(parsed);
        const summary: Record<string, string> = {};
        for (const key of topKeys) {
          const val = parsed[key];
          if (Array.isArray(val)) {
            summary[key] = `array[${val.length}]`;
          } else if (typeof val === "object" && val !== null) {
            summary[key] = `object{${Object.keys(val).length} keys}`;
          } else {
            summary[key] = typeof val;
          }
        }
        return { path: relPath, top_level_keys: topKeys, schema: summary };
      } catch {
        return { path: relPath, error: "Failed to parse JSON" };
      }
    });

    return {
      contents: [
        {
          uri: "godot://project/data",
          mimeType: "application/json",
          text: JSON.stringify(inventory, null, 2),
        },
      ],
    };
  },
);

// ── Start server ────────────────────────────────────────────────────

async function main() {
  const godot = findGodotBinary();
  console.error(`[godot-mcp] Project root: ${PROJECT_ROOT}`);
  console.error(`[godot-mcp] Godot binary: ${godot ?? "not found (headless tools disabled)"}`);

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("[godot-mcp] Fatal:", err);
  process.exit(1);
});
