#!/usr/bin/env bash
# merge-to-stable.sh — validate then merge main → stable
#
# Usage:
#   ./rumor_mill/tools/merge-to-stable.sh [--godot <path>] [--dry-run]
#
# What it does:
#   1. Ensures the working tree is clean (no uncommitted changes)
#   2. Runs headless GDScript validation on the main branch project
#   3. If validation passes, fast-forward merges main into stable
#
# Exit codes:
#   0 — merge completed successfully
#   1 — GDScript validation failed (merge aborted)
#   2 — precondition failed (dirty tree, binary not found, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate_gdscript.sh"

GODOT_ARG=""
DRY_RUN=false

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot)    GODOT_ARG="--godot $2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--godot <path>] [--dry-run]"
      echo ""
      echo "  --godot <path>  Path to Godot 4 binary (auto-detected if omitted)"
      echo "  --dry-run       Validate only; do not merge"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# ── Ensure we are in the repo root ────────────────────────────────────────────
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Merge-to-Stable — Rumor Mill"
echo "  Repo:    $REPO_ROOT"
if $DRY_RUN; then
  echo "  Mode:    DRY RUN (validate only, no merge)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Precondition: clean working tree ──────────────────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  echo ""
  echo "ERROR: Working tree has uncommitted changes. Commit or stash before merging." >&2
  git status --short >&2
  exit 2
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
MAIN_SHA="$(git rev-parse main)"
STABLE_SHA="$(git rev-parse stable)"

echo ""
echo "  main:    $MAIN_SHA"
echo "  stable:  $STABLE_SHA"

if [[ "$MAIN_SHA" == "$STABLE_SHA" ]]; then
  echo ""
  echo "✓ stable is already up to date with main. Nothing to merge."
  exit 0
fi

AHEAD_COUNT="$(git rev-list --count stable..main)"
echo "  Ahead:   $AHEAD_COUNT commit(s) on main not yet on stable"
echo ""

# ── Step 1: Validate ──────────────────────────────────────────────────────────
echo "Step 1/2 — Running GDScript validation on main branch..."
echo ""

# shellcheck disable=SC2086
bash "$VALIDATE_SCRIPT" $GODOT_ARG

echo ""
echo "✓ Validation passed."

# ── Step 2: Merge ─────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo ""
  echo "DRY RUN — skipping merge. Re-run without --dry-run to perform the merge."
  exit 0
fi

echo ""
echo "Step 2/2 — Merging main → stable..."

# Switch to stable and fast-forward
git checkout stable
git merge --ff-only main -m "chore: merge main into stable (validated)

Co-Authored-By: Paperclip <noreply@paperclip.ing>"

NEW_STABLE_SHA="$(git rev-parse stable)"

# Return to original branch
git checkout "$CURRENT_BRANCH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Merge complete."
echo "  stable is now at: $NEW_STABLE_SHA"
echo "  Working branch restored: $CURRENT_BRANCH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
