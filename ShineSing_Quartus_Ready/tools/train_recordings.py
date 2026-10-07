"""WAV -> actual board RTL features -> saved four-vowel templates.

python tools/train_recordings.py --samples data/recordings --sim verilator
The two-fold score holds out whole files. The final ROM uses all recordings.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import resample_poly
from provided_train_templates import kmeans_sad, write_svh
from template_common import decision

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/recordings'
LABELS = ['ee', 'ah', 'oo', 'aw']
FRAME = 4096  # 48 kHz / 4 -> 1024 samples at the FFT input


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def feature_hashes():
    paths = [ROOT/'rtl/audio_frontend.sv', ROOT/'rtl/sync_ram.sv', ROOT/'rtl/reuse/low_pass_conv.sv',
             ROOT/'rtl/reuse/fft_mag_sq.sv', ROOT/'rtl/audio_features.sv', ROOT/'rtl/mel_weights.svh',
             ROOT/'assets/hamming.hex', *sorted((ROOT/'rtl/fft').glob('*.v'))]
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in paths}


def decode_pcm(raw, width, channels):
    """PCM WAV is unsigned at 8 bits and signed little-endian otherwise."""
    if width == 1:
        values = (np.frombuffer(raw, np.uint8).astype(np.int32) - 128) / 128.0
    elif width == 2:
        values = np.frombuffer(raw, '<i2').astype(np.float64) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        values = ((v ^ 8388608) - 8388608) / 8388608.0
    elif width == 4:
        values = np.frombuffer(raw, '<i4').astype(np.float64) / 2147483648.0
    else:
        raise ValueError('Only 8/16/24/32-bit integer PCM WAV is supported')
    return values.reshape(-1, channels)


def prepare(samples):
    paths = sorted(samples.rglob('*.wav'))
    if not paths:
        raise ValueError(f'No .wav files in {samples}')
    WORK.mkdir(parents=True, exist_ok=True)
    records, pcm = [], []
    for path in paths:
        # Accept ee.wav, ee1.wav, ah-001.wav, or ee/speaker_take.wav.
        match = re.match(r'^(ee|ah|oo|aw)(?=$|[\d_ -])', path.stem.lower())
        label = match[1] if match else path.parent.name.lower()
        if label not in LABELS:
            raise ValueError(f'Cannot label {path.name}; use ee/ah/oo/aw filename prefixes or folders')
        with wave.open(str(path)) as stream:
            if stream.getcomptype() != 'NONE':
                raise ValueError(f'{path}: compressed WAV unsupported')
            rate, width, channels = stream.getframerate(), stream.getsampwidth(), stream.getnchannels()
            data = decode_pcm(stream.readframes(stream.getnframes()), width, channels)
        if not len(data):
            raise ValueError(f'{path}: empty recording')
        # Choose the strongest channel; never average anti-phase stereo to silence.
        channel = int(np.argmax(np.mean(data * data, axis=0)))
        mono = data[:, channel]
        divisor = math.gcd(rate, 48000)
        converted = resample_poly(mono, 48000 // divisor, rate // divisor)
        pcm16 = np.clip(np.rint(converted * 32768), -32768, 32767).astype(np.int16)
        count = len(pcm16) // FRAME
        if count < 2:
            raise ValueError(f'{path}: need at least two complete 85.33 ms frames')
        blocks = pcm16[:count * FRAME].reshape(count, FRAME)
        rms = np.sqrt(np.mean(blocks.astype(float) ** 2, axis=1))
        # A fixed, label-independent energy rule excludes silence and vowel tails.
        # Preserve every earlier sample in RTL so the FIR state is not reset per frame.
        threshold = max(128.0, 0.40 * float(rms.max()))
        keep = np.flatnonzero(rms >= threshold).tolist()
        if len(keep) < 2:
            raise ValueError(f'{path}: fewer than two voiced frames; record a longer sustained vowel')
        records.append(dict(file=path.relative_to(samples).as_posix(), sha256=sha(path),
                            label=label, class_index=LABELS.index(label), sample_rate=rate,
                            bits=8*width, channels=channels, selected_channel=channel,
                            duration_seconds=len(data)/rate, peak=float(np.abs(mono).max()),
                            clipped_input_samples=int(np.count_nonzero(np.abs(mono) >= 0.9999)),
                            frames=count, kept_frames=keep, rms_pcm16=rms.tolist(),
                            rms_threshold=threshold, discarded_tail_samples=len(pcm16)-count*FRAME))
        pcm.extend(blocks.reshape(-1).tolist())
    for label in LABELS:
        if sum(r['label'] == label for r in records) < 2:
            raise ValueError(f'{label}: need at least two separate WAV recordings for file-level validation')
    manifest = dict(labels=LABELS, records=records, pcm_rate=48000, frame_samples=FRAME,
                    feature_source_hashes=feature_hashes(),
                    preprocessing='Strongest channel; polyphase resampling; fixed PCM16 scaling, no per-file normalisation',
                    selection='Whole-frame RMS >= max(128, 0.40 * highest whole-frame RMS in that recording)')
    (WORK/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    (WORK/'pcm.hex').write_text(''.join(f'{int(x)&65535:04x}\n' for x in pcm))
    (WORK/'counts.hex').write_text(''.join(f'{r["frames"]:08x}\n' for r in records))
    (WORK/'dimensions.svh').write_text(f'localparam int TOKENS={len(records)}, SAMPLES={len(pcm)};\n')
    # A fresh prepare invalidates any feature capture from a previous input set.
    (WORK/'features.csv').unlink(missing_ok=True)
    (ROOT/'build/extract_recording_features.log').unlink(missing_ok=True)
    print(f'Prepared {len(records)} recordings, {sum(r["frames"] for r in records)} frames; '
          f'{sum(len(r["kept_frames"]) for r in records)} voiced frames', flush=True)


def centres(values, count=4):
    """Reuse the Ed-provided L1/median trainer, with deterministic training-only seed selection."""
    candidates = [np.rint(kmeans_sad(values.astype(float), count, seed=s, iters=40)).astype(np.int64)
                  for s in range(12)]
    best = min(candidates, key=lambda t: np.abs(values[:, None, :] - t).sum(axis=2).min(axis=1).sum())
    # Short recordings may have <4 frames. Repeat existing centres, never invent extra observations.
    return np.concatenate([best, np.repeat(best[-1:], max(0, count-len(best)), axis=0)])


def fit(rows):
    result = []
    for label in range(4):
        tokens = sorted(set(t for c,t,_ in rows if c == label))
        if len(tokens) <= 4:
            # Reserve slots per recording: two takes from two people receive two each.
            # A longer take cannot displace the other person's templates.
            groups = []
            for i, token in enumerate(tokens):
                count = 4//len(tokens) + int(i < 4%len(tokens))
                groups.append(centres(np.array([f for c,t,f in rows if c == label and t == token]), count))
            result.append(np.concatenate(groups))
        else:
            # For larger datasets, give every recording equal weight before clustering.
            groups = [np.array([f for c,t,f in rows if c == label and t == token]) for token in tokens]
            size = max(map(len,groups))
            balanced = np.concatenate([g[np.arange(size)*len(g)//size] for g in groups])
            result.append(centres(balanced))
    return np.array(result)


def matrix_score(rows, templates):
    matrix = np.zeros((4, 5), dtype=int)
    for label, _, feature in rows:
        result, reject, _ = decision(feature, templates)
        matrix[label, 4 if reject else result] += 1
    return matrix


def pack(feature):
    return ''.join(f'{int(v):04x}' for v in feature[::-1])


def train(sim):
    manifest = json.loads((WORK/'manifest.json').read_text())
    if manifest.get('feature_source_hashes') != feature_hashes():
        raise ValueError('RTL changed since WAV preparation; rerun the full extraction command')
    log = ROOT/'build/extract_recording_features.log'
    if not log.exists() or 'ALL TESTS PASSED: extract_recording_features' not in log.read_text():
        raise ValueError('A completed RTL extraction is required before training')
    records = manifest['records']
    rows, all_rows, seen = [], [], [0] * len(records)
    with (WORK/'features.csv').open() as stream:
        for row in csv.DictReader(stream):
            token = int(row['token_index'])
            record = records[token]
            packed = int(row['feature'], 16)
            feature = np.array([(packed >> (16*i)) & 65535 for i in range(24)], dtype=np.int64)
            item = (record['class_index'], token, feature)
            all_rows.append(item)
            if seen[token] in record['kept_frames']:
                rows.append(item)
            seen[token] += 1
    if seen != [r['frames'] for r in records]:
        raise ValueError('RTL frame counts do not match the WAV manifest')
    # Alternate whole recordings of EACH vowel between folds. No frame random split.
    fold_of = {}
    for label in range(4):
        for i, token in enumerate(t for t, r in enumerate(records) if r['class_index'] == label):
            fold_of[token] = i % 2
    matrix = np.zeros((4, 5), dtype=int)
    folds = []
    for fold in range(2):
        training = [r for r in rows if fold_of[r[1]] != fold]
        testing = [r for r in rows if fold_of[r[1]] == fold]
        score = matrix_score(testing, fit(training))
        matrix += score
        folds.append(dict(heldout_files=[records[t]['file'] for t in fold_of if fold_of[t] == fold],
                          training_files=[records[t]['file'] for t in fold_of if fold_of[t] != fold],
                          confusion=score.tolist()))
    final = fit(rows)
    target = ROOT/'assets/recordings'
    target.mkdir(exist_ok=True)
    header = ROOT/'rtl/templates.svh'
    write_svh(str(header), final.reshape(16, 24), 24)
    header.write_text('// Group WAV recordings; generated by tools/train_recordings.py.\n'
                      'localparam bit TEMPLATES_READY = 1;\nlocalparam int TEMPLATE_D = 24;\n'
                      'localparam int TEMPLATE_NT = 4;\n'+header.read_text())
    (ROOT/'rtl/templates.hex').write_text(''.join(pack(row)+'\n' for row in final.reshape(16, 24)))
    # All captured frames (including discarded low-energy ones) exercise Python/RTL agreement.
    expected = []
    for _, _, f in all_rows:
        result, reject, confidence = decision(f, final)
        expected.append(f'{((0 if reject else result)<<9)|(int(reject)<<8)|confidence:03x}')
    (target/'features.hex').write_text(''.join(pack(f)+'\n' for _, _, f in all_rows))
    (target/'expected.hex').write_text('\n'.join(expected)+'\n')
    (target/'test_dimensions.svh').write_text(f'localparam int RECORDING_TEST_FRAMES={len(all_rows)};\n')
    shutil.copyfile(WORK/'manifest.json', target/'manifest.json')
    shutil.copyfile(WORK/'features.csv', target/'features.csv')
    total = int(matrix.sum())
    accepted = int(matrix[:, :4].sum())
    correct = int(np.trace(matrix[:, :4]))
    report = dict(source='data/recordings (group WAV recordings)', labels=LABELS,
                  dimensions=24, feature_mode=4, log_scale=64, templates_per_class=4,
                  rho='7/10', dmax=65000, training_frames=[sum(c==k for c,_,_ in rows) for k in range(4)],
                  template_allocation='Equal slots per recording up to four takes/class; for the supplied two speakers, two templates per recording. More than four takes use equal-recording-weight pooled clustering.',
                  feature_extraction=f'Actual audio_frontend -> course FFT -> fft_mag_sq -> audio_features MODE=4; simulator={sim}',
                  validation='Two folds by complete recordings, then final deployment ROM retrained on all eight supplied recordings (or all replacement input files)',
                  folds=folds, held_out_confusion_columns=LABELS+['reject'], held_out_confusion=matrix.tolist(),
                  held_out_frames=total, accepted_accuracy=correct/accepted if accepted else 0,
                  overall_correct_fraction=correct/total, rejection_fraction=(total-accepted)/total,
                  final_training_confusion=matrix_score(rows, final).tolist(),
                  regression_frames=len(all_rows), template_sha256=sha(header),
                  feature_source_hashes=manifest['feature_source_hashes'],
                  recordings=[dict(file=r['file'], sha256=r['sha256']) for r in records],
                  note='Final training-set scores and Python/RTL agreement are not held-out accuracy. '
                       'Only two takes per vowel were supplied; speakers are unknown. Live microphone/room/pitch generalisation is unmeasured.')
    (ROOT/'rtl/templates_training.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ['training_frames','held_out_confusion','overall_correct_fraction',
                                          'rejection_fraction','final_training_confusion']}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, default=ROOT/'data/recordings')
    parser.add_argument('--sim', choices=['modelsim', 'verilator'], default='verilator')
    parser.add_argument('--stage', choices=['all','prepare','train'], default='all')
    args = parser.parse_args()
    if args.stage in ('all','prepare'):
        prepare(args.samples.resolve())
    if args.stage == 'all':
        subprocess.run([sys.executable, str(ROOT/'tools/run_tests.py'), '--sim', args.sim,
                        'extract_recording_features'], cwd=ROOT, check=True)
    if args.stage in ('all','train'):
        train(args.sim)
    if args.stage == 'all':
        subprocess.run([sys.executable, str(ROOT/'tools/check_project.py'), '--require-trained'], cwd=ROOT, check=True)
        subprocess.run([sys.executable, str(ROOT/'tools/run_tests.py'), '--sim', args.sim,
                        'tb_recording_classifier'], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
