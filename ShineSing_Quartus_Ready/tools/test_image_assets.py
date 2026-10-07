"""Catch stretched/resampled images, stale HEX/MIF, and a bypassed course converter."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from PIL import Image
from sync_mif_hex import parse_mif

ROOT = Path(__file__).resolve().parents[1]


class ImageAssetsTest(unittest.TestCase):
    def test_bundled_images_match_course_converter(self):
        with tempfile.TemporaryDirectory() as tmp:
            for slot, name in enumerate(('ParallelPiano.png', 'ParallelPiano2.png')):
                source = ROOT/'reference_materials/piano_examples'/name
                if not source.exists():
                    self.skipTest('Original photos are in the full handoff package')
                prefix = Path(tmp)/f'piano{slot}'
                subprocess.run([sys.executable, str(ROOT/'tools/image_to_mif.py'),
                                str(source), str(prefix)], check=True, capture_output=True)
                # Text mode normalizes Windows CRLF vs Ed/Linux LF. PNG encoders
                # may differ between Pillow/zlib builds; compare actual pixels.
                for suffix in ('.mif', '.hex'):
                    with self.subTest(slot=slot, suffix=suffix):
                        self.assertTrue(prefix.with_suffix(suffix).read_text() ==
                                        (ROOT/'assets'/f'piano{slot}{suffix}').read_text(),
                                        f'piano{slot}{suffix} differs from the course converter')
                with self.subTest(slot=slot, suffix='.png'), \
                     Image.open(prefix.with_suffix('.png')) as expected, \
                     Image.open(ROOT/'assets'/f'piano{slot}.png') as actual:
                    self.assertEqual((actual.mode, actual.size), (expected.mode, expected.size))
                    self.assertEqual(actual.tobytes(), expected.tobytes())

    def test_all_rom_formats_have_identical_pixels(self):
        for slot in range(3):
            prefix = ROOT/'assets'/f'piano{slot}'
            mif = parse_mif(prefix.with_suffix('.mif').read_text())
            hex_pixels = [int(v, 16) for v in prefix.with_suffix('.hex').read_text().split()]
            with Image.open(prefix.with_suffix('.png')) as image:
                self.assertEqual(image.size, (320, 240))
                self.assertEqual(bytes(mif), image.tobytes())
            self.assertEqual(mif, hex_pixels)

    def test_import_keeps_small_image_size_and_centres_on_grey(self):
        # thumbnail must not upscale: a 2x2 input occupies exactly the centre 2x2.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT/'tools', root/'tools', ignore=shutil.ignore_patterns('__pycache__'))
            (root/'assets').mkdir()
            source = root/'tiny.png'
            image = Image.new('L', (2, 2))
            image.putdata([0, 255, 64, 192])
            image.save(source)
            subprocess.run([sys.executable, str(root/'tools/import_image.py'),
                            str(source), '--slot', '2'], check=True, capture_output=True)
            values = parse_mif((root/'assets/piano2.mif').read_text())
            expected = [128] * 76800
            for x, y, v in [(159,119,0), (160,119,255), (159,120,64), (160,120,192)]:
                expected[y*320+x] = v
            self.assertEqual(bytes(values), bytes(expected))


if __name__ == '__main__':
    unittest.main(verbosity=2)
