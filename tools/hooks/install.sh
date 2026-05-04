#!/usr/bin/env bash
# Install project git hooks from tools/hooks/ into .git/hooks/
# Run once after cloning: bash tools/hooks/install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

for hook in "$SCRIPT_DIR"/pre-*; do
  [ -f "$hook" ] || continue
  name="$(basename "$hook")"
  cp "$hook" "$HOOKS_DIR/$name"
  chmod +x "$HOOKS_DIR/$name"
  echo "Installed $name hook."
done

echo "Done. Git hooks installed from tools/hooks/."
