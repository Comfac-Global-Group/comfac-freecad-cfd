#!/usr/bin/env bash
# ============================================================
# 05_collect_logs.sh
# Collect ALL relevant logs into a single diagnostic bundle
# Share the output file with your AI assistant
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/logs/diagnostic_bundle_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$SCRIPT_DIR/logs"

{
echo "========================================================"
echo "  FreeCAD/CfdOF/OpenFOAM Diagnostic Bundle"
echo "  Generated: $(date)"
echo "========================================================"

echo ""
echo "=== SYSTEM ==="
uname -a
cat /etc/os-release 2>/dev/null | grep -E "NAME|VERSION"

echo ""
echo "=== FREECAD ==="
freecadcmd --version 2>&1 || echo "freecadcmd not found"

echo ""
echo "=== OPENFOAM ==="
for SH in /opt/openfoam11/etc/bashrc /opt/openfoam10/etc/bashrc \
          /opt/openfoam9/etc/bashrc /opt/openfoam2312/etc/bashrc; do
  [ -f "$SH" ] && source "$SH" 2>/dev/null && echo "Sourced: $SH" && break
done
simpleFoam --version 2>&1 || echo "simpleFoam not found"
echo "WM_PROJECT_DIR: ${WM_PROJECT_DIR:-NOT SET}"
echo "WM_PROJECT_VERSION: ${WM_PROJECT_VERSION:-NOT SET}"

echo ""
echo "=== CFDOF WORKBENCH ==="
MOD="$HOME/.local/share/FreeCAD/Mod/CfdOF"
[ -d "$MOD" ] && git -C "$MOD" log --oneline -5 || echo "CfdOF not found at $MOD"

echo ""
echo "=== LOG FILES ==="
for f in "$SCRIPT_DIR/logs/"*.log; do
  [ -f "$f" ] || continue
  echo ""
  echo "--- $f ---"
  cat "$f"
  echo "--- END $f ---"
done

echo ""
echo "=== OPENFOAM CASE: 0/U ==="
cat "$SCRIPT_DIR/of_vol_inlet/0/U" 2>/dev/null || echo "No U file found"

echo ""
echo "=== OF CASE: BLOCKMESH LOG ==="
cat "$SCRIPT_DIR/of_vol_inlet/log.blockMesh" 2>/dev/null || echo "No blockMesh log"

echo ""
echo "=== OF CASE: SIMPLEFOAM LOG (last 50 lines) ==="
tail -50 "$SCRIPT_DIR/of_vol_inlet/log.simpleFoam" 2>/dev/null || echo "No simpleFoam log"

} > "$OUT" 2>&1

echo "Diagnostic bundle saved to: $OUT"
echo "Size: $(du -sh "$OUT" | cut -f1)"
