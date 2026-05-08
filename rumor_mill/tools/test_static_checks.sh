#!/usr/bin/env bash
# test_static_checks.sh — run GDScript static checker regression tests
#
# Usage:  bash rumor_mill/tools/test_static_checks.sh
# Exits 0 on green, non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== GDScript static checker regression tests (SPA-1560) ==="
node "$SCRIPT_DIR/test_check_gdscript_static.js"
