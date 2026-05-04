#!/usr/bin/env bash
# test_kpi_aggregate.sh — run all kpi_aggregate regression tests
#
# Usage:  bash tools/analytics/test_kpi_aggregate.sh
# Exits 0 on green, non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== kpi_aggregate smoke: all fixtures ==="
node "$SCRIPT_DIR/kpi_aggregate.js" "$SCRIPT_DIR/fixtures/"*.ndjson > /dev/null
echo "  PASS  smoke exits 0 on all fixtures"

echo ""
echo "=== evidence aggregation regression tests (SPA-1535) ==="
node "$SCRIPT_DIR/test_evidence_agg.js"

echo ""
echo "=== evidence parity regression tests (SPA-1593) ==="
node "$SCRIPT_DIR/test_evidence_parity.js"
