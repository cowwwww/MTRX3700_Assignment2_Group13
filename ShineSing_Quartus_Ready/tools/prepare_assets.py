"""Rebuild image memories from the bundled PNGs or a supplied image folder."""
from pathlib import Path
import argparse
import math
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def convert_image(source, destination):
    """Run the original Barcode Reader image and MIF converter."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(ROOT/'tools'/'image_to_mif.py'),
                    str(source), str(destination)], check=True)

def write_memory(path, values, width):
    values = list(values)
    path.with_suffix('.hex').write_text(''.join(f'{v:0{(width+3)//4}x}\n' for v in values))
    path.with_suffix('.mif').write_text(
        f'WIDTH={width};\nDEPTH={len(values)};\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n' +
        ''.join(f'{i}: {v:0{(width+3)//4}x};\n' for i,v in enumerate(values)) + 'END;\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--images', type=Path, help='Folder containing ParallelPiano.png and ParallelPiano2.png')
    args = parser.parse_args()
    assets=ROOT/'assets'
    for i,name in enumerate(('ParallelPiano.png','ParallelPiano2.png')):
        source=(args.images/name) if args.images else assets/f'piano{i}.png'
        convert_image(source, assets/f'piano{i}')
    # Use a copy in slot 2 until the tutor photo is available.
    # tools/import_image.py replaces it; the ROM stores pixels, not key edges.
    for suffix in ('.hex','.mif','.png'):
        (assets/('piano2'+suffix)).write_bytes((assets/('piano1'+suffix)).read_bytes())
    write_memory(assets/'hamming',[round((.54-.46*math.cos(2*math.pi*n/1023))*32767) for n in range(1024)],16)
    thresholds=[math.ceil(10**((d-.5)/20)) for d in range(1,91)]
    (ROOT/'rtl'/'db_thresholds.svh').write_text("localparam logic [15:0] DB_THRESHOLD[1:90]='{"+', '.join(map(str,thresholds))+"};\n")

if __name__=='__main__': main()
