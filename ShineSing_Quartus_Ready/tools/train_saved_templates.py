"""Save recorded HD vowel features for startup without live enrolment.

python tools/train_saved_templates.py ee.csv ah.csv oo.csv aw.csv
Use SignalTap exports from MODE=4, D=24, LOG_SCALE=64 in lane order.
Capture feature[23:0][15:0], feature_valid and voice (as enable).
Keep only voice frames. Record varied pitch and distance before the demo.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from provided_train_templates import read_capture, kmeans_sad, write_svh
from template_common import decision

ROOT = Path(__file__).resolve().parents[1]
LABELS = ['ee', 'ah', 'oo', 'aw']


def predict(feature, templates):
    result, rejected, _ = decision(feature, templates)
    return 4 if rejected else result


def train(captures, out_dir, holdout=0.3):
    if len(captures) != 4 or not 0 < holdout < 1:
        raise ValueError('Supply four vowel captures and a holdout fraction between 0 and 1.')
    templates, held_out, sources = [], [], []
    for label, path in zip(LABELS, captures):
        frames, _, width = read_capture(str(path), radix='hex')
        values = np.asarray(frames, dtype=np.int64)
        if width != 24 or len(values) < 20:
            raise ValueError(f'{label}: need at least 20 valid frames with 24 features from the HD build.')
        # Keep the last part separate to avoid mixing nearby training and test frames.
        split = int(len(values) * (1 - holdout))
        if split < 4 or split >= len(values):
            raise ValueError(f'{label}: not enough training or held-out frames.')
        centres = np.rint(kmeans_sad(values[:split].astype(float), 4)).astype(np.int64)
        templates.append(centres)
        held_out.append(values[split:])
        sources.append({'vowel': label, 'file': Path(path).name,
                        'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest(),
                        'training_frames': split, 'held_out_frames': len(values)-split})
    templates = np.asarray(templates)
    matrix = [[0]*5 for _ in LABELS]
    for label, frames in enumerate(held_out):
        for frame in frames:
            matrix[label][predict(frame, templates)] += 1
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    header = out_dir / 'templates.svh'
    write_svh(str(header), templates.reshape(16, 24), 24)
    header.write_text('// Recorded vowel templates: ee, ah, oo, aw. Reset keeps these values.\n'
                      'localparam bit TEMPLATES_READY = 1;\n'
                      'localparam int TEMPLATE_D = 24;\n'
                      'localparam int TEMPLATE_NT = 4;\n' + header.read_text())
    (out_dir / 'templates.hex').write_text(''.join(
        ''.join(f'{int(v):04x}' for v in row[::-1])+'\n' for row in templates.reshape(16, 24)))
    report = {'feature_mode': 4, 'dimensions': 24, 'log_scale': 64,
              'templates_per_class': 4, 'rho': '7/10', 'dmax': 65000,
              'labels': LABELS, 'sources': sources,
              'held_out_confusion_columns': LABELS+['reject'],
              'held_out_confusion': matrix,
              'note': 'Frame results before voting. Check separate live pitch/distance trials on the board.'}
    (out_dir / 'templates_training.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', nargs=4, type=Path, metavar='CSV')
    parser.add_argument('--out-dir', type=Path, default=ROOT/'rtl')
    parser.add_argument('--holdout', type=float, default=0.3)
    args = parser.parse_args()
    try:
        report = train(args.captures, args.out_dir, args.holdout)
    except ValueError as error:
        parser.error(str(error))
    print('Saved templates in', args.out_dir)
    print('Held-out rows: ee ah oo aw. Columns: ee ah oo aw reject.')
    for row in report['held_out_confusion']:
        print(*row)


if __name__ == '__main__':
    main()
