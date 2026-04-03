#!/usr/bin/env bash
# install_hooks.sh — install git pre-commit hook for GDScript validation
#
# Usage: bash rumor_mill/tools/install_hooks.sh
#
# Run this once after cloning the repo to enable automatic validation
# before every commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_DIR="$REPO_ROOT/.git/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

if [[ ! -d "$HOOK_DIR" ]]; then
  echo "ERROR: Not inside a git repository (no .git/hooks found)." >&2
  exit 1
fi

cat > "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook: GDScript validation
# Installed by rumor_mill/tools/install_hooks.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"
VALIDATE_SCRIPT="$REPO_ROOT/rumor_mill/tools/validate_gdscript.sh"

if [[ ! -f "$VALIDATE_SCRIPT" ]]; then
  echo "WARNING: validate_gdscript.sh not found — skipping GDScript check." >&2
  exit 0
fi

# Only run if any .gd or .tscn files are staged
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(gd|tscn)$' || true)
if [[ -z "$STAGED" ]]; then
  exit 0
fi

echo "Running GDScript validation on staged changes..."
bash "$VALIDATE_SCRIPT" --project "$REPO_ROOT/rumor_mill"
EOF

chmod +x "$HOOK_FILE"
echo "Pre-commit hook installed at: $HOOK_FILE"
echo "GDScript validation will now run automatically before each commit."
