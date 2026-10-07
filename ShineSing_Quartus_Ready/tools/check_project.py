"""Check build inputs; --require-trained also checks recorded HD template metadata."""
import argparse
import hashlib
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--require-trained',action='store_true')
a=p.parse_args()
missing=[]
for kind,name in re.findall(r'-name (\w+_FILE) ([^\r\n]+)',(ROOT/'shine_sing.qsf').read_text()):
    if not (ROOT/name.strip('"')).is_file(): missing.append(name)
for source in (ROOT/'rtl').rglob('*'):
    if source.suffix not in ('.sv','.v','.svh'): continue
    for name in re.findall(r'(?:`include\s+|\$readmemh\(\s*)"([^"]+)"',source.read_text()):
        if not (ROOT/name).is_file(): missing.append(name)
manifest=json.loads((ROOT/'course_sources/manifest.json').read_text())
for entry in manifest['files']:
    f=ROOT/entry['path']
    if not f.is_file() or hashlib.sha256(f.read_bytes()).hexdigest()!=entry['sha256']:
        missing.append('course source changed: '+entry['path'])
if missing: raise SystemExit('Missing or changed inputs:\n'+'\n'.join(missing))
print('PASS: project inputs and original course file hashes')
ready=bool(re.search(r'TEMPLATES_READY\s*=\s*1\s*;', (ROOT/'rtl/templates.svh').read_text()))
if a.require_trained:
    if not ready:
        raise SystemExit('Recorded HD vowel templates are missing. Run tools/train_saved_templates.py ee.csv ah.csv oo.csv aw.csv before a demo build.')
    report=json.loads((ROOT/'rtl/templates_training.json').read_text())
    if report['dimensions']!=24 or report['labels']!=['ee','ah','oo','aw']:
        raise SystemExit('Wrong template dimensions or vowel order.')
    expected_hash=report.get('template_sha256')
    if expected_hash and hashlib.sha256((ROOT/'rtl/templates.svh').read_bytes()).hexdigest()!=expected_hash:
        raise SystemExit('Template header does not match the training report. Regenerate templates.')
    for name,expected in report.get('feature_source_hashes',{}).items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=expected:
            raise SystemExit('Audio feature pipeline changed; rebuild the H95 templates: '+name)
    print('PASS: saved HD template metadata (live accuracy still needs board testing)')
elif not ready:
    print('NOT DEMO READY: recorded HD vowel templates are not supplied; classifier stays disabled.')
