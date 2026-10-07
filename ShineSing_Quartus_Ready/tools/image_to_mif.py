#!/usr/bin/env python3
"""Any picture -> 320x240 8-bit grey .mif + .hex + .png (for the reader, or for the assignment's piano).
    python3 tools/image_to_mif.py photo.jpg images/photo
Needs Pillow. Resizes to 320x240 (letterboxed, grey borders), converts to greyscale."""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from make_barcode import write_mif, write_hex, write_png, W, H

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("L")
im.thumbnail((W, H))
canvas = Image.new("L", (W, H), 128); canvas.paste(im, ((W - im.width) // 2, (H - im.height) // 2))
img = np.asarray(canvas, dtype=np.uint8)
write_mif(out + ".mif", img); write_hex(out + ".hex", img); write_png(out + ".png", img)
print(f"wrote {out}.mif/.hex/.png from {src} ({im.width}x{im.height} inside {W}x{H})")
