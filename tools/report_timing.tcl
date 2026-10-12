# Run after fitting the design: quartus_sta -t tools/report_timing.tcl
# Show paths for the default slow timing case. Use the normal STA report
# for setup and hold results across all timing cases.
project_open shine_sing
create_timing_netlist -model slow
read_sdc
update_timing_netlist
file mkdir docs/evidence
report_clocks -file docs/evidence/clocks.rpt
report_clock_fmax_summary -file docs/evidence/fmax.rpt
report_timing -setup -npaths 5 -detail full_path -file docs/evidence/setup_paths.rpt
report_timing -hold -npaths 5 -detail full_path -file docs/evidence/hold_paths.rpt
delete_timing_netlist
project_close
