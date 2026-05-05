# GDScript Parse-Error Guard

Three automated gates prevent GDScript parse errors from reaching `main`:

## 1. Pre-commit hook (local)

Validates all staged `.gd` files via two mechanisms before commit:

1. **Godot headless parse** — loads the full project to catch syntax/type errors.
2. **Static analysis** (`check_gdscript_static.js`) — catches UID mismatches, removed constants, unresolved types, and other patterns without requiring Godot.

**Install (one command):**

```bash
./rumor_mill/tools/install-hooks.sh
```

**Requirements:** Godot 4.x on PATH (or set `GODOT_BIN=/path/to/godot4`). Node.js for static analysis.

**What it catches:** any `ERROR`, `SCRIPT ERROR`, or `Parse error` that references a `res://` path during headless project load, plus all static analysis checks (see table below).

**Bypass (emergency only):**

```bash
git commit --no-verify -m "emergency: reason for bypass"
```

You almost never should bypass. The only valid cases:
- Godot binary is unavailable on this machine (hook soft-fails automatically).
- You are committing non-GDScript files only (hook auto-skips).
- A known engine bug produces a false positive (document in commit message).

## 2. Static analysis (`check_gdscript_static.js`)

A Node.js-based linter that runs **without Godot** and catches patterns the headless parse misses. Runs in both pre-commit and CI.

```bash
node rumor_mill/tools/check_gdscript_static.js [--project <path>] [--fix-hint]
```

**Checks performed:**
1. Bare extension-singleton references (Steam., etc.) without `Engine.has_singleton()` guard
2. Unresolved `class_name` type references in annotations
3. Undeclared autoload usage
4. Block-scope variable mismatches
5. Inferred-type with backslash continuation (SPA-1543)
6. **Missing `.uid` file for `class_name` declarations** (SPA-1677)
7. **Removed/missing constant references** — `ClassName.SCREAMING_CONST` not found in target (SPA-1678/1684)

## 3. CI smoke-launch (remote)

The `validate-gdscript.yml` workflow runs on every push to `main`/`dev` and on PRs touching `scripts/`, `scenes/`, `tools/`, `project.godot`, or the workflow file itself. It has three steps:

1. **Static analysis** — runs `check_gdscript_static.js` (checks 1–7).
2. **GDScript validation** — headless parse check via Godot.
3. **Smoke-launch** — boots the main scene (`res://scenes/Main.tscn`) headless and asserts no parse failures or autoload crashes occurred during `_ready`.

The smoke-launch catches errors the static check cannot: autoload init order, scene preload failures, and cross-script dependency breaks that only manifest at runtime.

## What classes of failure these guards catch

| Failure class | Static analysis | Pre-commit (Godot) | CI smoke-launch |
|---|:---:|:---:|:---:|
| Syntax errors / typos in `.gd` | — | ✓ | ✓ |
| `:=` type inference on complex expressions | ✓ (check 5) | ✓ | ✓ |
| Orphaned code fragments (partial edits) | — | ✓ | ✓ |
| Unresolved type annotations | ✓ (check 2) | ✓ | ✓ |
| Missing `.uid` for `class_name` (SPA-1677) | ✓ (check 6) | — | — |
| Removed/missing constant refs (SPA-1678) | ✓ (check 7) | — | ✓ |
| Bare extension-singleton usage | ✓ (check 1) | — | — |
| Undeclared autoload usage | ✓ (check 3) | — | — |
| Block-scope variable mismatch | ✓ (check 4) | — | — |
| Autoload init-order crashes | — | — | ✓ |
| Scene preload failures | — | — | ✓ |
| Missing DLL/plugin (conditional) | — | — | ✓ |
| Runtime logic bugs | — | — | — |

## Troubleshooting

- **Hook says "Godot binary not found"** — install Godot 4.x or `export GODOT_BIN=...`
- **False positive from engine noise** — the filter only flags lines matching `res://` paths; generic engine shutdown warnings are excluded.
- **CI fails but local passes** — likely an OS-specific path issue or asset that wasn't committed. Check the workflow log.
