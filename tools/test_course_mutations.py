"""Check that tests detect broken logic, keeping the real source files unchanged."""
from pathlib import Path
import os
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
verilator=shutil.which('verilator')
if not verilator: raise SystemExit('Verilator is not on PATH.')
out=ROOT/'build/mutations';out.mkdir(parents=True,exist_ok=True)
cases=[
 ('gate_stuck','rtl/audio_level.sv','else if(mean_level < noise+MARGIN) voice<=0;','else if(mean_level < noise+MARGIN) voice<=1;','tb_audio_level','gate never clears'),
 ('no_spacing','rtl/piano_detector.sv','best_position-last_position<MIN_GAP','best_position-last_position<0','tb_piano_thresholds','threshold count'),
 ('lost_smoothing','rtl/piano_detector.sv','smooth<=use_smoothing && use_sobel;','smooth<=0;','tb_piano_detector_hd','R-V4'),
 ('lost_saved_classes','rtl/classifier.sv',"trained <= PRETRAINED ? SAVED_CLASSES : '0;","trained <= '0;",'tb_classifier_saved','saved classes not ready'),
]
sources=[str(p) for d in ['rtl','rtl/reuse','rtl/fft'] for p in sorted(Path(d).glob('*')) if p.suffix in ['.sv','.v']]
for name,source,old,new,bench,reason in cases:
    text=(ROOT/source).read_text()
    if old not in text: raise SystemExit('Missing mutation target: '+source)
    changed=out/(name+'.sv');changed.write_text(text.replace(old,new))
    directory=out/name
    command=[verilator,'--binary','--timing','--assert','-Wno-fatal','--top-module',bench,'--Mdir',str(directory)]
    command += [str(changed) if p==source else p for p in sources]+['tb/'+bench+'.sv']
    result=subprocess.run(command,capture_output=True,text=True)
    (out/(name+'_compile.log')).write_text(result.stdout+result.stderr)
    if result.returncode: raise SystemExit('Mutation failed to compile: '+name)
    result=subprocess.run([str(directory/('V'+bench))],capture_output=True,text=True)
    log=result.stdout+result.stderr;(out/(name+'.log')).write_text(log)
    if result.returncode==0 or reason not in log or 'ALL TESTS PASSED' in log:
        raise SystemExit('Mutation was not caught for the expected reason: '+name+'\n'+log)
    print('MUTATION CAUGHT:',name,flush=True)
