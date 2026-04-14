#!/usr/bin/env bash
# ============================================================
# 00_install.sh — Install FreeCAD, OpenFOAM, CfdOF workbench
# Run with: bash 00_install.sh 2>&1 | tee logs/install.log
# ============================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "=== [1/5] System packages ==="
sudo apt-get update -qq
sudo apt-get install -y \
  git python3 python3-pip python3-venv \
  xvfb libgl1-mesa-glx libglib2.0-0 \
  paraview gmsh \
  2>&1

echo ""
echo "=== [2/5] OpenFOAM — OpenFOAM.org v11 (preferred by CfdOF) ==="
# Add OpenFOAM.org repo key and sources
if ! grep -q "openfoam.org" /etc/apt/sources.list.d/*.list 2>/dev/null; then
  curl -s https://dl.openfoam.org/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/openfoam.gpg
  sudo add-apt-repository -y "deb http://dl.openfoam.org/ubuntu noble main"
  sudo apt-get update -qq
fi
sudo apt-get install -y openfoam11 2>&1
echo "  Installed: $(ls /opt/openfoam11/bin/OpenFOAM-11.sh 2>/dev/null && echo 'openfoam11' || echo 'FAILED')"

echo ""
echo "=== [3/5] FreeCAD 1.0 — via FreeCAD PPA ==="
if ! command -v freecad &>/dev/null && ! command -v freecadcmd &>/dev/null; then
  sudo add-apt-repository -y ppa:freecad-maintainers/freecad-stable
  sudo apt-get update -qq
  sudo apt-get install -y freecad 2>&1
fi
echo "  FreeCAD: $(freecadcmd --version 2>/dev/null | head -1 || echo 'FAILED - trying AppImage fallback')"

echo ""
echo "=== [3b/5] FreeCAD AppImage fallback (if PPA failed) ==="
if ! command -v freecadcmd &>/dev/null; then
  APPIMG_URL="https://github.com/FreeCAD/FreeCAD/releases/download/1.0.0/FreeCAD_1.0.0-conda-Linux-x86_64-py311.AppImage"
  APPIMG_PATH="$SCRIPT_DIR/FreeCAD.AppImage"
  echo "  Downloading FreeCAD AppImage from GitHub releases..."
  wget -q --show-progress -O "$APPIMG_PATH" "$APPIMG_URL"
  chmod +x "$APPIMG_PATH"
  # Extract so freecadcmd works headlessly without FUSE
  cd /tmp && "$APPIMG_PATH" --appimage-extract >/dev/null 2>&1 || true
  if [ -d /tmp/squashfs-root ]; then
    sudo mv /tmp/squashfs-root /opt/freecad-appimage
    sudo ln -sf /opt/freecad-appimage/usr/bin/freecadcmd /usr/local/bin/freecadcmd
    sudo ln -sf /opt/freecad-appimage/usr/bin/FreeCAD /usr/local/bin/freecad
    echo "  AppImage extracted to /opt/freecad-appimage"
  fi
fi

echo ""
echo "=== [4/5] CfdOF workbench ==="
MOD_DIR="$HOME/.local/share/FreeCAD/Mod"
mkdir -p "$MOD_DIR"
if [ -d "$MOD_DIR/CfdOF" ]; then
  echo "  CfdOF already present — pulling latest..."
  git -C "$MOD_DIR/CfdOF" pull --ff-only 2>&1
else
  echo "  Cloning CfdOF from GitHub..."
  git clone https://github.com/jaheyns/CfdOF "$MOD_DIR/CfdOF" 2>&1
fi
echo "  CfdOF: $(git -C "$MOD_DIR/CfdOF" log --oneline -1 2>/dev/null)"

echo ""
echo "=== [5/5] CfdOF Python dependencies ==="
PYTHON_FOR_FC=$(freecadcmd -c "import sys; print(sys.executable)" 2>/dev/null || python3 -c "import sys; print(sys.executable)")
echo "  Python: $PYTHON_FOR_FC"
"$PYTHON_FOR_FC" -m pip install --quiet pyside2 pivy matplotlib scipy 2>/dev/null || true

echo ""
echo "=== Install complete. Next: run 01_diagnose.sh ==="
