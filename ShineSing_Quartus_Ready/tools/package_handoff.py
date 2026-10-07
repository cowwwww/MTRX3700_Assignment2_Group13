"""Create a self-contained V9 Ed/Quartus ZIP, excluding compiler caches and H95 raw data."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
folders = ['rtl','tb','tools','assets','quartus','course_sources','data/recordings','docs']
rootfiles = ['README.md','RUN_INSTRUCTIONS.txt','requirements.txt','run_ed.sh','build_quartus.sh',
             'shine_sing.qpf','shine_sing.qsf','shine_sing.sdc','verification.json']
files = [ROOT/name for name in rootfiles]
for folder in folders:
    files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts
                 and p.suffix not in ('.pyc','.bak'))
sof = ROOT/'output_files/shine_sing.sof'
inputs = [p for p in files if p.relative_to(ROOT).parts[0] in ('rtl','assets','quartus')
          or p.suffix in ('.qsf','.sdc')]
sof_current = sof.exists() and sof.stat().st_mtime >= max(p.stat().st_mtime for p in inputs)
if sof_current:
    files.append(sof)
files = sorted(set(files))
manifest = [dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size,
                 sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files]
dest = ROOT/'deliverables'
dest.mkdir(exist_ok=True)
path = dest/'ShineSing_V9_Group_Recordings.zip'
with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for p in files:
        archive.write(p, p.relative_to(ROOT).as_posix())
    archive.writestr('BUNDLE_MANIFEST.json', json.dumps(manifest, indent=2))
with zipfile.ZipFile(path) as archive:
    if archive.testzip():
        raise RuntimeError('ZIP CRC verification failed')
    for entry in manifest:
        if hashlib.sha256(archive.read(entry['path'])).hexdigest() != entry['sha256']:
            raise RuntimeError(entry['path'])
result = dict(file=path.name, bytes=path.stat().st_size, files=len(files), sof_included=sof_current,
              sha256=hashlib.sha256(path.read_bytes()).hexdigest())
(dest/'SHA256.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
