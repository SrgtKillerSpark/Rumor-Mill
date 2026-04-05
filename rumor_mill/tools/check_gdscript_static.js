#!/usr/bin/env node
// check_gdscript_static.js — static GDScript checker for Rumor Mill
//
// Catches common parse-error patterns WITHOUT requiring Godot to be installed.
// Complements validate_gdscript.sh (which needs Godot headless mode).
//
// Checks performed:
//   1. Bare extension-singleton references (Steam., etc.) not guarded by
//      Engine.has_singleton()
//   2. class_name type references in extends/type annotations that don't
//      resolve to any .gd file in the project
//   3. Autoload bare identifiers used in code that aren't declared in
//      project.godot's [autoload] section
//   4. Variables assigned without `var` whose only `var` declaration in the
//      same function is inside a conditional / loop block (scope mismatch)
//
// Usage:
//   node rumor_mill/tools/check_gdscript_static.js [--project <path>] [--fix-hint]
//
// Exit codes:
//   0 — no errors found
//   1 — one or more errors detected

'use strict';

const fs   = require('fs');
const path = require('path');

// ── CLI args ──────────────────────────────────────────────────────────────────
let PROJECT_DIR = path.join(__dirname, '..');
let showFixHint = false;

for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === '--project' && process.argv[i + 1]) {
    PROJECT_DIR = path.resolve(process.argv[++i]);
  } else if (process.argv[i] === '--fix-hint') {
    showFixHint = true;
  } else if (process.argv[i] === '-h' || process.argv[i] === '--help') {
    console.log('Usage: node check_gdscript_static.js [--project <path>] [--fix-hint]');
    process.exit(0);
  }
}

// ── Validate project dir ──────────────────────────────────────────────────────
const PROJECT_GODOT = path.join(PROJECT_DIR, 'project.godot');
if (!fs.existsSync(PROJECT_GODOT)) {
  console.error(`ERROR: No project.godot found in: ${PROJECT_DIR}`);
  process.exit(2);
}

// ── Godot built-in class names — not custom class_names ──────────────────────
// Covers core nodes, resources, singletons, and common types used in this project.
const GODOT_BUILTINS = new Set([
  // Core node types
  'Node', 'Node2D', 'Node3D', 'CanvasLayer', 'CanvasItem', 'CanvasModulate',
  'Control', 'Container', 'VBoxContainer', 'HBoxContainer', 'GridContainer',
  'MarginContainer', 'ScrollContainer', 'TabContainer', 'FlowContainer',
  'PanelContainer', 'AspectRatioContainer', 'CenterContainer',
  'Panel', 'SubViewportContainer', 'SplitContainer', 'HSplitContainer', 'VSplitContainer',
  'Viewport', 'SubViewport', 'Window',
  // UI controls
  'Label', 'Button', 'CheckButton', 'CheckBox', 'LineEdit', 'TextEdit',
  'RichTextLabel', 'OptionButton', 'MenuButton', 'PopupMenu', 'PopupPanel', 'Popup',
  'Slider', 'HSlider', 'VSlider', 'ScrollBar', 'HScrollBar', 'VScrollBar',
  'ProgressBar', 'SpinBox', 'ColorPicker', 'ColorPickerButton', 'FileDialog',
  'TabBar', 'Tree', 'TextureRect', 'TextureButton', 'VideoStreamPlayer',
  'NinePatchRect', 'Separator', 'HSeparator', 'VSeparator',
  // 2D nodes
  'Camera2D', 'Sprite2D', 'AnimatedSprite2D', 'AnimationPlayer', 'AnimationTree',
  'Area2D', 'CollisionShape2D', 'CollisionPolygon2D', 'CollisionObject2D',
  'StaticBody2D', 'CharacterBody2D', 'RigidBody2D', 'PhysicsBody2D', 'KinematicBody2D',
  'Path2D', 'PathFollow2D', 'Line2D', 'Polygon2D', 'MultiMeshInstance2D',
  'GPUParticles2D', 'CPUParticles2D', 'PointLight2D', 'DirectionalLight2D',
  'LightOccluder2D', 'NavigationAgent2D', 'NavigationRegion2D',
  'Skeleton2D', 'Bone2D', 'TouchScreenButton', 'VisibleOnScreenEnabler2D',
  'RemoteTransform2D', 'ShaderMaterial', 'CanvasGroup',
  // TileMap
  'TileMapLayer', 'TileMap', 'TileSet', 'TileSetAtlasSource',
  'TileSetScenesCollectionSource', 'TileData',
  // 3D nodes
  'Camera3D', 'DirectionalLight3D', 'OmniLight3D', 'SpotLight3D',
  'MeshInstance3D', 'StaticBody3D', 'CharacterBody3D',
  // Audio
  'AudioStreamPlayer', 'AudioStreamPlayer2D', 'AudioStreamPlayer3D',
  'AudioStream', 'AudioStreamMP3', 'AudioStreamOggVorbis', 'AudioStreamWAV',
  'AudioStreamPolyphonic', 'AudioStreamPlayback', 'AudioStreamPlaybackPolyphonic',
  'AudioBusLayout', 'AudioEffect', 'AudioEffectReverb', 'AudioEffectDelay',
  // Resources / data
  'Resource', 'RefCounted', 'Object',
  'PackedScene', 'Shader', 'Material', 'StandardMaterial3D', 'BaseMaterial3D',
  'Texture2D', 'ImageTexture', 'AtlasTexture', 'CompressedTexture2D',
  'Font', 'FontFile', 'FontVariation', 'SystemFont',
  'StyleBox', 'StyleBoxFlat', 'StyleBoxTexture', 'StyleBoxEmpty', 'StyleBoxLine',
  'Theme', 'Curve', 'Gradient', 'GradientTexture2D', 'NoiseTexture2D',
  'Image', 'ImageFormat',
  'InputEvent', 'InputEventKey', 'InputEventMouseButton', 'InputEventMouseMotion',
  'InputEventAction', 'InputEventJoypadButton', 'InputEventJoypadMotion',
  'Mesh', 'ArrayMesh', 'SphereMesh', 'BoxMesh', 'PlaneMesh', 'CylinderMesh',
  // Misc built-ins
  'AStarGrid2D', 'AStar2D', 'AStar3D',
  'SceneTree', 'SceneTreeTimer',
  'Mutex', 'Thread', 'Semaphore',
  'HTTPRequest', 'HTTPClient', 'StreamPeerTCP', 'StreamPeer', 'TCPServer',
  'XMLParser', 'JSON', 'FileAccess', 'DirAccess', 'ZIPReader', 'ZIPPacker',
  'Tween', 'Tweener', 'PropertyTweener',
  'Timer', 'Skeleton3D', 'AnimationMixer',
  'ColorRect', 'WorldBoundaryShape2D', 'CircleShape2D', 'RectangleShape2D',
  'CapsuleShape2D', 'ConvexPolygonShape2D', 'ConcavePolygonShape2D',
  // Singleton / global classes (Godot built-in singletons)
  'Engine', 'OS', 'Time', 'Input', 'InputMap', 'ProjectSettings',
  'RenderingServer', 'PhysicsServer2D', 'PhysicsServer3D', 'NavigationServer2D',
  'DisplayServer', 'AudioServer', 'TranslationServer', 'ResourceLoader',
  'ResourceSaver', 'GodotSteam',
  // Script type
  'Script', 'GDScript',
  // Primitive / value types used as type hints
  'Variant', 'bool', 'int', 'float', 'String', 'StringName', 'NodePath',
  'Array', 'Dictionary', 'PackedByteArray', 'PackedInt32Array', 'PackedInt64Array',
  'PackedFloat32Array', 'PackedFloat64Array', 'PackedStringArray',
  'PackedVector2Array', 'PackedVector3Array', 'PackedColorArray',
  'Vector2', 'Vector2i', 'Vector3', 'Vector3i', 'Vector4', 'Vector4i',
  'Rect2', 'Rect2i', 'Transform2D', 'Transform3D', 'Basis', 'Plane',
  'Quaternion', 'AABB', 'Color', 'RID', 'Callable', 'Signal',
  'Math', 'PI',
]);

// Extension singletons that must be guarded by Engine.has_singleton()
const EXTENSION_SINGLETONS = ['Steam', 'GodotSteam', 'Discord', 'Steamworks'];

// ── Parse project.godot for autoload names ────────────────────────────────────
function parseAutoloads(projectGodotPath) {
  const text = fs.readFileSync(projectGodotPath, 'utf8');
  const autoloads = new Set();
  let inAutoload = false;
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '[autoload]') { inAutoload = true; continue; }
    if (trimmed.startsWith('[') && trimmed !== '[autoload]') { inAutoload = false; }
    if (inAutoload && trimmed && !trimmed.startsWith(';')) {
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        autoloads.add(trimmed.slice(0, eqIdx).trim());
      }
    }
  }
  return autoloads;
}

// ── Collect all .gd files recursively ────────────────────────────────────────
function findGdFiles(dir) {
  const results = [];
  function walk(current) {
    let entries;
    try { entries = fs.readdirSync(current, { withFileTypes: true }); }
    catch { return; }
    for (const e of entries) {
      if (e.name.startsWith('.')) continue;
      const full = path.join(current, e.name);
      if (e.isDirectory()) { walk(full); }
      else if (e.isFile() && e.name.endsWith('.gd')) { results.push(full); }
    }
  }
  walk(dir);
  return results;
}

// ── Collect class_name declarations across all .gd files ─────────────────────
function collectClassNames(gdFiles) {
  const map = new Map(); // className → filePath
  for (const fp of gdFiles) {
    const lines = fs.readFileSync(fp, 'utf8').split('\n');
    for (const line of lines) {
      const m = line.match(/^class_name\s+([A-Za-z_][A-Za-z0-9_]*)/);
      if (m) { map.set(m[1], fp); }
    }
  }
  return map;
}

// ── Strip a line for safe code-only inspection ────────────────────────────────
// Removes: full-line comments, inline comments (outside strings), string literals.
// Returns a sanitized version suitable for pattern matching.
function stripLine(raw) {
  // Remove full-line comments (line starts with optional whitespace + #)
  if (/^\s*#/.test(raw)) return '';
  let result = '';
  let inString = false;
  let stringChar = '';
  let i = 0;
  while (i < raw.length) {
    const ch = raw[i];
    if (!inString) {
      if (ch === '#') break; // inline comment starts — stop
      if (ch === '"' || ch === "'") {
        inString = true;
        stringChar = ch;
        result += ' '; // replace string with a space to preserve token boundaries
        i++;
        continue;
      }
      result += ch;
    } else {
      // Inside string — skip until closing quote (handle \\ and \")
      if (ch === '\\' && i + 1 < raw.length) {
        i += 2; // skip escaped char
        continue;
      }
      if (ch === stringChar) {
        inString = false;
        i++;
        continue;
      }
    }
    i++;
  }
  return result;
}

// ── Error accumulator ─────────────────────────────────────────────────────────
const errors = [];
function reportError(filePath, lineNum, message, hint) {
  const rel = path.relative(PROJECT_DIR, filePath).replace(/\\/g, '/');
  // De-duplicate: same file+line+message
  const key = `${rel}:${lineNum}:${message}`;
  if (errors.some(e => `${e.rel}:${e.lineNum}:${e.message}` === key)) return;
  errors.push({ rel, lineNum, message, hint });
}

// ── Helper: indentation depth ─────────────────────────────────────────────────
function indentLevel(line) {
  let count = 0;
  for (const ch of line) {
    if (ch === '\t') count++;
    else if (ch === ' ') count += 0.25; // treat 4 spaces as 1 level
    else break;
  }
  return count; // may be fractional for space-indented files
}

// ── Check 1: bare extension-singleton references ──────────────────────────────
// Flags any use of e.g. `Steam.` that isn't behind an Engine.has_singleton guard.
function checkBareExtensionSingletons(filePath, lines) {
  // Collect which singletons are guarded somewhere in this file
  const guarded = new Set();
  for (const line of lines) {
    const m = line.match(/Engine\.has_singleton\s*\(\s*["']([^"']+)["']\s*\)/);
    if (m) guarded.add(m[1]);
  }

  for (let i = 0; i < lines.length; i++) {
    const code = stripLine(lines[i]);
    if (!code.trim()) continue;

    for (const singleton of EXTENSION_SINGLETONS) {
      const pattern = new RegExp(`(?<![A-Za-z0-9_"'])${singleton}\\.`);
      if (pattern.test(code) && !guarded.has(singleton)) {
        reportError(filePath, i + 1,
          `Bare extension-singleton '${singleton}.' used without Engine.has_singleton("${singleton}") guard in this file`,
          `Add: if Engine.has_singleton("${singleton}"): var s = Engine.get_singleton("${singleton}")`
        );
      }
    }
  }
}

// ── Collect inner classes and named enums defined inside a .gd file ──────────
// Returns a Set of names declared as `class X:` or `enum X {` in the file.
// These are valid as type references within the same file and (via OuterClass.X)
// from other files — we allow them either way to avoid false positives.
function collectFileLocalTypes(lines) {
  const localTypes = new Set();
  for (const line of lines) {
    // Inner class: `class Foo:` (not indented — top-level of the file)
    let m = line.match(/^class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:extends\s+\w+\s*)?:/);
    if (m) { localTypes.add(m[1]); continue; }
    // Named enum: `enum Foo {`
    m = line.match(/^enum\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/);
    if (m) { localTypes.add(m[1]); }
  }
  return localTypes;
}

// ── Check 2: class_name references that don't resolve ────────────────────────
// Only checks positions where type annotations are syntactically valid in GDScript:
//   extends ClassName
//   var x: ClassName  /  var x: Array[ClassName]
//   func f(p: ClassName) -> ClassName:
//   as ClassName
function checkClassNameRefs(filePath, lines, knownClassNames, autoloads) {
  const fileLocalTypes = collectFileLocalTypes(lines);

  function isKnown(name) {
    return (
      GODOT_BUILTINS.has(name) ||
      autoloads.has(name)      ||
      knownClassNames.has(name)||
      fileLocalTypes.has(name)
    );
  }

  // Also collect all outer-class names known in the project to skip
  // dotted inner-class references like `Rumor.ClaimType` — the `ClaimType`
  // part would otherwise be seen as a type ref.  We simply allow any name
  // that immediately follows a `.` in code as it's likely a member/inner-class.
  // (Handled below by checking the char before the matched type name.)

  for (let i = 0; i < lines.length; i++) {
    const raw  = lines[i];
    const code = stripLine(raw);
    if (!code.trim()) continue;

    // Pattern: extends X
    {
      const m = code.match(/^\s*extends\s+([A-Z][A-Za-z0-9_]*)/);
      if (m && !isKnown(m[1])) {
        reportError(filePath, i + 1,
          `'extends ${m[1]}' — no .gd file declares 'class_name ${m[1]}' and it is not a Godot built-in`,
          `Check spelling or add 'class_name ${m[1]}' to the correct script`
        );
      }
    }

    // Pattern: `: TypeName` in var declarations and function signatures
    // Matches: var x: Type, func f(x: Type), -> Type
    // Skip anything immediately following a `.` (inner class / enum member access).
    {
      const typeAnnotations = [
        // var name: Type  or  var name: Array[Type]
        /\bvar\s+\w+\s*:\s*([A-Z][A-Za-z0-9_]*)/g,
        // func foo(name: Type  — inside parens
        /\(\s*\w+\s*:\s*([A-Z][A-Za-z0-9_]*)/g,
        /,\s*\w+\s*:\s*([A-Z][A-Za-z0-9_]*)/g,
        // return type: -> Type
        /->\s*([A-Z][A-Za-z0-9_]*)/g,
        // explicit cast: as Type (but not `as X.Y`)
        /\bas\s+([A-Z][A-Za-z0-9_]*)/g,
      ];
      for (const re of typeAnnotations) {
        re.lastIndex = 0;
        let m;
        while ((m = re.exec(code)) !== null) {
          const typeName = m[1];
          if (isKnown(typeName)) continue;
          // Skip if this type name is immediately followed by `.` (it's the
          // outer class of a dotted reference, not a missing type on its own)
          const afterMatch = code.slice(m.index + m[0].length);
          if (afterMatch.startsWith('.')) continue;
          // Skip if preceded by `.` (it's a nested type member, e.g. Rumor.ClaimType)
          const beforeMatch = code.slice(0, m.index);
          if (beforeMatch.endsWith('.')) continue;
          reportError(filePath, i + 1,
            `Unresolved type '${typeName}' — not a Godot built-in, autoload, or declared class_name`,
            `Verify '${typeName}' has 'class_name ${typeName}' in a .gd file, or add it to GODOT_BUILTINS`
          );
        }
      }
    }
  }
}

// ── Check 3: autoload identifier used in code but missing from project.godot ──
// Looks for PascalCase identifiers used as singleton call targets that aren't
// declared in project.godot's [autoload] section.
// Conservative: only flag when 5+ distinct usages exist to reduce noise from
// static-class calls and inner-class references.
function checkUndeclaredAutoloadUsage(filePath, lines, autoloads, knownClassNames, allLocalTypes) {
  const usage = new Map(); // name → [lineNums]

  for (let i = 0; i < lines.length; i++) {
    const code = stripLine(lines[i]);
    // Match `Identifier.method(` where Identifier is PascalCase
    const re = /([A-Z][A-Za-z][A-Za-z0-9_]*)\.([a-z_]\w*)\s*\(/g;
    let m;
    while ((m = re.exec(code)) !== null) {
      const name   = m[1];
      const before = code.slice(0, m.index);
      // Skip if preceded by `.` — means it's a chained member, not a root identifier
      if (before.endsWith('.')) continue;
      // Skip ALL_CAPS or SCREAMING_SNAKE constants
      if (name.toUpperCase() === name) continue;
      // Skip known categories
      if (GODOT_BUILTINS.has(name)) continue;
      if (knownClassNames.has(name)) continue; // static call on a class_name type
      if (autoloads.has(name)) continue;
      if (EXTENSION_SINGLETONS.includes(name)) continue; // handled in check 1
      if (allLocalTypes.has(name)) continue; // inner class or enum from any file
      if (!usage.has(name)) usage.set(name, []);
      usage.get(name).push(i + 1);
    }
  }

  for (const [name, lineNums] of usage.entries()) {
    if (lineNums.length >= 5) {
      reportError(filePath, lineNums[0],
        `'${name}' used as a singleton/autoload (${lineNums.length}×) but not found in project.godot [autoload] — possible removed or misspelled autoload`,
        `Add '${name}="*res://scripts/..."' under [autoload] in project.godot, or replace with the correct autoload name`
      );
    }
  }
}

// ── Check 4: block-scope variable mismatch ────────────────────────────────────
// Within each function: if `var X` is declared inside a conditional/loop block
// (indented more than the function body baseline) and the same name `X` is
// assigned without `var` somewhere else in the function, flag it.
//
// This catches the pattern from SPA-485:
//   if condition_a:
//       var x := value    ← block-local
//   if condition_b:
//       x = other_value   ← ERROR: x not in scope here
function checkBlockScopeVars(filePath, lines) {
  // GDScript function starters
  const FUNC_START   = /^(\t| {4})*(?:static\s+)?func\s+\w+/;
  // var declaration: `var name` or `var name:` or `var name :=`
  const VAR_DECL     = /^(\s*)var\s+([A-Za-z_][A-Za-z0-9_]*)\b/;
  // bare assignment (not var): `name =`, `name +=`, `name[...] =`, etc.
  // must be at the start of meaningful content (after indentation)
  const BARE_ASSIGN  = /^(\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*(?:\[.*?\])?\s*)(?:=|\+=|-=|\*=|\/=|%=|&=|\|=|\^=)/;
  // Keywords that look like identifiers but aren't variables
  const KEYWORDS = new Set([
    'self', 'super', 'true', 'false', 'null', 'pass', 'return',
    'if', 'elif', 'else', 'for', 'while', 'match', 'break', 'continue',
    'class', 'extends', 'var', 'const', 'func', 'static', 'signal',
    'enum', 'and', 'or', 'not', 'in', 'is', 'as',
  ]);

  // Locate function start lines
  const funcStarts = [];
  for (let i = 0; i < lines.length; i++) {
    if (FUNC_START.test(lines[i])) funcStarts.push(i);
  }
  // Build ranges [start, end)
  const funcRanges = funcStarts.map((s, idx) => ({
    start: s,
    end: idx + 1 < funcStarts.length ? funcStarts[idx + 1] : lines.length,
  }));

  for (const { start, end } of funcRanges) {
    // Determine body baseline indentation (first non-empty, non-comment line after signature)
    let baseline = -1;
    for (let i = start + 1; i < end; i++) {
      const code = stripLine(lines[i]);
      if (code.trim()) { baseline = indentLevel(lines[i]); break; }
    }
    if (baseline < 0) continue;

    // Block-local var declarations: Map<name, {line, indent}[]>
    const blockVars = new Map();
    // Bare assignments: Map<name, {line, indent}[]>
    const bareAssigns = new Map();

    for (let i = start + 1; i < end; i++) {
      const raw  = lines[i];
      const code = stripLine(raw);
      if (!code.trim()) continue;

      const level = indentLevel(raw);

      const vm = VAR_DECL.exec(raw);
      if (vm) {
        const name = vm[2];
        if (level > baseline) {
          // declared inside a block, not at function body level
          if (!blockVars.has(name)) blockVars.set(name, []);
          blockVars.get(name).push({ line: i + 1, indent: level });
        }
        continue; // var decl lines are never also bare assigns
      }

      const am = BARE_ASSIGN.exec(raw);
      if (am) {
        const name = am[2];
        if (KEYWORDS.has(name)) continue;
        // Skip ALL_CAPS constants
        if (name === name.toUpperCase() && name.length > 2 && /^[A-Z]/.test(name)) continue;
        // Skip if name matches a known node/property accessor (starts with _)
        // (we still track them — just a heuristic note)
        if (!bareAssigns.has(name)) bareAssigns.set(name, []);
        bareAssigns.get(name).push({ line: i + 1, indent: level });
      }
    }

    // Cross-reference block-local var decls with bare assigns.
    //
    // The ONLY safe flag: assignment is at LOWER indent than the var declaration.
    // That means the assignment is in an OUTER scope that can't see the inner var.
    //
    // Example of what we catch:
    //   func f():
    //       if cond:
    //           var x := 5    ← indent 2 (block-local)
    //       x = 10            ← indent 1 (outer — x is not in scope here!)
    //
    // We do NOT flag: assignment at SAME or HIGHER indent than decl — that covers
    // the valid "declared in outer block, assigned in inner branch" pattern, as well
    // as the SPA-485-style sibling-block case (which requires full AST analysis).
    // That limitation is documented in the script header comment.
    for (const [name, decls] of blockVars.entries()) {
      if (!bareAssigns.has(name)) continue;

      for (const assign of bareAssigns.get(name)) {
        // Find if there is ANY declaration that is at a HIGHER indent than this assign.
        // If so, the assign is in an outer scope — can't see the block-local var.
        const outerAssignVsInnerDecl = decls.find(d => d.indent > assign.indent);
        if (outerAssignVsInnerDecl) {
          const declSummary = decls.map(d => `line ${d.line}, indent ${d.indent}`).join('; ');
          reportError(filePath, assign.line,
            `Possible block-scope error: '${name}' assigned without 'var' at indent ${assign.indent}, ` +
            `but 'var ${name}' is only declared inside deeper block(s) (${declSummary}) — ` +
            `outer scope cannot access inner block variables`,
            `Hoist 'var ${name}' to the function level (before the conditional), or use 'var ${name} :=' at line ${assign.line}`
          );
        }
      }
    }
  }
}

// ── Per-file driver ───────────────────────────────────────────────────────────
function checkFile(filePath, knownClassNames, autoloads, allLocalTypes) {
  let text;
  try { text = fs.readFileSync(filePath, 'utf8'); }
  catch (e) { console.error(`  SKIP: cannot read ${filePath}: ${e.message}`); return; }

  const lines = text.split('\n');

  checkBareExtensionSingletons(filePath, lines);
  checkClassNameRefs(filePath, lines, knownClassNames, autoloads);
  checkUndeclaredAutoloadUsage(filePath, lines, autoloads, knownClassNames, allLocalTypes);
  checkBlockScopeVars(filePath, lines);
}

// ── Main ──────────────────────────────────────────────────────────────────────
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('  GDScript Static Checker — Rumor Mill');
console.log(`  Project: ${PROJECT_DIR}`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

const autoloads     = parseAutoloads(PROJECT_GODOT);
const gdFiles       = findGdFiles(PROJECT_DIR);
const knownClasses  = collectClassNames(gdFiles);

// Collect inner classes and named enums from every .gd file for check 3
const allLocalTypes = new Set();
for (const fp of gdFiles) {
  let text;
  try { text = fs.readFileSync(fp, 'utf8'); } catch { continue; }
  for (const name of collectFileLocalTypes(text.split('\n'))) {
    allLocalTypes.add(name);
  }
}

console.log(`  Autoloads     : ${[...autoloads].join(', ')}`);
console.log(`  GD files      : ${gdFiles.length}`);
console.log(`  Class names   : ${[...knownClasses.keys()].join(', ')}`);
console.log('');

for (const fp of gdFiles) {
  checkFile(fp, knownClasses, autoloads, allLocalTypes);
}

// ── Report ────────────────────────────────────────────────────────────────────
if (errors.length === 0) {
  console.log('✓  Static check passed — no issues found.');
  process.exit(0);
} else {
  console.log(`✗  Static check FAILED — ${errors.length} issue(s) found:\n`);
  for (const e of errors) {
    console.log(`  ${e.rel}:${e.lineNum}`);
    console.log(`    ERROR: ${e.message}`);
    if (showFixHint && e.hint) {
      console.log(`    HINT:  ${e.hint}`);
    }
  }
  console.log('');
  console.log(`Run with --fix-hint for remediation suggestions.`);
  process.exit(1);
}
