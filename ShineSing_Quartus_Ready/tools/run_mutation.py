"""Prove the gate unit test kills a never-closing gate; original RTL is untouched."""
from pathlib import Path
import subprocess,sys,os,shutil
ROOT=Path(__file__).resolve().parents[1];os.chdir(ROOT)
out=ROOT/'build'/'mutation';out.mkdir(exist_ok=True)
source=(ROOT/'rtl'/'audio_level.sv').read_text()
old='else if(mean_level < noise+MARGIN) voice<=0;'
assert old in source
(out/'audio_level.sv').write_text(source.replace(old,'else if(mean_level < noise+MARGIN) voice<=1;'))
found=shutil.which('vsim') or shutil.which('vsim.exe')
base=Path(os.environ.get('MODELSIM_BIN',str(Path(found).parent) if found else ''))
if not (base/'vsim.exe').exists(): raise SystemExit('Set MODELSIM_BIN or put vsim.exe on PATH.')
lib=out/'work'
def run(cmd):
 r=subprocess.run(cmd,capture_output=True,text=True,errors='replace')
 return r.returncode,r.stdout+r.stderr
if not lib.exists():
 code,text=run([str(base/'vlib.exe'),str(lib)])
 if code: raise SystemExit(text)
code,text=run([str(base/'vlog.exe'),'-sv','-work',str(lib),str(out/'audio_level.sv'),'tb/tb_audio_level.sv'])
if code: raise SystemExit(text)
code,text=run([str(base/'vsim.exe'),'-c','-onfinish','stop','-lib',str(lib),'tb_audio_level','-do','run -all; quit -code 0'])
(out/'result.log').write_text(text)
if 'gate never clears' not in text or 'ALL TESTS PASSED' in text: raise SystemExit('Mutation was not killed for the intended reason.\n'+text)
print('MUTATION KILLED: gate never clears (original RTL was not modified)')
