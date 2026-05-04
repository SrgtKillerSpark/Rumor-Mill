# GDScript Parse-Error Guard

Two automated gates prevent GDScript parse errors from reaching `main`:

## 1. Pre-commit hook (local)

Validates all staged `.gd` files by running Godot headless before commit.

**Install (one command):**

```bash
./rumor_mill/tools/install-hooks.sh
```

**Requirements:** Godot 4.x on PATH (or set `GODOT_BIN=/path/to/godot4`).

**What it catches:** any `ERROR`, `SCRIPT ERROR`, or `Parse error` that references a `res://` path during headless project load.

**Bypass (emergency only):**

```bash
git commit --no-verify -m "emergency: reason for bypass"
```

You almost never should bypass. The only valid cases:
- Godot binary is unavailable on this machine (hook soft-fails automatically).
- You are committing non-GDScript files only (hook auto-skips).
- A known engine bug produces a false positive (document in commit message).

## 2. CI smoke-launch (remote)

The `validate-gdscript.yml` workflow runs on every push to `main`/`dev` and on PRs touching scripts/scenes. It has two steps:

1. **GDScript validation** — static headless parse check (same as pre-commit).
2. **Smoke-launch** — boots the main scene (`res://scenes/Main.tscn`) headless and asserts no parse failures or autoload crashes occurred during `_ready`.

The smoke-launch catches errors the static check cannot: autoload init order, scene preload failures, and cross-script dependency breaks that only manifest at runtime.

## What classes of failure these guards catch

| Failure class | Pre-commit | CI smoke-launch |
|---|:---:|:---:|
| Syntax errors / typos in `.gd` | ✓ | ✓ |
| `:=` type inference on complex expressions | ✓ | ✓ |
| Orphaned code fragments (partial edits) | ✓ | ✓ |
| Missing constant/member references | ✓ | ✓ |
| Autoload init-order crashes | — | ✓ |
| Scene preload failures | — | ✓ |
| Missing DLL/plugin (conditional) | — | ✓ |
| Runtime logic bugs | — | — |

## Troubleshooting

- **Hook says "Godot binary not found"** — install Godot 4.x or `export GODOT_BIN=...`
- **False positive from engine noise** — the filter only flags lines matching `res://` paths; generic engine shutdown warnings are excluded.
- **CI fails but local passes** — likely an OS-specific path issue or asset that wasn't committed. Check the workflow log.
