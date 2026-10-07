"""Verify image benches reject missing pixels, disabled spacing and swapped ROMs."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
found = shutil.which('vsim') or shutil.which('vsim.exe')
base = Path(os.environ.get('MODELSIM_BIN', str(Path(found).parent) if found else ''))
if not (base/'vsim.exe').exists():
    raise SystemExit('Set MODELSIM_BIN or put vsim.exe on PATH.')
out = ROOT/'build/image_mutations'
out.mkdir(parents=True, exist_ok=True)
cases = [
    ('no_spacing', 'rtl/piano_detector.sv', 'best_position-last_position<MIN_GAP',
     'best_position-last_position<0', 'tb_piano_thresholds', 'threshold count'),
    ('missing_pixels', 'rtl/piano_detector.sv', 'edge_write<=1;',
     'edge_write<=0;', 'tb_piano_detector', 'incomplete edge map'),
    ('swapped_rom', 'rtl/image_store.sv', 'a1<=image1[analysis_address]',
     'a1<=image0[analysis_address]', 'tb_image_store', 'analysis ROM slot=1'),
]
records = []
for name, source, old, new, bench, reason in cases:
    text = (ROOT/source).read_text()
    assert old in text, (name, 'mutation target missing')
    mutated = out/f'{name}.sv'
    mutated.write_text(text.replace(old, new))
    lib = out/name
    commands = [] if lib.exists() else [[str(base/'vlib.exe'), str(lib)]]
    sources = [str(mutated) if p == source else p for p in
               ['rtl/piano_detector.sv', 'rtl/image_store.sv', 'rtl/reuse/sobel.sv', 'rtl/reuse/conv3x3.sv']]
    commands.append([str(base/'vlog.exe'), '-sv', '-work', str(lib), *sources, f'tb/{bench}.sv'])
    for command in commands:
        run = subprocess.run(command, capture_output=True, text=True, errors='replace')
        if run.returncode:
            raise SystemExit(run.stdout + run.stderr)
    run = subprocess.run([str(base/'vsim.exe'), '-c', '-onfinish', 'stop', '-lib', str(lib), bench,
                          '-do', 'run -all; quit -code 0'], capture_output=True, text=True, errors='replace')
    log = run.stdout + run.stderr
    (out/f'{name}.log').write_text(log, encoding='utf-8')
    if reason not in log or 'ALL TESTS PASSED' in log:
        raise SystemExit(f'{name} was not killed for the intended reason:\n{log}')
    records.append(f'MUTATION KILLED: {name} ({reason})')
summary = '\n'.join(records) + '\n'
(ROOT/'docs/evidence/image_mutations.log').write_text(summary, encoding='utf-8')
print(summary, end='')
