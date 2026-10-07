#!/usr/bin/env python3
"""Make a barcode picture for the reader: 320x240 8-bit grey, as barcode.mif (Quartus), barcode.hex
($readmemh) and barcode.png (to look at).

    python3 tools/make_barcode.py --code 0xA5 [--narrow 6 --wide 12 --space 6 --noise 0 --gradient 0 --blur 0]

The code is NB bits (8): one dark bar per bit, wide = 1, narrow = 0, spaces of fixed width
between them. Quiet zones left and right. The .mif uses address ranges for runs of equal
pixels so it stays small (Ed's workspace disk is tiny)."""
import argparse, os
import numpy as np

W, H = 320, 240

def make(code, nb=8, narrow=6, wide=12, space=6, white=230, black=25, noise=0.0, gradient=0.0, blur=0, seed=1):
    rng = np.random.default_rng(seed)
    img = np.full((H, W), white, dtype=float)
    bits = [(code >> (nb - 1 - i)) & 1 for i in range(nb)]
    widths = [wide if b else narrow for b in bits]
    total = sum(widths) + space * (nb - 1)
    x = (W - total) // 2
    y0, y1 = 50, 190
    bars = []
    for wd in widths:
        img[y0:y1, x:x + wd] = black; bars.append((x, x + wd)); x += wd + space
    if gradient:
        img *= np.linspace(1 - gradient, 1, W)[None, :]
    for _ in range(blur):                                   # a 3x3 box blur per pass: soft edges, as a camera gives
        p = np.pad(img, 1, mode="edge"); img = sum(p[dy:dy + H, dx:dx + W] for dy in range(3) for dx in range(3)) / 9.0
    if noise:
        img += rng.normal(0, noise, img.shape)
    return np.clip(img, 0, 255).astype(np.uint8), bars

def write_mif(path, img):
    flat = img.flatten()
    lines = [f"WIDTH=8;", f"DEPTH={flat.size};", "ADDRESS_RADIX=UNS;", "DATA_RADIX=HEX;", "CONTENT BEGIN"]
    i = 0
    while i < flat.size:
        j = i
        while j + 1 < flat.size and flat[j + 1] == flat[i]: j += 1
        lines.append(f"  [{i}..{j}] : {flat[i]:02X};" if j > i else f"  {i} : {flat[i]:02X};")
        i = j + 1
    lines.append("END;")
    open(path, "w").write("\n".join(lines) + "\n")

def write_hex(path, img):
    open(path, "w").write("\n".join(f"{v:02X}" for v in img.flatten()) + "\n")

def write_png(path, img):
    try:
        from PIL import Image
        Image.fromarray(img, "L").save(path)
    except ImportError:
        pass

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--code", type=lambda s: int(s, 0), default=0xA5)
    ap.add_argument("--narrow", type=int, default=6); ap.add_argument("--wide", type=int, default=12)
    ap.add_argument("--space", type=int, default=6)
    ap.add_argument("--noise", type=float, default=0.0); ap.add_argument("--gradient", type=float, default=0.0)
    ap.add_argument("--blur", type=int, default=0)
    ap.add_argument("--out", default="images/barcode")
    a = ap.parse_args()
    img, bars = make(a.code, narrow=a.narrow, wide=a.wide, space=a.space, noise=a.noise, gradient=a.gradient, blur=a.blur)
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    write_mif(a.out + ".mif", img); write_hex(a.out + ".hex", img); write_png(a.out + ".png", img)
    edges = sorted(e for b in bars for e in b)
    open(a.out + ".txt", "w").write(f"code=0x{a.code:02X}\nedges={' '.join(map(str, edges))}\n")
    print(f"wrote {a.out}.mif/.hex/.png  code=0x{a.code:02X}  edges={edges}")
