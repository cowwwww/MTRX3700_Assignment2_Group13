"""One-time local provenance capture. Never edits the user's source directories.
The handoff archive contains the captured files; recipients need not run this.
"""
from pathlib import Path
import shutil, hashlib, json
ROOT=Path(__file__).resolve().parents[1]
course=ROOT.parents[1]
dest=ROOT/'reference_materials';dest.mkdir(exist_ok=True)
mapping={
 course/'ED'/'MTRX3700_Ed_Archive_Compat.zip':dest/'Ed_snapshot_2026-10-05.zip',
 course/'ED'/'MTRX3700_Sourcebook.md':dest/'MTRX3700_Sourcebook.md',
 course/'ASSIGNMENT1'/'ASSIGNMENT1.zip':dest/'Assignment1_original.zip',
 course/'ASSIGNMENT1'/'MTRX3700_Assignment_1_Piano_Tiles_release.pdf':dest/'Assignment1_specification.pdf',
 course/'ASSIGNMENT1'/'report'/'MTRX3700_Assignment_1 (1).pdf':dest/'Assignment1_report.pdf',
 ROOT.parent/'Assignment_2_Shine_and_Sing_final.docx.pdf':dest/'Assignment2_specification.pdf',
}
for name in ['ParallelPiano.png','ParallelPiano2.png']:
 mapping[ROOT.parent/'example'/name]=dest/'piano_examples'/name
for src,dst in mapping.items():
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
manifest=[]
for src,dst in mapping.items():
 manifest.append({'file':dst.relative_to(ROOT).as_posix(),'original_path':str(src),'bytes':dst.stat().st_size,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()})
(dest/'MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Pin list becomes a portable, independently retained build input.
qsf=(ROOT/'shine_sing.qsf').read_text()
(ROOT/'quartus'/'de1_soc_pins.qsf').write_text('\n'.join(s for s in qsf.splitlines() if s.startswith(('set_location_assignment','set_instance_assignment')))+'\n')
print(f'Frozen {len(manifest)} original materials with SHA-256 hashes.')
