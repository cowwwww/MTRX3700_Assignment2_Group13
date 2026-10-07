#!/bin/sh
# Barcode reader mini-project: unit benches, then the whole system with the VGA monitor model.
#   ./simulate.sh            all benches
#   ./simulate.sh system     system bench only (writes frame_1.png, frame_2.png)
#   ./simulate.sh unit       unit benches only
# Verilator 5 (--timing). Run from the project root. Images: tools/make_barcode.py --code 0xA5
set -e
export LC_ALL=C
what="${1:-all}"
RTL="rtl/conv3x3.sv rtl/sobel.sv rtl/col_profile.sv rtl/peak_pick.sv rtl/bar_decode.sv rtl/image_rom.sv rtl/raster_source.sv rtl/cdc_latch.sv rtl/display.sv rtl/barcode_reader.sv"
run() {  # $1 = testbench module, $2 = extra sources, $3 = plusargs
  rm -rf obj_dir
  verilator -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM --trace-fst --timing --assert --top "$1" --cc tb/$1.sv $2 --main --exe -o V$1 > verilator_$1.log 2>&1 || { tail -30 verilator_$1.log; exit 1; }
  make -s -C obj_dir -f V$1.mk V$1 > /dev/null
  ./obj_dir/V$1 $3 | tee sim_$1.log | grep -E "PASS|FAIL|result|display|edges" 
}
[ ! -f images/barcode.hex ] && python3 tools/make_barcode.py --code 0xA5
if [ "$what" = all ] || [ "$what" = unit ]; then
  run tb_conv3x3     "rtl/conv3x3.sv"
  run tb_col_profile "rtl/col_profile.sv"
  run tb_peak_pick   "rtl/peak_pick.sv"
  run tb_bar_decode  "rtl/bar_decode.sv"
fi
if [ "$what" = all ] || [ "$what" = system ]; then
  run barcode_system_tb "$RTL tb/vga_monitor_model.sv" "+expect=A5"
  run barcode_system_tb "$RTL tb/vga_monitor_model.sv -GMIF_FILE=\"images/barcode2.mif\" -GHEX_FILE=\"images/barcode2.hex\"" "+expect=3C"
  python3 tools/render_frames.py; rm -f frame_*.ppm
fi
grep -h "PASS\|FAILED" sim_*.log
