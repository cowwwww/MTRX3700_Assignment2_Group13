#!/bin/sh
# ModelSim (ASE 10.5b on the Quartus VM): every bench, the way the A1 scaffold does it.
#   sh run_msim.sh            (from the project root; needs images/barcode.hex)
set -e
export PATH=/opt/intelFPGA_lite/18.1/modelsim_ase/bin:$PATH
RTL="rtl/conv3x3.sv rtl/sobel.sv rtl/col_profile.sv rtl/peak_pick.sv rtl/bar_decode.sv rtl/image_rom.sv rtl/raster_source.sv rtl/cdc_latch.sv rtl/display.sv rtl/barcode_reader.sv"
rm -rf work; vlib work
vlog -quiet -sv $RTL tb/vga_monitor_model.sv tb/tb_conv3x3.sv tb/tb_col_profile.sv tb/tb_peak_pick.sv tb/tb_bar_decode.sv tb/tb_reader_only.sv tb/barcode_system_tb.sv
for tb in tb_conv3x3 tb_col_profile tb_peak_pick tb_bar_decode tb_reader_only; do
  echo "== $tb"
  vsim -c -quiet -do "onbreak {quit -code 1}; onfinish exit; run -all" work.$tb +expect=A5 | grep -E "PASS|FAIL|result|TIMEOUT|Error" || true
done
echo "== barcode_system_tb at 160x120 (ModelSim on the VM is slow; the picture is the top-left quarter)"
vsim -c -quiet -gH_RES=160 -gV_RES=120 -do "onbreak {quit -code 1}; onfinish exit; run -all" work.barcode_system_tb +expect=A5 | grep -E "PASS|FAIL|result|latched|Error" || true
