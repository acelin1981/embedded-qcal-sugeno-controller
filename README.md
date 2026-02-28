## Run
```bash
iverilog -g2012 -o simv rtl/*.sv tb/tb_qcal_apb_top.sv
vvp simv | tee sim.log
```

## License
This project is released under the MIT License. See the header at the top of each RTL file and the LICENSE file (if present).

## Quick start (Icarus Verilog)
```bash
iverilog -g2012 -o simv tb/tb_qcal_apb_top.sv rtl/*.sv
vvp simv > run.log
```
Optional drift injection:
```bash
vvp simv +DRIFT_K=800 +DRIFT_LEN=400 +DRIFT_STEP_M=20 > run_plus.log
vvp simv +DRIFT_K=800 +DRIFT_LEN=400 +DRIFT_STEP_M=-20 > run_neg.log
```
