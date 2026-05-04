#!/usr/bin/env bash
# install-hooks.sh — Install Rumor Mill git hooks
#
# Usage (from repo root):
#   ./rumor_mill/tools/install-hooks.sh
#
# This creates a pre-commit hook that runs GDScript validation on staged .gd files.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
HOOK_TARGET="$HOOKS_DIR/pre-commit"
SCRIPT_SOURCE="$REPO_ROOT/rumor_mill/tools/pre-commit-gdscript.sh"

# Ensure the source script is executable
chmod +x "$SCRIPT_SOURCE"

# Install (or replace) the pre-commit hook
if [[ -f "$HOOK_TARGET" ]] && ! grep -q "pre-commit-gdscript" "$HOOK_TARGET"; then
  # Existing hook that isn't ours — append
  echo "" >> "$HOOK_TARGET"
  echo "# ── GDScript validation (Rumor Mill) ──" >> "$HOOK_TARGET"
  echo "exec \"$SCRIPT_SOURCE\"" >> "$HOOK_TARGET"
  echo "✓ Appended GDScript guard to existing pre-commit hook."
else
  # No existing hook or it's already ours — write fresh
  cat > "$HOOK_TARGET" << 'HOOK'
#!/usr/bin/env bash
# Auto-installed by rumor_mill/tools/install-hooks.sh
HOOK
  echo "exec \"$SCRIPT_SOURCE\"" >> "$HOOK_TARGET"
  chmod +x "$HOOK_TARGET"
  echo "✓ Installed pre-commit hook → $HOOK_TARGET"
fi

echo ""
echo "The hook validates staged .gd files using Godot headless mode."
echo "Set GODOT_BIN=/path/to/godot4 if Godot is not on PATH."
echo "Bypass (emergency only): git commit --no-verify"
