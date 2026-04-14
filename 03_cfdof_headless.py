#!/usr/bin/env python3
"""
03_cfdof_headless.py
====================
Run CfdOF case preparation headlessly from an existing .FCStd file.

Usage (via xvfb-run):
    xvfb-run freecadcmd 03_cfdof_headless.py -- /path/to/model.FCStd

What this script does:
  1. Opens the FreeCAD document
  2. Finds the CfdAnalysis object
  3. Writes the OpenFOAM case to disk
  4. Dumps all errors to logs/cfdof_headless_<timestamp>.log

After this runs, use 04_patch_vol_inlet.py to override the inlet BC
with flowRateInletVelocity before running the solver.
"""

import sys
import os
import traceback
import datetime

LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
TIMESTAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_FILE = os.path.join(LOG_DIR, f"cfdof_headless_{TIMESTAMP}.log")

def log(msg):
    print(msg, flush=True)
    with open(LOG_FILE, "a") as f:
        f.write(msg + "\n")

log(f"=== CfdOF Headless Run — {TIMESTAMP} ===")

# ---- Find FCStd path from CLI args --------------------------
fcstd_path = None
for i, arg in enumerate(sys.argv):
    if arg.endswith(".FCStd") and os.path.isfile(arg):
        fcstd_path = arg
        break
    if arg == "--" and i + 1 < len(sys.argv):
        fcstd_path = sys.argv[i + 1]
        break

# Fallback: look in Downloads for the Cornersteel pipe CFD file
if fcstd_path is None:
    candidates = [
        os.path.expanduser("~/Downloads/Cornersteel Pipe Thermal Flow Fused with CFD(1).FCStd"),
        os.path.expanduser("~/Downloads/Cornersteel Pipe Thermal Flow Fused with CFD.FCStd"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            fcstd_path = c
            break

if fcstd_path is None:
    log("ERROR: No .FCStd file found. Pass path as argument:")
    log("  xvfb-run freecadcmd 03_cfdof_headless.py -- /path/to/file.FCStd")
    sys.exit(1)

log(f"Opening: {fcstd_path}")

# ---- Import FreeCAD -----------------------------------------
try:
    import FreeCAD
    log(f"FreeCAD version: {FreeCAD.Version()}")
except ImportError:
    log("ERROR: FreeCAD module not importable. This script must run inside freecadcmd.")
    sys.exit(1)

# ---- Open document ------------------------------------------
try:
    doc = FreeCAD.openDocument(fcstd_path)
    log(f"Document opened. Objects: {len(doc.Objects)}")
    for obj in doc.Objects:
        log(f"  - {obj.Name} [{obj.TypeId}]")
except Exception as e:
    log(f"ERROR opening document: {e}")
    log(traceback.format_exc())
    sys.exit(1)

# ---- Find CfdAnalysis ---------------------------------------
cfd_analysis = None
for obj in doc.Objects:
    if "CfdAnalysis" in obj.TypeId or obj.Name.startswith("CfdAnalysis"):
        cfd_analysis = obj
        log(f"Found CfdAnalysis: {obj.Name}")
        break

if cfd_analysis is None:
    log("WARNING: No CfdAnalysis object found in document.")
    log("Objects with 'Cfd' in name:")
    for obj in doc.Objects:
        if "cfd" in obj.Name.lower() or "cfd" in obj.TypeId.lower():
            log(f"  {obj.Name} [{obj.TypeId}]")
    sys.exit(1)

# ---- Find CfdSolver and output dir ---------------------------
cfd_solver = None
output_dir = None
for obj in doc.Objects:
    if "CfdSolver" in obj.TypeId or obj.Name.startswith("CfdSolver"):
        cfd_solver = obj
        log(f"Found CfdSolver: {obj.Name}")
        if hasattr(obj, "OutputPath"):
            output_dir = obj.OutputPath
            log(f"  Output path: {output_dir}")
        break

# ---- Write OpenFOAM case ------------------------------------
try:
    import CfdOF
    import CfdCaseWriterFoam
    log("CfdOF imported OK")

    writer = CfdCaseWriterFoam.CfdCaseWriterFoam(cfd_analysis)
    log(f"Case writer created. Output dir: {writer.case_folder}")

    success = writer.writeCase()
    if success:
        log(f"SUCCESS: Case written to {writer.case_folder}")
        log("Contents:")
        for root, dirs, files in os.walk(writer.case_folder):
            level = root.replace(writer.case_folder, "").count(os.sep)
            indent = "  " * level
            log(f"{indent}{os.path.basename(root)}/")
            for fname in files:
                log(f"{indent}  {fname}")
    else:
        log("FAILED: Case write returned False")

except Exception as e:
    log(f"ERROR writing case: {e}")
    log(traceback.format_exc())

log(f"\n=== Complete. Log: {LOG_FILE} ===")
log("Next step: run 04_patch_vol_inlet.py to override inlet BC")
