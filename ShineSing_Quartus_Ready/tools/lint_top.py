"""Check board wiring with the supplied PLL black box; this is not a timing fit."""
import os
from pathlib import Path
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
verilator=shutil.which('verilator')
if not verilator: raise SystemExit('Verilator is not on PATH.')
sources=[str(p) for d in ['rtl','rtl/reuse','rtl/fft'] for p in sorted(Path(d).glob('*'))
         if p.suffix in ['.sv','.v'] and p.name!='adc_pll.v']
sources+=['course_sources/audio/mic/adc_pll_bb.v']
sources += [str(p) for p in sorted(Path('quartus/vga_sink/synthesis').rglob('*.v'))]
(ROOT/'build').mkdir(exist_ok=True)
result=subprocess.run([verilator,'--lint-only','--timing','-Wno-fatal','--top-module','shine_sing_top',*sources],capture_output=True,text=True)
(ROOT/'build/top_lint.log').write_text(result.stdout+result.stderr)
if result.returncode: raise SystemExit(result.stdout+result.stderr)
print('PASS: top-level wiring lint (PLL black box; no Quartus fit or timing claim)')
