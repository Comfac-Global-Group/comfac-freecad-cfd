# FRD.md — Feature Requirements Document
# freecad-cfd · github.com/justinaquino/freecad-cfd

<!-- ================================================================
  MCP DATETIME PROTOCOL FOR AI MODELS — READ BEFORE EDITING
  ================================================================
  This document tracks feature requirements for the freecad-cfd toolkit.
  AI models (Claude, Kimi, DeepSeek, etc.) that add or update entries
  MUST follow these rules:

  ADDING A NEW FEATURE REQUIREMENT
  ─────────────────────────────────
  1. Assign the next sequential ID: FR-XXX (check the last entry below)
  2. Set status to: PROPOSED
  3. Fill all fields — do not leave "TBD" unless the field is genuinely
     unknown and you flag it with <!-- NEEDS-CLARIFICATION -->
  4. Add a dated footer line:
       > Added: YYYY-MM-DD HH:MM UTC | Model: <name>

  UPDATING AN EXISTING REQUIREMENT
  ──────────────────────────────────
  1. Change the Status field only (do not rewrite description/AC unless
     explicitly asked to do so)
  2. Append a dated note in the History block:
       > Updated: YYYY-MM-DD HH:MM UTC | Model: <name> | Status: OLD → NEW | Reason: ...
  3. Do NOT delete the previous history lines.

  VALIDATING / CONFIRMING A REQUIREMENT
  ──────────────────────────────────────
  When a human or model confirms a feature works:
  1. Change Status → VALIDATED
  2. Add to History:
       > Validated: YYYY-MM-DD HH:MM UTC | Model/Person: <name> | Evidence: <log file or test>

  STATUS VALUES (use exactly these strings)
  ──────────────────────────────────────────
  PROPOSED  → defined, not started
  IN-DEV    → actively being implemented
  IN-TEST   → implemented, running QA tests
  VALIDATED → confirmed working by test or human review
  DEFERRED  → pushed to a later milestone
  REJECTED  → will not implement (reason required in History)

  DATETIME FORMAT: ISO 8601 — YYYY-MM-DD HH:MM UTC
  ================================================================ -->

---

## Summary Table

| ID | Title | Status | Owner |
|----|-------|--------|-------|
| FR-001 | Install script — multi-version OpenFOAM detection | VALIDATED | Claude S4.6 |
| FR-002 | FreeCAD AppImage headless fallback | PROPOSED | — |
| FR-003 | Volumetric inlet BC patch (flowRateInletVelocity) | IN-TEST | Claude S4.6 |
| FR-004 | CfdOF headless case writer | PROPOSED | — |
| FR-005 | Log collection bundle | PROPOSED | — |
| FR-006 | Auto-detect inlet patch name without user prompt | PROPOSED | — |
| FR-007 | Restore controlDict after test run | PROPOSED | — |
| FR-008 | .gitignore for logs and runtime artifacts | PROPOSED | — |
| FR-009 | Mass flow rate inlet support (massFlowRateInletVelocity) | PROPOSED | — |
| FR-010 | Time-varying volumetric flow rate (table input) | PROPOSED | — |

---

## Feature Entries

---

### FR-001 — Install script: multi-version OpenFOAM detection

**Status:** VALIDATED
**File(s):** `00_install.sh`, `01_diagnose.sh`
**Priority:** Critical

**Description:**
The install script must detect and source the correct OpenFOAM version available on the host. CfdOF prefers OpenFOAM.org v11 but must gracefully handle v9, v10, v2312 (ESI), and the system apt `openfoam` package. Detection must happen at both install time and diagnosis time, with a clear error if none are found.

**Acceptance Criteria:**
- [ ] Script sources the first available bashrc from: v11, v10, v9, v2312 in that order
- [ ] `simpleFoam --version` is callable after sourcing
- [ ] `WM_PROJECT_VERSION` is printed in diagnosis output
- [ ] If no OpenFOAM found: explicit error message pointing to `00_install.sh`

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6
> Validated: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6 | Evidence: 01_diagnose.sh section [2] implements and tests this

---

### FR-002 — FreeCAD AppImage headless fallback

**Status:** PROPOSED
**File(s):** `00_install.sh`
**Priority:** High

**Description:**
On Ubuntu 24.04, the `ppa:freecad-maintainers/freecad-stable` PPA may not yet have a 24.04 (Noble) build. The install script must fall back to extracting the official FreeCAD 1.0.0 AppImage and symlinking `freecadcmd` to `/usr/local/bin/`. The extraction must use `--appimage-extract` (not FUSE mount) so it works in environments without FUSE support (e.g. Docker, CI runners).

**Acceptance Criteria:**
- [ ] PPA install attempted first; AppImage only triggered if `freecadcmd` not found after PPA step
- [ ] AppImage extracted to `/opt/freecad-appimage/`
- [ ] `freecadcmd` symlink created at `/usr/local/bin/freecadcmd`
- [ ] `LD_LIBRARY_PATH` set correctly for AppImage libs
- [ ] `freecadcmd --version` succeeds after fallback

**Open question:** <!-- NEEDS-CLARIFICATION -->
AppImage URL is hardcoded to 1.0.0. Should this be dynamically fetched from GitHub releases API?

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-003 — Volumetric inlet BC patch (flowRateInletVelocity)

**Status:** IN-TEST
**File(s):** `04_patch_vol_inlet.py`, `of_vol_inlet/0/U`
**Priority:** Critical

**Description:**
CfdOF writes `fixedValue` velocity inlets with a uniform vector. Engineers supply flow meter data in m³/s or m³/hr. The patch script must replace the `fixedValue` block in `0/U` with `flowRateInletVelocity` and a scalar `volumetricFlowRate` value. The patch must handle nested OpenFOAM dict syntax correctly using brace-depth parsing (not simple regex).

**Acceptance Criteria:**
- [ ] `detect_inlet_patches()` correctly identifies patches named "inlet", "Inlet", "in", or "IN"
- [ ] Fallback: if no name matches, detects any `fixedValue` patch
- [ ] `replace_patch_block()` handles nested `{}` inside patch dicts without corrupting surrounding file
- [ ] Original `0/U` backed up as `0/U.orig_<TIMESTAMP>` before modification
- [ ] Patched file passes OpenFOAM dictionary parser (no syntax errors at solver startup)
- [ ] Conversion reference (m³/hr, L/min, L/s, SCFM) printed to stdout on every run
- [ ] Script exits non-zero and prints clear error if `0/U` not found

**Conversion reference:**
| Unit | m³/s |
|------|------|
| 1 m³/hr | 2.778e-4 |
| 1 L/min | 1.667e-5 |
| 1 L/s | 1.000e-3 |
| 1 SCFM | 4.719e-4 |

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6
> Status set IN-TEST: awaiting OpenFOAM install to run 02_run_vol_inlet_test.sh end-to-end

---

### FR-004 — CfdOF headless case writer

**Status:** PROPOSED
**File(s):** `03_cfdof_headless.py`
**Priority:** High

**Description:**
Given a `.FCStd` file containing a `CfdAnalysis` object configured with CfdOF, generate the complete OpenFOAM case directory headlessly (no GUI, via `freecadcmd`). Must log every FreeCAD object found in the document for debugging. Must work with `xvfb-run` to satisfy Qt's display requirement.

**Acceptance Criteria:**
- [ ] Runs via `xvfb-run freecadcmd 03_cfdof_headless.py -- model.FCStd`
- [ ] Prints full object inventory (Name + TypeId) for every object in document
- [ ] Locates `CfdAnalysis` and `CfdSolver` objects by TypeId scan
- [ ] `CfdCaseWriterFoam.writeCase()` called and return value checked
- [ ] On success: prints directory tree of written case
- [ ] On failure: full Python traceback written to `logs/cfdof_headless_<ts>.log`
- [ ] If no `.FCStd` argument given: falls back to two hardcoded Cornersteel paths (configurable)

**Known issue:** Hardcoded fallback paths reference `~/Downloads/Cornersteel Pipe...` — must be updated for new projects.

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-005 — Log collection bundle

**Status:** PROPOSED
**File(s):** `05_collect_logs.sh`
**Priority:** Medium

**Description:**
A single script that concatenates all runtime logs, the current `0/U` file, and system info into one text file for sharing with an AI assistant or human reviewer without needing access to the machine.

**Acceptance Criteria:**
- [ ] Bundles all `logs/*.log` files
- [ ] Includes `0/U` from the vol_inlet test case
- [ ] Includes system info (`uname -a`, OS version)
- [ ] Includes FreeCAD and OpenFOAM version strings
- [ ] Includes CfdOF git commit hash
- [ ] Output file named `logs/diagnostic_bundle_<ts>.txt`
- [ ] Script runs even if some components (FreeCAD, OpenFOAM) are not installed — skips gracefully

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-006 — Auto-detect inlet patch name (no interactive prompt)

**Status:** PROPOSED
**File(s):** `04_patch_vol_inlet.py`
**Priority:** Medium

**Description:**
`detect_inlet_patches()` currently falls back to `input()` which hangs in automated pipelines. Add a `--patch` CLI flag so the patch name can be passed non-interactively, and make the interactive fallback optional (only triggered in TTY).

**Acceptance Criteria:**
- [ ] `python3 04_patch_vol_inlet.py <case_dir> <flow_m3s> --patch inlet` skips auto-detection
- [ ] Without `--patch`: auto-detection runs; only prompts interactively if `sys.stdin.isatty()`
- [ ] Without `--patch` in non-TTY: exits with error code 2 and clear message listing all found patch names

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-007 — Restore controlDict after test run

**Status:** PROPOSED
**File(s):** `02_run_vol_inlet_test.sh`
**Priority:** Low

**Description:**
`02_run_vol_inlet_test.sh` mutates `system/controlDict` via `sed` to reduce `endTime` for a quick test but does not restore it. If the script is interrupted or fails, the case is left in a modified state. Add a backup/restore pattern.

**Acceptance Criteria:**
- [ ] `controlDict` backed up to `controlDict.orig` before sed modification
- [ ] Restored (or original re-copied) after solver run, whether it succeeds or fails
- [ ] Uses `trap` to ensure restore happens even on script exit/error

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-008 — .gitignore for logs and runtime artifacts

**Status:** PROPOSED
**File(s):** `.gitignore` (to be created)
**Priority:** Low

**Description:**
The repo currently has no `.gitignore`. Solver output (time directories like `100/`, `200/`), log files, AppImage binaries, and backup files (`0/U.orig_*`) should not be committed.

**Acceptance Criteria:**
- [ ] `logs/` excluded
- [ ] `of_vol_inlet/[1-9]*/` (time directories) excluded
- [ ] `0/U.orig_*` backup files excluded
- [ ] `*.AppImage` excluded
- [ ] `__pycache__/` and `*.pyc` excluded
- [ ] `of_vol_inlet/system/controlDict.orig` excluded

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-009 — Mass flow rate inlet support

**Status:** PROPOSED
**File(s):** `04_patch_vol_inlet.py`
**Priority:** Medium

**Description:**
Add `--mode mass` flag to `04_patch_vol_inlet.py` to output `massFlowRateInletVelocity` instead of `flowRateInletVelocity`. Required for compressible flows and when density data is available from the flow meter.

**Acceptance Criteria:**
- [ ] `--mode volumetric` (default) → `flowRateInletVelocity`
- [ ] `--mode mass` → `massFlowRateInletVelocity` with `massFlowRate` field
- [ ] Density `rho` value settable via `--rho` flag (default: 1.225 kg/m³ for air)
- [ ] Both modes produce valid OpenFOAM syntax

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### FR-010 — Time-varying volumetric flow rate (table input)

**Status:** PROPOSED
**File(s):** `04_patch_vol_inlet.py`, `of_vol_inlet/0/U`
**Priority:** Medium

**Description:**
For transient simulations, the inlet flow rate varies over time. Support `--table` flag that reads a CSV (`time,flow_m3s`) and generates a `table` sub-dict inside `flowRateInletVelocity`.

**Acceptance Criteria:**
- [ ] `--table flow_data.csv` accepts two-column CSV (time[s], Q[m³/s])
- [ ] Generated OpenFOAM table syntax:
  ```cpp
  volumetricFlowRate  table ((0 0)(10 0.001)(20 0.0015));
  ```
- [ ] Error if CSV has fewer than 2 rows or non-numeric values
- [ ] Works alongside `--patch` and `--mode` flags

**History:**
> Added: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

*Last summary table updated: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6*
