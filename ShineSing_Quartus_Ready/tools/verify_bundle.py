from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
manifest=root/'BUNDLE_MANIFEST.json'
if not manifest.exists(): raise SystemExit('Run on an extracted handoff bundle containing BUNDLE_MANIFEST.json.')
bad=[]
for entry in json.loads(manifest.read_text(encoding='utf-8')):
 p=root/entry['path']
 if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=entry['sha256']: bad.append(entry['path'])
if bad: print('\n'.join(bad));sys.exit(1)
print('PASS: every bundled file matches its SHA-256 manifest.')
