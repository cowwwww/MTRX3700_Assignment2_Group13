"""Generate a clean Quartus 18.1 project using only ports present on the A2 top."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
pins=(ROOT/'quartus'/'de1_soc_pins.qsf').read_text()
ports={'CLOCK_50','SW','KEY','AUD_ADCDAT','AUD_ADCLRCK','AUD_BCLK','AUD_XCK','AUD_DACDAT','FPGA_I2C_SCLK','FPGA_I2C_SDAT','LEDR',*[f'HEX{i}' for i in range(6)],'VGA_CLK','VGA_HS','VGA_VS','VGA_BLANK_N','VGA_SYNC_N','VGA_R','VGA_G','VGA_B'}
lines=['set_global_assignment -name FAMILY "Cyclone V"','set_global_assignment -name DEVICE 5CSEMA5F31C6','set_global_assignment -name TOP_LEVEL_ENTITY shine_sing_top','set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files','set_global_assignment -name SDC_FILE shine_sing.sdc','set_global_assignment -name QIP_FILE quartus/vga_sink/synthesis/vga_sink.qip','set_global_assignment -name NUM_PARALLEL_PROCESSORS 4','set_global_assignment -name VERILOG_MACRO "SYNTHESIS=1"']
for slot in range(3):
 lines.append(f'set_global_assignment -name MIF_FILE assets/piano{slot}.mif')
for folder in ['rtl','rtl/reuse','rtl/fft']:
 for f in sorted((ROOT/folder).glob('*')):
  if f.suffix in ('.v','.sv'):
   lines.append(f'set_global_assignment -name {"SYSTEMVERILOG_FILE" if f.suffix==".sv" else "VERILOG_FILE"} {f.relative_to(ROOT).as_posix()}')
for line in pins.splitlines():
 if line.startswith(('set_location_assignment','set_instance_assignment')) and ' -to ' in line:
  name=line.split(' -to ')[1].strip('"').split('[')[0]
  if name in ports: lines.append(line)
(ROOT/'shine_sing.qsf').write_text('\n'.join(lines)+'\n')
(ROOT/'shine_sing.qpf').write_text('QUARTUS_VERSION = "18.1"\nPROJECT_REVISION = "shine_sing"\n')
print('Generated shine_sing.qpf/qsf')
