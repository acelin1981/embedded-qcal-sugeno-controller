---

# QCAL – Embedded Calibration Controller (Singleton Sugeno Fuzzy, Verilog)
Publish:https://www.ijcaonline.org/archives/volume187/number95/embedded-calibration-for-cryogenic-quantum-devices-using-a-singleton-sugeno-fuzzy-controller/

This repository contains a **cycle-accurate Verilog prototype** of an embedded, hostless calibration controller for cryogenic quantum-device readout/control experiments.  
The controller implements a **3×3 Singleton Sugeno fuzzy** update law using fixed-point arithmetic and provides a lightweight **monitor mode** for drift sensitivity.

## What this repo provides
- **RTL controller core** (fixed-point, deterministic update/monitor flow)
- **APB register interface** for configuration/telemetry (no wait states)
- **Self-contained simulation harness (TB)** with:
  - simplified success-probability plant model
  - bounded pseudo-random noise
  - optional injected drift window (bidirectional via plusargs)
- **MIT License** (see `LICENSE` and per-file headers)

## Directory structure
- `rtl/` – synthesizable RTL modules
- `tb/` – simulation testbench (`tb_qcal_apb_top.sv`)
- `LICENSE` – MIT license
- `README.md` – this file

## Quick start (Icarus Verilog)
From the repo root:

```bash
iverilog -g2012 -o simv tb/tb_qcal_apb_top.sv rtl/*.sv
vvp simv > run.log
```

### Drift injection (paper benchmark default)
The testbench supports these plusargs:
- `DRIFT_K` – drift start poll index (default: 800)
- `DRIFT_LEN` – drift duration in polls (default: 400)
- `DRIFT_STEP_M` – drift step in milli-units (e.g., 20 ⇒ 0.020)

Run **positive** drift:
```bash
vvp simv +DRIFT_K=800 +DRIFT_LEN=400 +DRIFT_STEP_M=20 > run_plus.log
```

Run **negative** drift:
```bash
vvp simv +DRIFT_K=800 +DRIFT_LEN=400 +DRIFT_STEP_M=-20 > run_neg.log
```

## How to read the logs
The TB prints a per-poll summary like:

- `k` – poll index
- `BUSY` – controller is in update (calibration) mode
- `CONV` – convergence flag
- `DRIFT` – TB drift window active (injected)
- `UPD` – update counter
- `AMP` – calibrated parameter `amp(k)` (Q4.12 displayed as real)
- `E` – current error `e(k)` (Q4.12 displayed as real)

These fields correspond directly to the results figures/tables in the associated paper draft.

## APB register map (key addresses)
Base addresses are from `rtl/qcal_apb.sv`.

- `0x000 A_CTRL` – bit0: mode_sel (manual table write enable), bit1: start_pulse (write 1 to pulse)
- `0x010 A_RULE_ADDR` – rule index [3:0] (0..8)
- `0x014 A_RULE_DATA` – rule delta (signed 16-bit Q4.12 in [15:0])
- `0x018 A_RULE_WR` – write 1 to commit rule entry
- `0x020 A_STATUS` – {oscillating, converged, busy}
- `0x024 A_AMP` – current `amp` (signed 16-bit Q4.12)
- `0x028 A_LAST_E` – last `e` (signed 16-bit Q4.12)
- `0x02C A_LAST_D` – last `delta` (signed 16-bit Q4.12)
- `0x030 A_UPD_CNT` – update counter
- `0x034/0x038` – rule table readback (addr/data)
- `0x03C A_LAST_DE` – last `de`
- `0x040 A_LAST_PMEAS` – last `p_meas`

```

## License
MIT License. See `LICENSE`.
