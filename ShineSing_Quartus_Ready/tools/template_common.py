"""Integer decision rule shared by the WAV, H95 and SignalTap training paths."""
import numpy as np


def decision(feature, templates):
    # Cast before subtracting to prevent unsigned 16-bit distance wraparound.
    distances = np.abs(np.asarray(templates, dtype=np.int64) -
                       np.asarray(feature, dtype=np.int64)).sum(axis=2).min(axis=1)
    order = distances.argsort(kind='stable')
    c = int(order[0])
    d1, d2 = int(distances[c]), int(distances[order[1]])
    reject = d2 == 0 or d1 > 65000 or d1 * 10 > d2 * 7
    confidence = 0 if reject else 255 - (256 * d1 // d2)
    return c, reject, confidence
