"""Create code and full-project ZIPs with a hash for each file."""
from pathlib import Path
import zipfile,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
dest=ROOT/'deliverables';dest.mkdir(exist_ok=True)
folders=['rtl','tb','tools','assets','quartus','docs']
rootfiles=['README.md','HANDOFF.md','requirements.txt','simulate.sh','shine_sing.qpf','shine_sing.qsf','shine_sing.sdc','.gitignore']
def build(name,full):
 files=[ROOT/n for n in rootfiles]
 for folder in folders+(['reference_materials'] if full else []):
  files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.pyc','.bak','.log'])
 # Keep test logs; leave out build caches.
 files.extend(p for p in (ROOT/'docs/evidence').glob('*.log') if p not in files)
 sof=ROOT/'output_files/shine_sing.sof'
 inputs=[p for folder in ['rtl','assets','quartus'] for p in (ROOT/folder).rglob('*') if p.is_file()]
 inputs.extend(ROOT/name for name in ['shine_sing.qsf','shine_sing.sdc'])
 sof_current=sof.exists() and sof.stat().st_mtime >= max(p.stat().st_mtime for p in inputs)
 if sof_current: files.append(sof)
 files=sorted(set(files))
 manifest=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
 path=dest/name
 with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in files: z.write(p,p.relative_to(ROOT).as_posix())
  z.writestr('BUNDLE_MANIFEST.json',json.dumps(manifest,indent=2))
 with zipfile.ZipFile(path) as z:
  if z.testzip(): raise RuntimeError('ZIP CRC error')
  for e in manifest:
   if hashlib.sha256(z.read(e['path'])).hexdigest()!=e['sha256']: raise RuntimeError(e['path'])
 return {'file':name,'bytes':path.stat().st_size,'files':len(manifest),'sof_included':sof_current,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
result=[build('ShineSing_code.zip',False),build('ShineSing_full_handoff.zip',True)]
(dest/'SHA256.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
