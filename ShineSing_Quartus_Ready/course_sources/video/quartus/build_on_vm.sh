#!/bin/sh
# Run ON THE QUARTUS VM from the quartus/ directory:  sh build_on_vm.sh
# 1) generate vga_sink.qsys from the script, 2) compile, 3) leave output_files/barcode.sof
set -e
export PATH=/opt/intelFPGA_lite/18.1/quartus/bin:/opt/intelFPGA_lite/18.1/quartus/sopc_builder/bin:$PATH
[ -f vga_sink.qsys ] || qsys-script --script=make_vga_sink_qsys.tcl
qsys-generate vga_sink.qsys --synthesis=VERILOG --family="Cyclone V" --part=5CSEMA5F31C6
quartus_sh --flow compile barcode
grep -E "Total logic|Total block memory|DSP Blocks|Logic utilization" output_files/barcode.fit.summary || true
ls -la output_files/barcode.sof
# a picture ROM that Quartus could not initialise is a black screen on the board: fail loudly
if grep -q "Critical Warning (127003)" output_files/*.map.rpt 2>/dev/null; then echo "BUILD FAILED: a .mif was not found (Critical Warning 127003): check SEARCH_PATH"; exit 1; fi
