# repoanalysis.md — freecad-cfd Repository Analysis

<!-- ================================================================
  MCP DATETIME PROTOCOL — READ THIS BEFORE EDITING
  ================================================================
  This file is maintained collaboratively by AI models (Claude, Kimi,
  DeepSeek, etc.) and human contributors. Every model that edits this
  file MUST:

  1. Add a dated entry to the CHANGELOG section at the bottom using:
       <!-- MCP-UPDATE: YYYY-MM-DD HH:MM UTC | Model: <name> | <summary> -->

  2. Preserve all existing content unless explicitly asked to replace it.

  3. When describing new code added to the repo, place the analysis under
     the correct section (Architecture, File Reference, Known Issues).

  4. Never remove or overwrite a prior MCP-UPDATE line.

  DATETIME FORMAT: ISO 8601 — YYYY-MM-DD HH:MM UTC
  ================================================================ -->

---

## Purpose

**freecad-cfd** is a headless automation and diagnostic toolkit that bridges:

```
FreeCAD (.FCStd model)
    ↓  [03_cfdof_headless.py]
CfdOF Workbench  ←  github.com/jaheyns/CfdOF
    ↓  writes OpenFOAM case directory
OpenFOAM solver (simpleFoam / icoFoam)
    ↑  [04_patch_vol_inlet.py] overrides inlet BC → flowRateInletVelocity
```

**Primary use case:** Cornersteel Systems Corporation pipe and duct CFD analysis — running OpenFOAM from FreeCAD models in a server/CI environment without a display.

**Core problem solved:** CfdOF generates `fixedValue` velocity inlets. This repo patches them to `flowRateInletVelocity` so engineers can supply real-world flow meter data (m³/s or m³/hr) instead of computing velocity manually.

---

## Architecture Overview

```
freecad-cfd/
├── 00_install.sh            Phase 1 — Environment bootstrap
├── 01_diagnose.sh           Phase 2 — Validate all components
├── 02_run_vol_inlet_test.sh Phase 3 — Standalone OF pipe test
├── 03_cfdof_headless.py     Phase 4 — FCStd → OF case (headless)
├── 04_patch_vol_inlet.py    Phase 5 — Patch inlet BC
├── 05_collect_logs.sh       Utility — Bundle logs for review
├── of_vol_inlet/            Reference OpenFOAM pipe case
│   ├── 0/                   Initial conditions (U, p, k, omega)
│   ├── constant/            Physical properties + turbulence model
│   └── system/              Mesh, solver, and scheme config
└── logs/                    Runtime output (gitignored)
```

### Execution phases and data flow

```
Phase 1: Install
  00_install.sh
  ├─ apt: git, python3, xvfb, paraview, gmsh
  ├─ OpenFOAM.org v11  →  /opt/openfoam11/
  ├─ FreeCAD 1.0       →  via PPA or AppImage at /opt/freecad-appimage/
  └─ CfdOF workbench   →  ~/.local/share/FreeCAD/Mod/CfdOF/

Phase 2: Diagnose
  01_diagnose.sh
  ├─ Check: freecadcmd binary exists + version
  ├─ Check: OpenFOAM bashrc sources cleanly, simpleFoam in PATH
  ├─ Check: CfdOF .py files present, git commit hash logged
  ├─ Check: FreeCAD Python can import Part, Mesh, FreeCAD, CfdOF
  └─ Self-test: run pitzDaily tutorial (blockMesh + simpleFoam)
  Output: logs/fc_python_<ts>.log, logs/pitzDaily_<ts>/

Phase 3: Standalone volumetric inlet test
  02_run_vol_inlet_test.sh
  ├─ Sources OpenFOAM env
  ├─ blockMesh on of_vol_inlet/   →  50×5×5 hex pipe mesh
  ├─ checkMesh                    →  quality report
  └─ simpleFoam (200 iter)        →  residual convergence check
  Output: logs/blockMesh_<ts>.log, logs/simpleFoam_<ts>.log

Phase 4: FCStd → OF case
  xvfb-run freecadcmd 03_cfdof_headless.py -- model.FCStd
  ├─ Opens .FCStd document via FreeCAD.openDocument()
  ├─ Locates CfdAnalysis object (TypeId scan)
  ├─ Locates CfdSolver object → reads OutputPath
  ├─ Calls CfdCaseWriterFoam.CfdCaseWriterFoam(analysis).writeCase()
  └─ Dumps full object tree + errors to logs/cfdof_headless_<ts>.log

Phase 5: Patch inlet BC
  python3 04_patch_vol_inlet.py <case_dir> <flow_m3s>
  ├─ Finds 0/U (checks 0/ then 0.orig/)
  ├─ Auto-detects inlet patches (name contains "inlet" OR fixedValue type)
  ├─ Backs up original: 0/U.orig_<ts>
  ├─ replace_patch_block(): brace-depth walk replaces patch block
  └─ Writes flowRateInletVelocity with volumetricFlowRate = Q

Phase 6: Log collection
  05_collect_logs.sh
  └─ Concatenates all logs/ files + 0/U + blockMesh/simpleFoam logs
     into logs/diagnostic_bundle_<ts>.txt
```

---

## File Reference

### `00_install.sh`
- **Guard:** `set -euo pipefail` — hard failure on any error
- **OpenFOAM source:** OpenFOAM.org v11 PPA (`dl.openfoam.org/ubuntu noble`)
- **FreeCAD primary:** `ppa:freecad-maintainers/freecad-stable`
- **FreeCAD fallback:** AppImage extracted to `/opt/freecad-appimage/`, symlinked to `/usr/local/bin/`
- **CfdOF clone target:** `~/.local/share/FreeCAD/Mod/CfdOF`
- **Key env var set by AppImage path:** `LD_LIBRARY_PATH`

### `01_diagnose.sh`
- **Headless display:** `xvfb-run --auto-servernum` wraps every freecadcmd call
- **OpenFOAM detection:** tries v11, v10, v9, v2312 bashrc paths in order
- **Python check:** embedded heredoc script run inside freecadcmd with `-c`
- **pitzDaily test:** copies from `$FOAM_TUTORIALS` (or `/opt/openfoam*/tutorials/`)

### `02_run_vol_inlet_test.sh`
- **Case used:** `of_vol_inlet/` (1m × 0.1m × 0.1m hex pipe)
- **Turbulence:** kOmegaSST
- **endTime override:** inline `sed` on `controlDict` (reduces 500→200 for speed)
- **Error grep:** looks for `ERROR|FATAL|Cannot|flowRateInletVelocity` in solver log

### `03_cfdof_headless.py`
- **Must run inside** `freecadcmd` — not plain `python3`
- **FCStd lookup:** CLI arg `--` separator first; fallback to hardcoded Cornersteel Downloads paths
- **Object scan:** checks `obj.TypeId` and `obj.Name` prefix for `CfdAnalysis`, `CfdSolver`
- **CfdOF import:** `CfdCaseWriterFoam.CfdCaseWriterFoam(analysis).writeCase()`
- **Log:** `logs/cfdof_headless_<ts>.log` written simultaneously to stdout and file

### `04_patch_vol_inlet.py`
- **`find_u_file()`:** checks `0/U` then `0.orig/U`
- **`detect_inlet_patches()`:** regex scan for `fixedValue`/`flowRateInletVelocity` types; falls back to any `fixedValue` if no name matches "inlet"
- **`replace_patch_block()`:** character-level brace-depth walk (not regex) — handles nested dicts inside patch blocks correctly
- **Backup:** writes `0/U.orig_<TIMESTAMP>` before every modification
- **Fallback:** if patch name not found in file, appends new block before last `}`

### `of_vol_inlet/` — Reference Case
| File | Purpose |
|------|---------|
| `system/blockMeshDict` | 50×5×5 structured hex, 1m pipe, patches: inlet/outlet/walls |
| `system/controlDict` | `simpleFoam`, 500 iterations, ascii output every 100 steps |
| `system/fvSchemes` | `steadyState` ddt, `linearUpwind` for U divergence |
| `system/fvSolution` | GAMG for p, smoothSolver for U/k/omega, SIMPLE consistent |
| `constant/transportProperties` | Air: `nu = 1.5e-5 m²/s` |
| `constant/turbulenceProperties` | RAS kOmegaSST |
| `0/U` | **flowRateInletVelocity** at inlet (Q=0.001 m³/s), noSlip walls |
| `0/p` | fixedValue=0 at outlet, zeroGradient elsewhere |
| `0/k` | `turbulentIntensityKineticEnergyInlet` (5%) at inlet |
| `0/omega` | `turbulentMixingLengthFrequencyInlet` (L=0.01m) at inlet |

---

## Key Dependencies and Versions

| Component | Source | Version Target | Install Path |
|-----------|--------|----------------|--------------|
| FreeCAD | PPA: freecad-maintainers/freecad-stable | 1.0.x | `/usr/bin/freecadcmd` |
| FreeCAD (fallback) | GitHub AppImage | 1.0.0 (py311) | `/opt/freecad-appimage/` |
| OpenFOAM | OpenFOAM.org PPA | v11 | `/opt/openfoam11/` |
| CfdOF | github.com/jaheyns/CfdOF | latest main | `~/.local/share/FreeCAD/Mod/CfdOF/` |
| xvfb | apt | system | virtual display for headless FreeCAD |
| paraview | apt | system | post-processing visualisation |
| gmsh | apt | system | external mesh generation |

---

## Critical Integration Points

### 1. flowRateInletVelocity boundary condition
The central technical goal. In `0/U`:
```cpp
inlet {
    type                flowRateInletVelocity;
    volumetricFlowRate  0.001;   // m³/s — Q not U
    value               uniform (0 0 0);
}
```
This BC requires OpenFOAM v9+ (OpenFOAM.org) or v2106+ (ESI). Earlier builds lack it or have it under a different name. The apt package `openfoam` (v1912) on Ubuntu 24.04 is too old.

### 2. CfdOF case writer import chain
```python
import CfdOF                           # top-level workbench init
import CfdCaseWriterFoam               # case writer module
writer = CfdCaseWriterFoam.CfdCaseWriterFoam(analysis)
writer.writeCase()
```
Both modules must be on `sys.path`. FreeCAD adds `~/.local/share/FreeCAD/Mod/CfdOF/` automatically when run via `freecadcmd`. Running via plain `python3` will fail.

### 3. Headless display requirement
FreeCAD initialises Qt even in `freecadcmd` mode. Without a display:
```bash
xvfb-run --auto-servernum freecadcmd script.py
```
Without `xvfb-run`, you get `QXcbConnection: Could not connect to display` and a segfault.

---

## Known Limitations

- `04_patch_vol_inlet.py` interactive prompt (`input()`) will hang in fully automated pipelines — pass patch name as a 3rd argument when automating.
- `02_run_vol_inlet_test.sh` mutates `system/controlDict` in-place (sed, no restore). Run from a clean working tree or add a reset step.
- `03_cfdof_headless.py` hardcodes two Cornersteel FCStd fallback paths — update these for other projects.
- AppImage extraction to `/tmp/squashfs-root` will conflict if multiple installs run concurrently.
- No `.gitignore` currently prevents `logs/` output from being committed.

---

## Suggested `.gitignore` additions
```
logs/
*.AppImage
of_vol_inlet/[1-9]*/
of_vol_inlet/0/U.orig_*
__pycache__/
*.pyc
```

---

## CHANGELOG
<!-- Append entries below. Do not edit existing entries. -->
<!-- MCP-UPDATE: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6 | Initial repoanalysis.md created — full file-by-file breakdown, architecture phases, integration points, known limitations -->
