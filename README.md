# FreeCAD + CfdOF + OpenFOAM — Headless Diagnostic Setup

## Workflow

```
00_install.sh          → Install FreeCAD, OpenFOAM, CfdOF workbench
01_diagnose.sh         → Check everything is working
02_run_vol_inlet_test.sh → Test volumetric inlet BC on a pipe case
03_cfdof_headless.py   → Write OF case from .FCStd file (headlessly)
04_patch_vol_inlet.py  → Override inlet BC to flowRateInletVelocity
05_collect_logs.sh     → Bundle all logs for sharing / review
```

## Step-by-step

### 1. Install everything
```bash
cd /home/justin/opencode260220/freecad-cfd
bash 00_install.sh 2>&1 | tee logs/install.log
```

### 2. Diagnose the environment
```bash
bash 01_diagnose.sh 2>&1 | tee logs/diagnose.log
```

### 3. Test volumetric inlet BC
```bash
bash 02_run_vol_inlet_test.sh 2>&1 | tee logs/vol_inlet_test.log
```

### 4. Write OpenFOAM case from your FCStd model
```bash
xvfb-run freecadcmd 03_cfdof_headless.py \
  -- ~/Downloads/"Cornersteel Pipe Thermal Flow Fused with CFD(1).FCStd" \
  2>&1 | tee logs/cfdof_case_write.log
```

### 5. Patch the inlet BC to accept volumetric flow rate
```bash
# Adjust flow rate in m³/s (1 L/s = 0.001, 1 m³/hr = 2.778e-4)
python3 04_patch_vol_inlet.py <case_output_dir> 0.001
```

### 6. Run the solver
```bash
source /opt/openfoam11/etc/bashrc
cd <case_output_dir>
simpleFoam 2>&1 | tee simpleFoam.log
```

### 7. Collect all logs for diagnosis
```bash
bash 05_collect_logs.sh
# Share the output file with your AI assistant
```

## The volumetric inlet problem explained

CfdOF by default writes `fixedValue` for velocity inlets — you specify
a fixed velocity vector (e.g. `(1 0 0)` m/s).

**You want `flowRateInletVelocity`** — you give it a volumetric flow rate
`Q` in m³/s and OpenFOAM computes `U = Q / faceArea` automatically.

```cpp
// In 0/U boundaryField:
inlet
{
    type                flowRateInletVelocity;
    volumetricFlowRate  0.001;   // 1 L/s = 3.6 m³/hr
    value               uniform (0 0 0);
}
```

The `04_patch_vol_inlet.py` script automatically replaces the CfdOF-generated
`fixedValue` block with the above pattern.

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `unknown type flowRateInletVelocity` | OpenFOAM version too old | Install openfoam11 via 00_install.sh |
| `Cannot find patchField` | Wrong patch name | Check `0/U` for actual patch names |
| `simpleFoam: command not found` | OF not sourced | `source /opt/openfoam11/etc/bashrc` first |
| `No module named CfdOF` | Workbench not in path | Check `~/.local/share/FreeCAD/Mod/CfdOF` |
| `Segmentation fault` in freecadcmd | Missing display | Use `xvfb-run freecadcmd ...` |
