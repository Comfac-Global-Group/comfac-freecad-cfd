#!/usr/bin/env bash
# ============================================================
# 01_diagnose.sh — Headless FreeCAD + CfdOF + OpenFOAM diagnostics
# Run with: bash 01_diagnose.sh 2>&1 | tee logs/diagnose.log
# ============================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================"
echo "  FreeCAD/CfdOF/OpenFOAM Diagnostic"
echo "  $TIMESTAMP"
echo "========================================"

# ---- 1. FreeCAD binary check ----------------------------
echo ""
echo "[1] FreeCAD binary"
if command -v freecadcmd &>/dev/null; then
  FCMD="freecadcmd"
elif [ -x /opt/freecad-appimage/usr/bin/freecadcmd ]; then
  FCMD="/opt/freecad-appimage/usr/bin/freecadcmd"
  export LD_LIBRARY_PATH="/opt/freecad-appimage/usr/lib:${LD_LIBRARY_PATH:-}"
else
  echo "  ERROR: freecadcmd not found. Run 00_install.sh first." >&2
  FCMD=""
fi
[ -n "$FCMD" ] && echo "  Using: $FCMD" && $FCMD --version 2>&1 | head -3

# ---- 2. OpenFOAM check ----------------------------------
echo ""
echo "[2] OpenFOAM installation"
FOAM_SOURCED=0
for SH in /opt/openfoam11/etc/bashrc /opt/openfoam10/etc/bashrc \
          /opt/openfoam9/etc/bashrc /opt/openfoam2312/etc/bashrc \
          /usr/lib/openfoam/openfoam2312/etc/bashrc; do
  if [ -f "$SH" ]; then
    source "$SH" 2>/dev/null || true
    FOAM_SOURCED=1
    echo "  Sourced: $SH"
    break
  fi
done
if [ $FOAM_SOURCED -eq 0 ]; then
  echo "  WARNING: No OpenFOAM bashrc found. Install with 00_install.sh"
fi
which simpleFoam 2>/dev/null && echo "  simpleFoam: $(simpleFoam --version 2>&1 | head -1)" || echo "  ERROR: simpleFoam not in PATH"
which icoFoam   2>/dev/null && echo "  icoFoam: OK" || echo "  ERROR: icoFoam not in PATH"
echo "  WM_PROJECT_DIR: ${WM_PROJECT_DIR:-NOT SET}"
echo "  WM_PROJECT_VERSION: ${WM_PROJECT_VERSION:-NOT SET}"

# ---- 3. CfdOF workbench check ---------------------------
echo ""
echo "[3] CfdOF workbench"
MOD_DIR="$HOME/.local/share/FreeCAD/Mod/CfdOF"
if [ -d "$MOD_DIR" ]; then
  echo "  Path: $MOD_DIR"
  echo "  Commit: $(git -C "$MOD_DIR" log --oneline -1 2>/dev/null || echo 'unknown')"
  ls "$MOD_DIR"/*.py 2>/dev/null | wc -l | xargs echo "  Python files:"
  # Check key files
  for F in CfdOF.py CfdPreferencePage.py CfdFluidBoundary.py CfdMeshTools.py; do
    [ -f "$MOD_DIR/$F" ] && echo "  OK: $F" || echo "  MISSING: $F"
  done
else
  echo "  ERROR: CfdOF not found at $MOD_DIR. Run 00_install.sh."
fi

# ---- 4. FreeCAD Python environment check ----------------
echo ""
echo "[4] FreeCAD Python environment"
if [ -n "$FCMD" ]; then
  PYTHON_CHECK=$(cat <<'PYEOF'
import sys
print("Python:", sys.version)
print("sys.path entries:", len(sys.path))

errors = []
for mod in ['Part', 'Mesh', 'FreeCAD']:
    try:
        __import__(mod)
        print(f"  OK: {mod}")
    except ImportError as e:
        print(f"  MISSING: {mod} — {e}")
        errors.append(mod)

try:
    import CfdOF
    print("  OK: CfdOF imported")
except ImportError as e:
    print(f"  MISSING: CfdOF — {e}")
    errors.append('CfdOF')

if errors:
    sys.exit(1)
PYEOF
)
  xvfb-run --auto-servernum $FCMD -c "$PYTHON_CHECK" \
    >"$LOG_DIR/fc_python_${TIMESTAMP}.log" 2>&1 \
    && cat "$LOG_DIR/fc_python_${TIMESTAMP}.log" \
    || { echo "  ERRORS (see $LOG_DIR/fc_python_${TIMESTAMP}.log):"; cat "$LOG_DIR/fc_python_${TIMESTAMP}.log"; }
fi

# ---- 5. OpenFOAM self-test ------------------------------
echo ""
echo "[5] OpenFOAM self-test — run pitzDaily"
if [ $FOAM_SOURCED -eq 1 ] && command -v simpleFoam &>/dev/null; then
  TESTCASE="$LOG_DIR/pitzDaily_${TIMESTAMP}"
  cp -r "$FOAM_TUTORIALS/incompressible/simpleFoam/pitzDaily" "$TESTCASE" 2>/dev/null || \
  cp -r /opt/openfoam*/tutorials/incompressible/simpleFoam/pitzDaily "$TESTCASE" 2>/dev/null
  if [ -d "$TESTCASE" ]; then
    cd "$TESTCASE"
    blockMesh >"$TESTCASE/blockMesh.log" 2>&1 && echo "  blockMesh: OK" || echo "  blockMesh: FAILED — see $TESTCASE/blockMesh.log"
    simpleFoam >"$TESTCASE/simpleFoam.log" 2>&1 && echo "  simpleFoam: OK" || { echo "  simpleFoam: FAILED — last 20 lines:"; tail -20 "$TESTCASE/simpleFoam.log"; }
    cd "$SCRIPT_DIR"
  else
    echo "  WARNING: pitzDaily tutorial not found, skipping solver test"
  fi
else
  echo "  SKIP: OpenFOAM not available"
fi

# ---- 6. Collect summary log -----------------------------
echo ""
echo "[6] Log summary saved to: $LOG_DIR/"
ls -lh "$LOG_DIR/"

echo ""
echo "=== Diagnostic complete. Share logs/ with your AI assistant. ==="
