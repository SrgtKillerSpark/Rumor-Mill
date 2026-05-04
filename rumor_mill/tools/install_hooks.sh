#!/usr/bin/env bash
# install_hooks.sh — install git hooks for GDScript validation
#
# Installs two hooks:
#   pre-commit — runs check_gdscript_static.js (fast, no Godot) + validate_gdscript.sh (optional Godot)
#   pre-push   — runs check_gdscript_static.js (no Godot required) on all .gd files
#
# Usage: bash rumor_mill/tools/install_hooks.sh
#
# Run once after cloning the repo to enable automatic validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_DIR="$REPO_ROOT/.git/hooks"

if [[ ! -d "$HOOK_DIR" ]]; then
  echo "ERROR: Not inside a git repository (no .git/hooks found)." >&2
  exit 1
fi

# ── pre-commit: static check + optional headless Godot validation ─────────────
PRECOMMIT="$HOOK_DIR/pre-commit"
cat > "$PRECOMMIT" << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook: GDScript static analysis + headless validation
# Installed by rumor_mill/tools/install_hooks.sh
#
# Runs two checks when .gd files are staged:
#   1. check_gdscript_static.js — fast Node.js linter (no Godot required)
#   2. validate_gdscript.sh — headless Godot validation (skipped if Godot absent)
#
# Bypass for emergencies: git commit --no-verify

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Only run if any .gd files are staged
STAGED_GD=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.gd$' || true)
if [[ -z "$STAGED_GD" ]]; then
  exit 0
fi

ERRORS=0

# ── Step 1: Static analysis (fast, no Godot) ─────────────────────────────────
STATIC_SCRIPT="$REPO_ROOT/rumor_mill/tools/check_gdscript_static.js"

if [[ -f "$STATIC_SCRIPT" ]]; then
  if command -v node &>/dev/null; then
    echo "pre-commit: running GDScript static check..."
    if ! node "$STATIC_SCRIPT" --project "$REPO_ROOT/rumor_mill" --fix-hint; then
      echo ""
      echo "✗ Static check failed — commit blocked."
      echo "  Fix the errors above or bypass with: git commit --no-verify"
      ERRORS=1
    fi
  else
    echo "WARNING: node not found — skipping static GDScript check." >&2
  fi
else
  echo "WARNING: check_gdscript_static.js not found — skipping static check." >&2
fi

# ── Step 2: Headless Godot validation (optional, skipped if Godot missing) ────
VALIDATE_SCRIPT="$REPO_ROOT/rumor_mill/tools/validate_gdscript.sh"

if [[ -f "$VALIDATE_SCRIPT" ]]; then
  # Only run headless validation if <= 20 staged .gd files (speed gate)
  STAGED_COUNT=$(echo "$STAGED_GD" | wc -l | tr -d ' ')
  if [[ $STAGED_COUNT -le 20 ]]; then
    echo "pre-commit: running headless Godot validation..."
    if ! bash "$VALIDATE_SCRIPT" --project "$REPO_ROOT/rumor_mill"; then
      echo ""
      echo "✗ Headless validation failed — commit blocked."
      echo "  Fix the errors above or bypass with: git commit --no-verify"
      ERRORS=1
    fi
  else
    echo "pre-commit: $STAGED_COUNT .gd files staged — skipping headless validation (too many; will run in CI)."
  fi
fi

exit $ERRORS
EOF
chmod +x "$PRECOMMIT"
echo "Pre-commit hook installed at: $PRECOMMIT"

# ── pre-push: static checker (no Godot required) ─────────────────────────────
PREPUSH="$HOOK_DIR/pre-push"
cat > "$PREPUSH" << 'EOF'
#!/usr/bin/env bash
# Pre-push hook: GDScript static analysis (no Godot required)
# Installed by rumor_mill/tools/install_hooks.sh
#
# Checks all .gd files for:
#   - bare extension-singleton references not guarded by Engine.has_singleton()
#   - unresolved class_name type references
#   - autoload identifiers not declared in project.godot
#   - block-scope variable mismatches (var declared inside inner block, used in outer scope)

REPO_ROOT="$(git rev-parse --show-toplevel)"
STATIC_SCRIPT="$REPO_ROOT/rumor_mill/tools/check_gdscript_static.js"

if [[ ! -f "$STATIC_SCRIPT" ]]; then
  echo "WARNING: check_gdscript_static.js not found — skipping static GDScript check." >&2
  exit 0
fi

if ! command -v node &>/dev/null; then
  echo "WARNING: node not found — skipping static GDScript check." >&2
  exit 0
fi

# Only run if any .gd files are in the push
CHANGED=$(git diff --name-only @{u}...HEAD 2>/dev/null | grep -E '\.gd$' || true)
if [[ -z "$CHANGED" ]]; then
  exit 0
fi

echo "Running GDScript static check..."
node "$STATIC_SCRIPT" --project "$REPO_ROOT/rumor_mill" --fix-hint
EOF
chmod +x "$PREPUSH"
echo "Pre-push hook installed at:   $PREPUSH"

echo ""
echo "Hooks installed. Static check + optional headless validation on every commit; static check on every push."
