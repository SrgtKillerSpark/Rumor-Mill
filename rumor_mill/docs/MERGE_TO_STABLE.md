# Merge-to-Stable Process

The `stable` branch is what the board tests. Only merge to it when validation passes.

## Quick start

```bash
# From the repo root, with Godot on PATH:
./rumor_mill/tools/merge-to-stable.sh

# Specify Godot binary manually:
./rumor_mill/tools/merge-to-stable.sh --godot /path/to/godot4

# Validate only (no merge):
./rumor_mill/tools/merge-to-stable.sh --dry-run
```

The script will:
1. Abort if there are uncommitted changes.
2. Run `validate_gdscript.sh` headlessly against the `main` branch project.
3. If zero errors → fast-forward merge `main` into `stable`.
4. Return you to your previous branch.

## Rules

| Rule | Why |
|------|-----|
| Validation must pass (exit 0) before any merge | Prevents broken GDScript from reaching the test branch |
| Merge is **fast-forward only** | Keeps `stable` a clean subset of `main`; no merge commits |
| Only merge from `main` | Feature branches must be merged to `main` first |
| Working tree must be clean | Avoids accidental inclusion of work-in-progress |

## When validation fails

Read the error lines printed by `validate_gdscript.sh`, fix the offending scripts on `main`, commit the fix, then re-run `merge-to-stable.sh`.

## Stable worktree

A linked worktree exists at `../Rumor-Mill-Stable/` (sibling of the main repo folder). The board opens the project from that folder. After a successful merge the worktree automatically reflects the new `stable` HEAD — no separate checkout is needed.

## Godot binary

`validate_gdscript.sh` auto-detects common install locations. If detection fails, set the `GODOT_BIN` environment variable or pass `--godot <path>` to both scripts. The binary must be Godot 4.1+ (required for `--check-only`).
