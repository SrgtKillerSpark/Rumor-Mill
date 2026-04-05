#!/usr/bin/env bash
# install_hooks.sh — install git hooks for GDScript validation
#
# Installs two hooks:
#   pre-commit — runs validate_gdscript.sh (requires Godot) on staged .gd/.tscn files
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

# ── pre-commit: headless Godot validation ─────────────────────────────────────
PRECOMMIT="$HOOK_DIR/pre-commit"
cat > "$PRECOMMIT" << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook: GDScript headless validation (requires Godot)
# Installed by rumor_mill/tools/install_hooks.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"
VALIDATE_SCRIPT="$REPO_ROOT/rumor_mill/tools/validate_gdscript.sh"

if [[ ! -f "$VALIDATE_SCRIPT" ]]; then
  echo "WARNING: validate_gdscript.sh not found — skipping headless GDScript check." >&2
  exit 0
fi

# Only run if any .gd or .tscn files are staged
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(gd|tscn)$' || true)
if [[ -z "$STAGED" ]]; then
  exit 0
fi

echo "Running GDScript headless validation on staged changes..."
bash "$VALIDATE_SCRIPT" --project "$REPO_ROOT/rumor_mill"
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
echo "Hooks installed. Static check runs on every push; headless check on every commit (requires Godot)."
