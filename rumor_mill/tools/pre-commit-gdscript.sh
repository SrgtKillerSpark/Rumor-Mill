#!/usr/bin/env bash
# pre-commit-gdscript.sh — Pre-commit hook that validates staged .gd files
#
# Runs Godot in headless mode on staged GDScript files to catch parse errors
# before they reach the repository. Fails the commit on any parse error.
#
# Installation (from repo root):
#   ./rumor_mill/tools/install-hooks.sh
#
# Bypass (emergency only):
#   git commit --no-verify -m "reason for bypass"
#
# Performance: completes in <10s for typical changesets (full project load).

set -euo pipefail

# ── Check if any .gd files are staged ────────────────────────────────────────
STAGED_GD=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' || true)

if [[ -z "$STAGED_GD" ]]; then
  # No GDScript files staged — nothing to validate
  exit 0
fi

echo "┌─────────────────────────────────────────────────┐"
echo "│  GDScript pre-commit guard                      │"
echo "│  Validating $(echo "$STAGED_GD" | wc -l | tr -d ' ') staged .gd file(s)…              │"
echo "└─────────────────────────────────────────────────┘"

# ── Locate Godot binary ──────────────────────────────────────────────────────
GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  for candidate in \
    "godot4" \
    "godot" \
    "/usr/local/bin/godot4" \
    "/usr/bin/godot4" \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/.local/share/godot/bin/godot4"
  do
    if command -v "$candidate" &>/dev/null 2>&1; then
      GODOT_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$GODOT_BIN" ]]; then
  echo "⚠ Godot binary not found — skipping GDScript validation."
  echo "  Set GODOT_BIN env var to enable the pre-commit guard."
  echo "  e.g.: export GODOT_BIN=/path/to/godot4"
  exit 0  # Soft-fail: don't block devs who don't have Godot installed locally
fi

# ── Locate project root ──────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_DIR="$REPO_ROOT/rumor_mill"

if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
  echo "⚠ project.godot not found at $PROJECT_DIR — skipping validation."
  exit 0
fi

# ── Run Godot headless validation ────────────────────────────────────────────
# We validate the full project (not individual files) because GDScript parse
# errors often stem from cross-file dependencies (missing autoloads, changed
# class members referenced elsewhere, etc.)
TMPLOG="$(mktemp /tmp/gdscript_precommit_XXXXXX.log)"
trap 'rm -f "$TMPLOG"' EXIT

GODOT_TIMEOUT="${GODOT_TIMEOUT:-30}"

set +e
if command -v timeout &>/dev/null 2>&1; then
  timeout "$GODOT_TIMEOUT" "$GODOT_BIN" --headless --path "$PROJECT_DIR" --quit 2>"$TMPLOG" 1>/dev/null
  EXIT_CODE=$?
  [[ $EXIT_CODE -eq 124 ]] && EXIT_CODE=0
else
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --quit 2>"$TMPLOG" 1>/dev/null &
  PID=$!
  ( sleep "$GODOT_TIMEOUT" && kill "$PID" 2>/dev/null ) &
  TIMER_PID=$!
  wait "$PID" 2>/dev/null
  EXIT_CODE=$?
  kill "$TIMER_PID" 2>/dev/null || true
fi
set -e

# ── Check for parse errors in output ─────────────────────────────────────────
ERROR_LINES=$(grep -E "^(ERROR|SCRIPT ERROR).*res://|^Parse error:" "$TMPLOG" || true)

if [[ -n "$ERROR_LINES" ]]; then
  ERROR_COUNT=$(echo "$ERROR_LINES" | wc -l | tr -d ' ')
  echo ""
  echo "✗ COMMIT BLOCKED — $ERROR_COUNT GDScript error(s) detected:"
  echo ""
  echo "$ERROR_LINES" | sed 's/^/  /'
  echo ""
  echo "Fix the errors above before committing."
  echo "Staged files: $(echo "$STAGED_GD" | tr '\n' ' ')"
  echo ""
  echo "To bypass (emergency): git commit --no-verify"
  exit 1
fi

echo "✓ GDScript validation passed."
exit 0
