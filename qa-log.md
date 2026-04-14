# qa-log.md — QA Problem Log
# freecad-cfd · github.com/justinaquino/freecad-cfd

<!-- ================================================================
  MCP DATETIME PROTOCOL FOR AI MODELS — READ BEFORE LOGGING
  ================================================================
  This file records every problem, error, and test result encountered
  while running the freecad-cfd toolkit. AI models (Claude, Kimi,
  DeepSeek, etc.) and humans MUST follow these rules when updating.

  ── LOGGING A NEW PROBLEM ─────────────────────────────────────────
  1. Copy the TEMPLATE below and paste it at the top of the LOG ENTRIES
     section (newest entries first).
  2. Assign the next sequential ID: QA-XXX
  3. Set status to OPEN
  4. Paste the EXACT error text in the Error Output block — do not
     paraphrase. Truncate only if > 100 lines; mark truncation with
     [... truncated N lines ...]
  5. Fill in all fields. Use <!-- UNKNOWN --> only if genuinely unknown.

  ── UPDATING AN EXISTING ENTRY ────────────────────────────────────
  1. Append a dated STATUS UPDATE line inside the entry — do not
     overwrite the original fields.
  2. If resolved: change Status to RESOLVED and fill Resolution field.
  3. If confirmed fixed: change Status to CLOSED.

  ── CONFIRMING / VALIDATING A FIX ─────────────────────────────────
  1. Run the relevant test (script or command listed in Reproduce Steps)
  2. If it passes: add VALIDATED line with evidence (log filename or
     command output excerpt)
  3. Change Status to CLOSED only after human or model confirms the fix
     is in the committed code.

  STATUS VALUES (use exactly these strings):
    OPEN       → problem reported, not yet investigated
    IN-WORK    → being actively diagnosed or fixed
    RESOLVED   → fix applied to code, not yet re-tested
    VALIDATED  → fix confirmed by re-test
    CLOSED     → validated + merged/committed
    WONTFIX    → acknowledged, will not be fixed (reason required)
    DUPLICATE  → duplicate of another QA entry (link it)

  SEVERITY LEVELS:
    P1 — Blocker: nothing runs at all
    P2 — Critical: main workflow fails
    P3 — Major: feature broken but workaround exists
    P4 — Minor: cosmetic or edge case
    P5 — Info: observation, not a failure

  DATETIME FORMAT: ISO 8601 — YYYY-MM-DD HH:MM UTC
  ================================================================ -->

---

## TEMPLATE
<!-- Copy this block when logging a new issue — fill in all fields -->
<!--
### QA-XXX — <short title>

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P? |
| **Date Logged** | YYYY-MM-DD HH:MM UTC |
| **Logged By** | Model: <name> or Person: <name> |
| **Script/File** | `filename.sh` or `filename.py` |
| **OpenFOAM Version** | vXX or NOT SET |
| **FreeCAD Version** | X.X.X or NOT INSTALLED |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-XXX or — |

**Description:**
One paragraph describing what went wrong and what was expected.

**Reproduce Steps:**
```bash
# exact commands to reproduce
```

**Error Output:**
```
exact error text here
```

**Root Cause:**
<!-- leave blank (OPEN) or fill when diagnosed -->

**Resolution:**
<!-- leave blank (OPEN) or fill when fixed -->

**History:**
> Logged: YYYY-MM-DD HH:MM UTC | Model: <name>
-->

---

## Summary Table

| ID | Title | Severity | Status | Date |
|----|-------|----------|--------|------|
| QA-001 | OpenFOAM 1912 apt package too old for flowRateInletVelocity | P2 | OPEN | 2026-04-14 |
| QA-002 | FreeCAD PPA may not have Ubuntu 24.04 Noble build | P1 | OPEN | 2026-04-14 |
| QA-003 | 02_run_vol_inlet_test.sh mutates controlDict permanently | P4 | OPEN | 2026-04-14 |
| QA-004 | 04_patch_vol_inlet.py hangs on input() in non-TTY | P3 | OPEN | 2026-04-14 |
| QA-005 | 03_cfdof_headless.py hardcoded fallback paths | P4 | OPEN | 2026-04-14 |

---

## LOG ENTRIES
<!-- Newest entries at top -->

---

### QA-005 — 03_cfdof_headless.py hardcoded fallback FCStd paths

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P4 |
| **Date Logged** | 2026-04-14 08:10 UTC |
| **Logged By** | Model: Claude Sonnet 4.6 |
| **Script/File** | `03_cfdof_headless.py` |
| **OpenFOAM Version** | any |
| **FreeCAD Version** | any |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-004 |

**Description:**
`03_cfdof_headless.py` lines 49–56 hardcode two fallback FCStd paths pointing to the Cornersteel pipe model in `~/Downloads/`. These will silently fail (or silently succeed with the wrong file) on any other user's machine or project.

**Reproduce Steps:**
```bash
# Run without a CLI argument on a machine without the Cornersteel file:
xvfb-run freecadcmd 03_cfdof_headless.py
# Expected: clear error asking for --file argument
# Actual: ERROR: No .FCStd file found (acceptable) but no hint to
#         set a project-level default
```

**Error Output:**
```
ERROR: No .FCStd file found. Pass path as argument:
  xvfb-run freecadcmd 03_cfdof_headless.py -- /path/to/file.FCStd
```

**Root Cause:**
Convenience fallback was added for the Cornersteel project but not generalised. No environment variable or config file override.

**Resolution:**
<!-- pending -->
Suggested fix: check env var `CFDOF_FCSTD` before the hardcoded candidates. Document in README.

**History:**
> Logged: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### QA-004 — 04_patch_vol_inlet.py hangs on input() in non-TTY context

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P3 |
| **Date Logged** | 2026-04-14 08:10 UTC |
| **Logged By** | Model: Claude Sonnet 4.6 |
| **Script/File** | `04_patch_vol_inlet.py` |
| **OpenFOAM Version** | any |
| **FreeCAD Version** | any |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-006 |

**Description:**
When `detect_inlet_patches()` finds no inlet patches (e.g. patch name is `BC_inlet_01` not `inlet`), the script calls `input()` to ask for the patch name. In a CI pipeline, cron job, or any non-interactive shell, this call blocks indefinitely.

**Reproduce Steps:**
```bash
# Rename the inlet patch in 0/U to something non-standard:
sed -i 's/inlet/BC_in_01/g' of_vol_inlet/0/U
# Run patch script piped (non-TTY):
echo "" | python3 04_patch_vol_inlet.py of_vol_inlet 0.001
# → hangs waiting for input
```

**Error Output:**
```
# No output — process hangs on input() call
```

**Root Cause:**
`input()` on line 157 of `04_patch_vol_inlet.py` is unconditional. No TTY check, no `--patch` CLI override.

**Resolution:**
<!-- pending -->
Fix per FR-006: add `--patch` flag; guard `input()` with `sys.stdin.isatty()`.

**History:**
> Logged: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### QA-003 — 02_run_vol_inlet_test.sh permanently mutates system/controlDict

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P4 |
| **Date Logged** | 2026-04-14 08:10 UTC |
| **Logged By** | Model: Claude Sonnet 4.6 |
| **Script/File** | `02_run_vol_inlet_test.sh` |
| **OpenFOAM Version** | any |
| **FreeCAD Version** | any |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-007 |

**Description:**
Line 54 of `02_run_vol_inlet_test.sh` uses `sed` to change `endTime` from 500 to 200 for a quick test, but writes back to the original file without backup or restore. If the script is killed mid-run, the committed `controlDict` is permanently altered to 200 iterations.

**Reproduce Steps:**
```bash
bash 02_run_vol_inlet_test.sh
# Then check:
grep endTime of_vol_inlet/system/controlDict
# Expected: endTime 500
# Actual:   endTime       200
```

**Error Output:**
```
# No error — silent data mutation
```

**Root Cause:**
`sed 's/.../...' file > file.tmp && mv file.tmp file` pattern with no restore step or `trap`.

**Resolution:**
<!-- pending -->
Fix per FR-007: `cp controlDict controlDict.orig` before sed; `trap 'cp controlDict.orig controlDict' EXIT`.

**History:**
> Logged: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### QA-002 — FreeCAD PPA may not have Ubuntu 24.04 Noble build

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P1 |
| **Date Logged** | 2026-04-14 08:10 UTC |
| **Logged By** | Model: Claude Sonnet 4.6 |
| **Script/File** | `00_install.sh` |
| **OpenFOAM Version** | any |
| **FreeCAD Version** | 1.0.x (target) |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-002 |

**Description:**
`ppa:freecad-maintainers/freecad-stable` historically lags behind Ubuntu release cycles. As of mid-2026 it may not have a `noble` (24.04) package, causing `apt-get install freecad` to fail with "E: Unable to locate package freecad" or install an outdated version from the Ubuntu main archive (0.20.x). The AppImage fallback in `00_install.sh` should activate, but the `if ! command -v freecadcmd` guard may fail if an old version was installed by the PPA step.

**Reproduce Steps:**
```bash
# On a clean Ubuntu 24.04 VM:
sudo add-apt-repository ppa:freecad-maintainers/freecad-stable
sudo apt-get update
apt-cache policy freecad
# Check if Noble packages appear or only Jammy/Focal
```

**Error Output:**
```
# Possible outputs depending on PPA state:
E: Unable to locate package freecad
# OR:
freecad:
  Installed: 0.20.2+dfsg1-1ubuntu1
  Candidate: 0.20.2+dfsg1-1ubuntu1   ← too old
```

**Root Cause:**
PPA build status unknown at time of writing. `00_install.sh` does not check the installed version before proceeding to the AppImage fallback guard.

**Resolution:**
<!-- pending — needs live test on clean Ubuntu 24.04 VM -->
Suggested: after PPA install, check `freecadcmd --version` and verify it reports ≥ 1.0.0. If not, force AppImage fallback regardless of whether the binary exists.

**History:**
> Logged: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

### QA-001 — OpenFOAM apt package (v1912) too old for flowRateInletVelocity

| Field | Value |
|-------|-------|
| **Status** | OPEN |
| **Severity** | P2 |
| **Date Logged** | 2026-04-14 08:10 UTC |
| **Logged By** | Model: Claude Sonnet 4.6 |
| **Script/File** | `02_run_vol_inlet_test.sh`, `of_vol_inlet/0/U` |
| **OpenFOAM Version** | 1912 (apt default on Ubuntu 24.04) |
| **FreeCAD Version** | any |
| **OS** | Ubuntu 24.04 LTS |
| **Related FR** | FR-003 |

**Description:**
The Ubuntu 24.04 apt repository contains `openfoam` package version `1912.200626`, which is OpenFOAM ESI v1912 (released 2019). The `flowRateInletVelocity` boundary condition exists in this version but is limited — it may not support the `volumetricFlowRate` scalar keyword used in OpenFOAM.org v9+. If a user runs `sudo apt install openfoam` without reading the install script, the test case in `of_vol_inlet/` will fail at solver startup.

**Reproduce Steps:**
```bash
# Install ONLY the system apt package (not openfoam11):
sudo apt install openfoam
source /usr/lib/openfoam/openfoam2306/etc/bashrc  # or similar path
cd of_vol_inlet
blockMesh
simpleFoam
```

**Error Output:**
```
# Expected (if BC keyword not recognised in v1912):
--> FOAM FATAL IO ERROR:
    Unknown patchField type flowRateInletVelocity
    ...
# OR solver crashes at boundary condition initialisation
```

**Root Cause:**
`00_install.sh` installs OpenFOAM.org v11 but does not remove the system apt `openfoam` package. If the user's `PATH` picks up the apt version first, the wrong OpenFOAM is used. `01_diagnose.sh` prints `WM_PROJECT_VERSION` which will reveal the mismatch.

**Resolution:**
<!-- pending — needs test with v1912 -->
Mitigation already in place: `01_diagnose.sh` prints version. Hard fix: add version assertion to `02_run_vol_inlet_test.sh` — refuse to run if `WM_PROJECT_VERSION` < 9.

**History:**
> Logged: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6

---

## Test Run Records
<!-- Append dated test run summaries here after running the scripts -->

| Date | Script | Result | OF Version | FreeCAD Version | Notes |
|------|--------|--------|------------|-----------------|-------|
| — | — | — | — | — | No runs recorded yet |

---

*Log initialised: 2026-04-14 08:10 UTC | Model: Claude Sonnet 4.6*
