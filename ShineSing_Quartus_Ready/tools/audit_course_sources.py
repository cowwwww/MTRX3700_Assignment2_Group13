"""Record which build files come from the uploaded course ZIPs."""
from pathlib import Path
import difflib
import hashlib
import json
ROOT=Path(__file__).resolve().parents[1]
pairs={
 'rtl/reuse/low_pass_conv.sv':('fir/low_pass_conv.sv','Added reset, busy guard and scaling/saturation; kept supplied taps and serial multiply pipeline.'),
 'rtl/reuse/conv3x3.sv':('video/rtl/conv3x3.sv','Completed the three exercise TODOs: window shift, signed multiply-sum, valid/coordinates.'),
 'rtl/reuse/sobel.sv':('video/rtl/sobel.sv','Direct reuse.'),
 'rtl/reuse/video_pll.sv':('video/rtl/video_pll.sv','Course PLL wrapper.'),
 'rtl/reuse/hex_seg.sv':('video/rtl/hex_seg.sv','Course display driver.'),
 'rtl/reuse/mic_load.sv':('audio/mic/mic_load.sv','Completed the supplied receiver stub using the left-justified codec interface.'),
 'rtl/reuse/fft_mag_sq.sv':('audio/fft_mag_sq.sv','Completed the supplied stub with two signed squares, their sum, and a two-cycle valid delay.'),
 'rtl/reuse/adc_pll.v':('audio/mic/adc_pll.v','Course generated audio PLL.'),
 'rtl/classifier.sv':('classifier/classifier.sv','Kept nearest-template distance and vote logic; added saved-template parameters, test/capture enrolment, immediate gate clear, zero-distance rejection, and a sequential confidence divider.'),
 'tools/provided_train_templates.py':('classifier/train_templates.py','Direct reuse; HD wrapper validates four classes and 24 dimensions.'),
 'assets/test_waveform.hex':('audio/test_waveform.hex','Supplied tone fixture, not recorded speech.'),
 'tools/image_to_mif.py':('video/tools/image_to_mif.py','Course image converter.'),
}
for f in (ROOT/'rtl/fft').glob('*.v'):
 pairs[str(f.relative_to(ROOT))]=('audio/fft_ip_r22sdf/'+f.name,'Direct reuse except DelayBuffer, which uses circular RAM to reduce registers.')
records=[]
for current,(original,reason) in pairs.items():
 source=ROOT/'course_sources'/original;target=ROOT/current
 old=source.read_text();new=target.read_text()
 records.append({'build_file':current,'course_source':'course_sources/'+original,
  'identical_text':old==new,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
  'build_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'changes':reason})
patch=''.join(''.join(difflib.unified_diff((ROOT/r['course_source']).read_text().splitlines(True),
 (ROOT/r['build_file']).read_text().splitlines(True),fromfile=r['course_source'],tofile=r['build_file'])) for r in records)
(ROOT/'course_sources/reuse.patch').write_text(patch)
(ROOT/'course_sources/reuse.json').write_text(json.dumps({'reused':records,'assignment_extensions':{
 'rtl/audio_frontend.sv':'Wraps the supplied FIR with resettable /4 decimation, Hamming window and ping-pong frame RAM.',
 'rtl/audio_features.sv':'Assignment feature ladder including 24 log-Mel bands; not supplied by these ZIPs.',
 'rtl/piano_detector.sv':'Assignment scan/profile/peak logic extends course concepts with normalization, hysteresis, smoothing and adaptive thresholds.',
 'rtl/video_source.sv':'Assignment VGA views, score and game masks built around the course Avalon-ST interface.',
 'rtl/cdc_mailbox.sv':'Held-data request/acknowledge transfer for independent clock domains.',
 'rtl/game.sv':'Assignment 1 game integration with classifier decisions.',
 'rtl/templates.svh':'Saved 24-feature templates trained from user-supplied H95 recorded vowels; see rtl/templates_training.json. The earlier course classifier ZIP contains only synthetic 8-feature test templates.'
}},indent=2)+'\n')
print('Audited',len(records),'course-derived files; originals retained unchanged.')
