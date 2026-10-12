"""Check the board RAM model using Intel's simulation library."""
from pathlib import Path
import subprocess,os,shutil
ROOT=Path(__file__).resolve().parents[1];os.chdir(ROOT)
found=shutil.which('vsim') or shutil.which('vsim.exe')
base=Path(os.environ.get('MODELSIM_BIN',str(Path(found).parent) if found else ''))
if not (base/'vsim.exe').exists(): raise SystemExit('Set MODELSIM_BIN or put vsim.exe on PATH.')
lib=ROOT/'build'/'ram_primitive'
def run(cmd):
 r=subprocess.run(cmd,capture_output=True,text=True,errors='replace')
 if r.returncode: raise SystemExit(r.stdout+r.stderr)
 return r.stdout+r.stderr
if not lib.exists(): run([str(base/'vlib.exe'),str(lib)])
run([str(base/'vlog.exe'),'-sv','+define+SYNTHESIS','-work',str(lib),'rtl/sync_ram.sv','tb/tb_sync_ram.sv'])
text=run([str(base/'vsim.exe'),'-c','-onfinish','stop','-lib',str(lib),'-L',str(base.parent/'altera/verilog/altera_mf'),'-L',str(base.parent/'altera/verilog/cyclonev'),'tb_sync_ram','-do','run -all; quit -code 0'])
(ROOT/'build'/'ram_primitive.log').write_text(text)
if 'ALL TESTS PASSED: tb_sync_ram' not in text: raise SystemExit(text)
print('PASS Intel altsyncram: latency and same-address OLD_DATA verified.')
