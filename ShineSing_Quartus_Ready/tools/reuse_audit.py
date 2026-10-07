"""Extract precise reused originals from frozen snapshots and create reviewable diffs."""
from pathlib import Path
import zipfile,hashlib,difflib
ROOT=Path(__file__).resolve().parents[1]
refs=ROOT/'reference_materials'
source_root=refs/'reuse_sources';source_root.mkdir(exist_ok=True)
ed=zipfile.ZipFile(refs/'Ed_snapshot_2026-10-05.zip')
a1=zipfile.ZipFile(refs/'Assignment1_original.zip')
mapping={
 'tools/image_to_mif.py':('ed','BarcodeReader/07_820062/Original/tools/image_to_mif.py'),
 'tools/make_barcode.py':('ed','BarcodeReader/07_820062/Original/tools/make_barcode.py'),
 'rtl/reuse/mic_load.sv':('ed','PitchDetection/02_771076/Completed/mic/mic_load.sv'),
 'rtl/reuse/adc_pll.v':('ed','PitchDetection/02_771076/Completed/mic/adc_pll.v'),
 'rtl/reuse/fft_mag_sq.sv':('ed','PitchDetection/02_771076/Completed/fft_mag_sq.sv'),
 'rtl/reuse/conv3x3.sv':('ed','BarcodeReader/07_820062/Completed/rtl/conv3x3.sv'),
 'rtl/reuse/sobel.sv':('ed','BarcodeReader/07_820062/Completed/rtl/sobel.sv'),
 'rtl/reuse/video_pll.sv':('ed','BarcodeReader/07_820062/Completed/rtl/video_pll.sv'),
 'rtl/reuse/hex_seg.sv':('ed','BarcodeReader/07_820062/Completed/rtl/hex_seg.sv'),
 'rtl/classifier.sv':('ed','PitchDetection/12_831269/Original/classifier.sv'),
 'rtl/game_controller.sv':('a1','rtl/game_controller.sv'),
 'rtl/reaction_time_fsm.sv':('a1','rtl/reaction_time_fsm.sv'),
}
for f in (ROOT/'rtl/fft').glob('*.v'):
 mapping[f.relative_to(ROOT).as_posix()]=('ed','PitchDetection/02_771076/Completed/fft_ip_r22sdf/'+f.name)
lines=['# Direct reuse audit','','Hashes compare the captured source bytes with the current file. Diffs ignore line-ending changes only.','']
for current,(archive,path) in mapping.items():
 z=ed if archive=='ed' else a1
 matches=[n for n in z.namelist() if n.endswith('/'+path) or n==path]
 if len(matches)!=1: raise RuntimeError((path,matches))
 old=z.read(matches[0]);new=(ROOT/current).read_bytes()
 target=source_root/archive/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(old)
 old_text=old.decode('utf-8-sig').splitlines(keepends=True)
 new_text=new.decode('utf-8-sig').splitlines(keepends=True)
 delta=''.join(difflib.unified_diff([s.rstrip('\r\n')+'\n' for s in old_text],[s.rstrip('\r\n')+'\n' for s in new_text],fromfile=path,tofile=current))
 lines.extend([f'## {current}',f'- Source: `{archive}/{path}`',f'- Source SHA-256: `{hashlib.sha256(old).hexdigest()}`',f'- Current SHA-256: `{hashlib.sha256(new).hexdigest()}`',f'- Status: {"modified" if delta else "identical apart from possible line endings"}',''])
 if delta: lines.extend(['```diff',delta.rstrip(),'```',''])
# Rewritten adapters retain their input source alongside the exact direct copies.
for path in ['PitchDetection/02_771076/Completed/low_pass_conv.sv','PitchDetection/02_771076/Completed/decimate.sv','PitchDetection/02_771076/Completed/fft_input_buffer.sv','PitchDetection/02_771076/Completed/window_function.sv','PitchDetection/02_771076/Completed/fft_find_peak.sv','PitchDetection/02_771076/Completed/mic/set_audio_encoder.sv','BarcodeReader/07_820062/Completed/rtl/col_profile.sv','BarcodeReader/07_820062/Completed/rtl/peak_pick.sv','BarcodeReader/07_820062/Completed/rtl/cdc_latch.sv','BarcodeReader/07_820062/Completed/rtl/display.sv','BarcodeReader/07_820062/Completed/rtl/image_rom.sv']:
 match=[n for n in ed.namelist() if n.endswith('/'+path)]
 if len(match)!=1: raise RuntimeError(path)
 target=source_root/'ed'/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(ed.read(match[0]))
(ROOT/'docs/REUSE_DIFFS.md').write_text('\n'.join(lines),encoding='utf-8')
print(f'Audited {len(mapping)} direct reuse files; retained rewritten-adapter inputs.')
