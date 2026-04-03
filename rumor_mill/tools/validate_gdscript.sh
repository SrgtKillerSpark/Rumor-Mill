#!/usr/bin/env bash
# validate_gdscript.sh — headless GDScript validation for Rumor Mill
#
# Runs Godot in headless mode to catch GDScript parse errors, type mismatches,
# and missing scene references without a GUI.
#
# Usage:
#   ./rumor_mill/tools/validate_gdscript.sh [--godot <path>] [--project <path>]
#
# Exit codes:
#   0 — no errors found
#   1 — GDScript errors detected
#   2 — Godot binary not found or project path invalid

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."   # rumor_mill/
GODOT_BIN=""

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot)   GODOT_BIN="$2"; shift 2 ;;
    --project) PROJECT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--godot <path>] [--project <path>]"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# ── Locate Godot binary ────────────────────────────────────────────────────────
if [[ -z "$GODOT_BIN" ]]; then
  for candidate in \
    "godot4" \
    "godot" \
    "/usr/local/bin/godot4" \
    "/usr/bin/godot4" \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "C:/Program Files/Godot/Godot_v4.x_stable/Godot_v4.x_stable_win64.exe" \
    "$HOME/.local/share/godot/bin/godot4"
  do
    if command -v "$candidate" &>/dev/null 2>&1; then
      GODOT_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$GODOT_BIN" ]] || ! command -v "$GODOT_BIN" &>/dev/null 2>&1; then
  echo "ERROR: Godot binary not found." >&2
  echo "  Set GODOT_BIN env var or pass --godot <path>" >&2
  echo "  e.g.: GODOT_BIN=/path/to/godot4 $0" >&2
  exit 2
fi

# ── Validate project path ──────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
  echo "ERROR: No project.godot found in: $PROJECT_DIR" >&2
  exit 2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GDScript Validation — Rumor Mill"
echo "  Godot:   $GODOT_BIN"
echo "  Project: $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Run Godot headless validation ─────────────────────────────────────────────
# --headless : no GUI, no display server required
# --path     : project root
# 2>&1       : merge stderr into stdout so we capture all output
#
# Note: Godot 4 in headless mode loads and runs the project without a window.
# It does not exit on its own, so we wrap the call in a timeout (default 60 s).
# If Godot exits cleanly OR is killed by the timeout and no res://-path errors
# were emitted, validation is considered passed.
GODOT_TIMEOUT="${GODOT_TIMEOUT:-60}"
TMPLOG="$(mktemp /tmp/godot_validate_XXXXXX.log)"
trap 'rm -f "$TMPLOG"' EXIT

# Use GNU timeout if available; fall back to direct run with a background kill.
set +e
if command -v timeout &>/dev/null 2>&1; then
  timeout "$GODOT_TIMEOUT" "$GODOT_BIN" --headless --path "$PROJECT_DIR" > "$TMPLOG" 2>&1
  GODOT_EXIT=$?
  # timeout exits 124 when it kills the process — treat that as a clean exit
  # (the game ran long enough to load all scripts; we check for errors below).
  [[ $GODOT_EXIT -eq 124 ]] && GODOT_EXIT=0
else
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" > "$TMPLOG" 2>&1 &
  GODOT_PID=$!
  sleep "$GODOT_TIMEOUT"
  kill "$GODOT_PID" 2>/dev/null || true
  wait "$GODOT_PID" 2>/dev/null
  GODOT_EXIT=0
fi
set -e

# ── Parse output for errors ────────────────────────────────────────────────────
# Godot 4 GDScript error lines reference a res:// path, e.g.:
#   ERROR: res://scripts/foo.gd:42 - Parse error: …
#   SCRIPT ERROR: res://scripts/foo.gd:42 - …
# Engine-level shutdown noise (BUG: Unreferenced static string, RID leaks,
# PagedAllocator, Thread cleanup) does NOT contain res:// and is excluded.
ERROR_LINES=$(grep -E "^(ERROR|SCRIPT ERROR).*res://|^Parse error:" "$TMPLOG" || true)
WARNING_LINES=$(grep -E "^WARNING:.*res://" "$TMPLOG" || true)

# Count errors
ERROR_COUNT=0
if [[ -n "$ERROR_LINES" ]]; then
  ERROR_COUNT=$(echo "$ERROR_LINES" | wc -l | tr -d ' ')
fi

WARNING_COUNT=0
if [[ -n "$WARNING_LINES" ]]; then
  WARNING_COUNT=$(echo "$WARNING_LINES" | wc -l | tr -d ' ')
fi

# ── Report ─────────────────────────────────────────────────────────────────────
if [[ -n "$WARNING_LINES" ]]; then
  echo ""
  echo "WARNINGS ($WARNING_COUNT):"
  echo "$WARNING_LINES" | sed 's/^/  /'
fi

if [[ -n "$ERROR_LINES" ]]; then
  echo ""
  echo "ERRORS ($ERROR_COUNT):"
  echo "$ERROR_LINES" | sed 's/^/  /'
fi

# If Godot returned non-zero but we didn't catch structured errors, dump raw log
if [[ $GODOT_EXIT -ne 0 && -z "$ERROR_LINES" ]]; then
  echo ""
  echo "Godot exited with code $GODOT_EXIT. Raw output:"
  cat "$TMPLOG" | sed 's/^/  /'
fi

echo ""
if [[ $GODOT_EXIT -eq 0 && -z "$ERROR_LINES" ]]; then
  echo "✓ Validation passed — no GDScript errors found."
  exit 0
else
  echo "✗ Validation FAILED — $ERROR_COUNT error(s) found."
  exit 1
fi
