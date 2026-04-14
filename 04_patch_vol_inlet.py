#!/usr/bin/env python3
"""
04_patch_vol_inlet.py
======================
After CfdOF writes the OpenFOAM case, this script patches the inlet
boundary condition in 0/U from CfdOF's default (fixedValue) to
flowRateInletVelocity (volumetric flow rate).

Usage:
    python3 04_patch_vol_inlet.py <case_dir> [flow_rate_m3s]

    case_dir        — path to the OpenFOAM case folder written by CfdOF
    flow_rate_m3s   — volumetric flow rate in m³/s (default: 0.001 = 1 L/s)

Example:
    python3 04_patch_vol_inlet.py ~/cfd_output/case_pipe 0.0005

Why this is needed:
    CfdOF writes inlet velocity as fixedValue with a uniform vector.
    OpenFOAM's flowRateInletVelocity instead takes Q (m³/s) and
    auto-computes velocity = Q / faceArea. This is what you want when
    your input data is a flow meter reading, not a velocity.

Conversion reference:
    1 m³/hr  = 2.778e-4 m³/s
    1 L/min  = 1.667e-5 m³/s
    1 L/s    = 1.000e-3 m³/s
    1 SCFM   = 4.719e-4 m³/s  (standard cubic feet per minute)
"""

import sys
import os
import re
import shutil
import datetime

TIMESTAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

def find_u_file(case_dir):
    """Find the U velocity field file (may be in 0/ or 0.orig/)."""
    for sub in ["0", "0.orig"]:
        p = os.path.join(case_dir, sub, "U")
        if os.path.isfile(p):
            return p
    return None

def detect_inlet_patches(u_content):
    """Return list of patch names that look like inlets."""
    inlets = []
    # Match patch blocks with 'inlet' in the name or fixedValue type
    pattern = re.finditer(
        r'(\w+)\s*\{[^}]*type\s+(fixedValue|flowRateInletVelocity|uniformFixedValue)[^}]*\}',
        u_content, re.DOTALL
    )
    for m in pattern:
        name = m.group(1)
        if "inlet" in name.lower() or "in" == name.lower():
            inlets.append(name)
    if not inlets:
        # Fallback: any fixedValue patch
        for m in re.finditer(r'(\w+)\s*\{[^}]*type\s+fixedValue[^}]*\}', u_content, re.DOTALL):
            inlets.append(m.group(1))
    return list(set(inlets))

def patch_inlet_bc(u_path, patch_name, flow_rate_m3s):
    """Replace the inlet patch BC with flowRateInletVelocity."""
    with open(u_path) as f:
        content = f.read()

    # Back up original
    backup = u_path + f".orig_{TIMESTAMP}"
    shutil.copy(u_path, backup)
    print(f"  Backup: {backup}")

    # Build the new patch block
    new_block = f"""    {patch_name}
    {{
        // --- Patched by 04_patch_vol_inlet.py ---
        // flowRateInletVelocity: OpenFOAM computes U = Q/A automatically.
        type                flowRateInletVelocity;
        volumetricFlowRate  {flow_rate_m3s};  // m³/s
        value               uniform (0 0 0);
    }}"""

    # Match and replace the existing patch block
    # Pattern: patch_name { ... } (non-greedy, respects nested braces level 1)
    pattern = rf'(\s*{re.escape(patch_name)}\s*\{{[^{{}}]*\}})'
    # Use a more robust approach: find the block by scanning brace depth
    result = replace_patch_block(content, patch_name, new_block)

    with open(u_path, "w") as f:
        f.write(result)
    print(f"  Patched: {u_path}")
    return True

def replace_patch_block(content, patch_name, new_block):
    """Replace a named OpenFOAM patch block, handling nested braces."""
    # Find start of patch block
    start_pattern = re.compile(rf'\b{re.escape(patch_name)}\s*\{{')
    m = start_pattern.search(content)
    if not m:
        print(f"  WARNING: patch '{patch_name}' not found in U file — appending.")
        # Append before closing brace of boundaryField
        bf_end = content.rfind("}")
        bf_end2 = content.rfind("}", 0, bf_end)
        return content[:bf_end2] + "\n" + new_block + "\n" + content[bf_end2:]

    start = m.start()
    brace_start = m.end() - 1  # position of the opening {

    # Walk forward counting braces
    depth = 0
    end = brace_start
    for i, ch in enumerate(content[brace_start:], brace_start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    # Preserve leading whitespace from original
    leading = re.match(r'\s*', content[start:]).group()
    return content[:start] + new_block + "\n" + content[end:]

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 04_patch_vol_inlet.py <case_dir> [flow_rate_m3s]")
        print("  case_dir       — OpenFOAM case directory")
        print("  flow_rate_m3s  — volumetric flow rate in m³/s (default 0.001)")
        sys.exit(1)

    case_dir = sys.argv[1]
    flow_rate = float(sys.argv[2]) if len(sys.argv) > 2 else 0.001

    print(f"Case dir:   {case_dir}")
    print(f"Flow rate:  {flow_rate} m³/s  ({flow_rate * 3600:.4f} m³/hr = {flow_rate * 1000:.4f} L/s)")

    if not os.path.isdir(case_dir):
        print(f"ERROR: directory not found: {case_dir}")
        sys.exit(1)

    u_path = find_u_file(case_dir)
    if not u_path:
        print(f"ERROR: 0/U not found in {case_dir}")
        sys.exit(1)

    print(f"U file:     {u_path}")

    with open(u_path) as f:
        content = f.read()

    inlets = detect_inlet_patches(content)
    if not inlets:
        print("WARNING: No inlet patches auto-detected. Common names: inlet, Inlet, in")
        patch_name = input("Enter inlet patch name (from 0/U boundaryField): ").strip()
        inlets = [patch_name]

    print(f"Inlet patches found: {inlets}")
    for patch in inlets:
        patch_inlet_bc(u_path, patch, flow_rate)

    print()
    print("=== Patch complete ===")
    print(f"Now run simpleFoam from: {case_dir}")
    print(f"  cd {case_dir} && simpleFoam | tee simpleFoam.log")

if __name__ == "__main__":
    main()
