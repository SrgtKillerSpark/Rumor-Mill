# GDScript Validation Hooks

## What it does

The pre-commit hook runs two checks when any `.gd` file is staged:

1. **Static analysis** (`rumor_mill/tools/check_gdscript_static.js`) — catches type-inference backslash traps, unresolved class names, bare singletons, and scope mismatches. Fast (~1-2s), requires only Node.js.
2. **Headless Godot validation** (`rumor_mill/tools/validate_gdscript.sh`) — loads the project in headless mode to catch parse errors the engine would reject. Requires Godot 4.x on PATH; skipped gracefully if not installed. Gated to ≤20 staged files for speed.

The pre-push hook re-runs the static analysis on all `.gd` files changed since upstream.

## Install

```bash
bash rumor_mill/tools/install_hooks.sh
```

Run once after cloning. Re-run after pulling changes to the hook script.

## Bypass (emergency commits)

```bash
git commit --no-verify -m "hotfix: ..."
```

Use sparingly — the hook exists to prevent parse errors from landing on `main`.

## Performance targets

| Check | Incremental (few files) | Full project |
|-------|------------------------|--------------|
| Static (Node.js) | < 2s | < 5s |
| Headless (Godot) | < 10s | skipped if >20 files |

If the headless step is consistently slow on your machine, ensure `GODOT_TIMEOUT` env var is set (default 60s) or rely on CI for full validation.
