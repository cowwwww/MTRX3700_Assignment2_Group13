"""Run RTL tests: python tools/run_tests.py --sim modelsim|verilator.
Each test has a timeout; no board connection is needed."""
import argparse, pathlib, shutil, subprocess, os, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
p=argparse.ArgumentParser();p.add_argument('--sim',choices=['modelsim','verilator'],default='verilator');p.add_argument('tests',nargs='*');a=p.parse_args()
tests=a.tests or [x.stem for x in sorted((ROOT/'tb').glob('tb_*.sv'))]
sources=[str(x.relative_to(ROOT)).replace('\\','/') for d in ['rtl','rtl/reuse','rtl/fft'] for x in sorted((ROOT/d).glob('*')) if x.suffix in ('.sv','.v')]
build=ROOT/'build';build.mkdir(exist_ok=True)
def run(cmd,log):
 r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace')
 log.write_text(r.stdout,encoding='utf-8')
 if r.returncode: print(r.stdout[-12000:]);raise SystemExit(r.returncode)
 return r.stdout
if a.sim=='modelsim':
 found=shutil.which('vsim') or shutil.which('vsim.exe')
 base=pathlib.Path(os.environ.get('MODELSIM_BIN',str(pathlib.Path(found).parent) if found else r'E:\intelFPGA_lite\18.1\modelsim_ase\win32aloem'))
 lib=build/'msim'
 if not lib.exists(): run([str(base/'vlib.exe'),str(lib)],build/'vlib.log')
 run([str(base/'vlog.exe'),'-sv','-work',str(lib),*sources,*[f'tb/{t}.sv' for t in tests]],build/'compile.log')
 for t in tests:
  out=run([str(base/'vsim.exe'),'-c','-onfinish','stop','-lib',str(lib),t,'-do','onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'],build/f'{t}.log')
  if f'ALL TESTS PASSED: {t}' not in out: print(out);raise SystemExit(f'{t}: no success marker')
  print(f'PASS {t}')
else:
 if not shutil.which('verilator'): raise SystemExit('Verilator is not on PATH. Use --sim modelsim locally; use Verilator 5.050 on Ed.')
 for t in tests:
  directory=build/t
  run(['verilator','--binary','--timing','--assert','-Wno-fatal','--top-module',t,'--Mdir',str(directory),*sources,f'tb/{t}.sv'],build/f'{t}_compile.log')
  out=run([str(directory/f'V{t}')],build/f'{t}.log')
  if f'ALL TESTS PASSED: {t}' not in out: raise SystemExit(f'{t}: no success marker')
  print(f'PASS {t}')
print(f'ALL {len(tests)} RTL TESTS PASSED ({a.sim})')
