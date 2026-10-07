#!/bin/sh
# Runs the provided classifier's self-checking bench in Verilator 5: prints PASS or FAIL, writes waveform.fst.
set -e
verilator --binary -Wno-fatal --timing -j 0 --top-module tb_classifier tb_classifier.sv classifier.sv -o sim 2>&1 | grep -E "^%Error" || true
./obj_dir/sim | grep -v "^- "
