#!/usr/bin/env bash
# ============================================================
# 02_run_vol_inlet_test.sh
# Test: OpenFOAM volumetric inlet BC on a simple pipe
# Run with: bash 02_run_vol_inlet_test.sh 2>&1 | tee logs/vol_inlet_test.log
# ============================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE="$SCRIPT_DIR/of_vol_inlet"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== OpenFOAM Volumetric Inlet Test — $TIMESTAMP ==="

# Source OpenFOAM environment
FOAM_SOURCED=0
for SH in /opt/openfoam11/etc/bashrc /opt/openfoam10/etc/bashrc \
          /opt/openfoam9/etc/bashrc /opt/openfoam2312/etc/bashrc; do
  if [ -f "$SH" ]; then
    source "$SH" 2>/dev/null && FOAM_SOURCED=1
    echo "Sourced: $SH"
    break
  fi
done

if [ $FOAM_SOURCED -eq 0 ]; then
  echo "ERROR: OpenFOAM not found. Run 00_install.sh first."
  exit 1
fi

cd "$CASE"

echo ""
echo "--- Step 1: blockMesh ---"
blockMesh > "$LOG_DIR/blockMesh_${TIMESTAMP}.log" 2>&1
if [ $? -eq 0 ]; then
  echo "  OK — mesh built"
  tail -5 "$LOG_DIR/blockMesh_${TIMESTAMP}.log"
else
  echo "  FAILED:"
  cat "$LOG_DIR/blockMesh_${TIMESTAMP}.log"
  exit 1
fi

echo ""
echo "--- Step 2: checkMesh ---"
checkMesh > "$LOG_DIR/checkMesh_${TIMESTAMP}.log" 2>&1
grep -E "cells:|faces:|FAILED|Error|warning" "$LOG_DIR/checkMesh_${TIMESTAMP}.log" | head -20

echo ""
echo "--- Step 3: simpleFoam (200 iterations, volumetric inlet) ---"
# Override endTime for quick test
sed 's/endTime.*500/endTime       200/' system/controlDict > system/controlDict.tmp \
  && mv system/controlDict.tmp system/controlDict

simpleFoam > "$LOG_DIR/simpleFoam_${TIMESTAMP}.log" 2>&1
EXIT_CODE=$?

echo ""
echo "--- Results ---"
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: simpleFoam completed"
  # Show final residuals
  grep "Solving for U" "$LOG_DIR/simpleFoam_${TIMESTAMP}.log" | tail -3
  grep "Solving for p" "$LOG_DIR/simpleFoam_${TIMESTAMP}.log" | tail -3
else
  echo "  FAIL (exit $EXIT_CODE) — relevant error lines:"
  grep -E "ERROR|error|FATAL|Cannot|unknown|not found|flowRateInletVelocity" \
    "$LOG_DIR/simpleFoam_${TIMESTAMP}.log" | head -30
  echo ""
  echo "  Last 30 lines of log:"
  tail -30 "$LOG_DIR/simpleFoam_${TIMESTAMP}.log"
fi

echo ""
echo "Full log: $LOG_DIR/simpleFoam_${TIMESTAMP}.log"
echo ""
echo "=== To inspect results: paraFoam (or post_log.sh) ==="
