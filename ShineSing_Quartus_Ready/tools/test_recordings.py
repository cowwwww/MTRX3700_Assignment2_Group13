"""Boundary tests for PCM conversion and the short-recording template path."""
import unittest
import numpy as np
from train_recordings import decode_pcm, centres, pack, fit
from template_common import decision


class RecordingTests(unittest.TestCase):
    def test_signed_24_bit_extremes_and_stereo_order(self):
        words = [-8388608, -1, 0, 8388607]
        raw = b''.join((v & 0xffffff).to_bytes(3, 'little') for v in words)
        result = decode_pcm(raw, 3, 2)
        np.testing.assert_array_equal(result, np.array(words).reshape(2, 2)/8388608)

    def test_other_pcm_widths(self):
        np.testing.assert_array_equal(decode_pcm(bytes([0,128,255]),1,1).ravel(), [-1,0,127/128])
        for width, dtype in [(2,'<i2'),(4,'<i4')]:
            bound = 1 << (8*width-1)
            values = np.array([-bound,-1,0,bound-1],dtype=dtype)
            np.testing.assert_array_equal(decode_pcm(values.tobytes(),width,1).ravel(), values.astype(float)/bound)

    def test_short_recordings_keep_four_templates_without_fake_samples(self):
        values = np.array([[100+i for i in range(24)], [500+i for i in range(24)]])
        result = centres(values)
        self.assertEqual(result.shape, (4,24))
        for row in result:
            self.assertTrue(any(np.array_equal(row, original) for original in values))
        self.assertEqual(pack(values[0])[-4:], '0064')
        self.assertEqual(pack(values[0])[:4], '007b')

    def test_unsigned_distance_and_exact_ratio_boundary(self):
        templates = np.array([[[100]], [[200]], [[300]], [[400]]], dtype=np.uint16)
        self.assertEqual(decision(np.array([0],dtype=np.uint16),templates), (0,False,127))
        # d1/d2=7/10 is accepted; one count nearer the competing class is rejected.
        templates = np.array([[[0]], [[17]], [[100]], [[200]]])
        self.assertEqual(decision([7],templates), (0,False,76))
        self.assertTrue(decision([8],templates)[1])

    def test_two_recordings_get_two_slots_each_despite_duration(self):
        rows = []
        for c in range(4):
            rows.extend((c, 2*c, np.full(24, 1000*c+10)) for _ in range(30))
            rows.extend((c, 2*c+1, np.full(24, 1000*c+500)) for _ in range(2))
        templates = fit(rows)
        for c in range(4):
            np.testing.assert_array_equal(templates[c,:2], np.full((2,24),1000*c+10))
            np.testing.assert_array_equal(templates[c,2:], np.full((2,24),1000*c+500))


if __name__ == '__main__':
    unittest.main()
