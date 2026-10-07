"""Check saved-template order, validation and rejection with made-up features."""
import csv
import tempfile
import unittest
from pathlib import Path
import numpy as np
from train_saved_templates import train, predict


class SavedTemplatesTest(unittest.TestCase):
    def test_training_and_packing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = []
            for c, label in enumerate(['ee', 'ah', 'oo', 'aw']):
                path = root / (label+'.csv')
                with path.open('w', newline='') as output:
                    writer = csv.writer(output)
                    writer.writerow(['feature[23..0][15..0]', 'feature_valid', 'enable'])
                    for _ in range(24):
                        words = [10000+c*1000+i for i in range(24)]
                        writer.writerow([''.join(f'{v:04x}' for v in words[::-1]), 1, 1])
                paths.append(path)
            report = train(paths, root/'out')
            rows = (root/'out/templates.hex').read_text().splitlines()
            self.assertEqual(len(rows), 16)
            for c in range(4):
                self.assertEqual(int(rows[c*4][-4:], 16), 10000+c*1000)
                self.assertEqual(int(rows[c*4][:4], 16), 10023+c*1000)
                self.assertEqual(report['held_out_confusion'][c][c], 8)
                self.assertEqual(sum(report['held_out_confusion'][c]), 8)
            self.assertIn('TEMPLATES_READY = 1', (root/'out/templates.svh').read_text())
            with self.assertRaises(ValueError):
                train(paths[:3], root/'bad')

    def test_ambiguous_and_far_frames_rejected(self):
        self.assertEqual(predict(np.zeros(24), np.zeros((4,4,24))), 4)
        self.assertEqual(predict(np.full(24,65535), np.zeros((4,4,24))), 4)


if __name__ == '__main__':
    unittest.main()
