#!/usr/bin/env bash
# promote-to-stable.sh — Validate main via Godot headless, then fast-forward stable.
# Usage: bash tools/promote-to-stable.sh
# Exit codes: 0 = promoted, 1 = validation failed, 2 = setup error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/rumor_mill"
STABLE_WORKTREE="$(cd "$REPO_ROOT/../Rumor-Mill-Stable" 2>/dev/null && pwd)" || true
GODOT_BIN="${GODOT_BIN:-C:/Users/KAOS/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe}"
TIMEOUT_SEC="${TIMEOUT_SEC:-60}"

# ── Preflight checks ─────────────────────────────────────────────────────────

if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
  echo "ERROR: project.godot not found at $PROJECT_DIR" >&2
  exit 2
fi

if [[ ! -f "$GODOT_BIN" ]]; then
  echo "ERROR: Godot binary not found at $GODOT_BIN" >&2
  exit 2
fi

if [[ -z "$STABLE_WORKTREE" || ! -d "$STABLE_WORKTREE" ]]; then
  echo "ERROR: Stable worktree not found at $REPO_ROOT/../Rumor-Mill-Stable" >&2
  exit 2
fi

# ── Run Godot headless validation ─────────────────────────────────────────────

echo "=== Validating GDScript on main branch ==="
echo "Project: $PROJECT_DIR"
echo "Godot:   $GODOT_BIN"
echo ""

VALIDATION_OUTPUT=$(timeout "$TIMEOUT_SEC" "$GODOT_BIN" --headless --path "$PROJECT_DIR" --quit 2>&1) || true

# Count errors (matching Godot's structured error output, excluding known-benign GodotSteam extension errors)
ERROR_LINES=$(echo "$VALIDATION_OUTPUT" | grep -E "^(ERROR|SCRIPT ERROR).*res://|^Parse error:" | grep -cvE "godotsteam" || true)
WARNING_LINES=$(echo "$VALIDATION_OUTPUT" | grep -cE "^WARNING:.*res://" || true)

echo "=== Validation Results ==="
echo "Errors:   $ERROR_LINES"
echo "Warnings: $WARNING_LINES"
echo ""

if [[ "$ERROR_LINES" -gt 0 ]]; then
  echo "=== ERRORS FOUND — stable NOT updated ==="
  echo ""
  echo "$VALIDATION_OUTPUT" | grep -E "^(ERROR|SCRIPT ERROR).*res://|^Parse error:" | grep -vE "godotsteam" || true
  echo ""
  echo "Fix the errors above on main, then re-run this script."
  exit 1
fi

# ── Promote main → stable ────────────────────────────────────────────────────

MAIN_SHA=$(git -C "$REPO_ROOT" rev-parse main)
STABLE_SHA=$(git -C "$REPO_ROOT" rev-parse stable)

if [[ "$MAIN_SHA" == "$STABLE_SHA" ]]; then
  echo "stable is already at main ($MAIN_SHA). Nothing to do."
  exit 0
fi

echo "Promoting main ($MAIN_SHA) → stable..."

# Update the stable branch ref to point at main
git -C "$REPO_ROOT" update-ref refs/heads/stable "$MAIN_SHA"

# Update the stable worktree to match
git -C "$STABLE_WORKTREE" checkout --force stable
git -C "$STABLE_WORKTREE" reset --hard stable

NEW_STABLE_SHA=$(git -C "$STABLE_WORKTREE" rev-parse HEAD)
echo ""
echo "=== SUCCESS ==="
echo "stable branch updated to $NEW_STABLE_SHA"
echo "Stable worktree: $STABLE_WORKTREE"
echo "Board can open: $STABLE_WORKTREE/rumor_mill"
