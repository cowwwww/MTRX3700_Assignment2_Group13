"""Extract the full bundle to a fresh directory and test without original paths."""
from pathlib import Path
import zipfile, tempfile, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
destination = Path(tempfile.mkdtemp(prefix='transfer_', dir=ROOT/'build'))
with zipfile.ZipFile(ROOT/'deliverables/ShineSing_full_handoff.zip') as archive:
    for name in archive.namelist():
        target = (destination/name).resolve()
        if not target.is_relative_to(destination.resolve()):
            raise SystemExit(f'Unsafe archive member: {name}')
    archive.extractall(destination)
records = [f'Fresh extraction: {destination.name}\n']
for arguments in [
    ['tools/verify_bundle.py'],
    ['tools/test_image_assets.py'],
    ['tools/run_tests.py', '--sim', 'modelsim', 'tb_system', 'tb_sync_ram', 'tb_video_source',
     'tb_image_store', 'tb_piano_detector', 'tb_piano_thresholds'],
]:
    result = subprocess.run([sys.executable, *arguments], cwd=destination,
                            capture_output=True, text=True, errors='replace')
    records.append(result.stdout + result.stderr)
    if result.returncode:
        print(''.join(records))
        raise SystemExit(result.returncode)
records.append('TRANSFER CHECK PASSED: independent extraction, hashes, image assets and six RTL tests.\n')
text = ''.join(records)
(ROOT/'docs/evidence/transfer_check.log').write_text(text, encoding='utf-8')
print(text)
