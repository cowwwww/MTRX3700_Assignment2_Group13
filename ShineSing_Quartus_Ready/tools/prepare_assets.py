"""Reproducible ROMs from the two Canvas examples (no key coordinates baked in)."""
from pathlib import Path
import math
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def convert_image(source, destination):
    """Run the unmodified Barcode Reader converter, including its MIF writer."""
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
    assets=ROOT/'assets'
    for i,name in enumerate(('ParallelPiano.png','ParallelPiano2.png')):
        source=ROOT/'reference_materials'/'piano_examples'/name
        convert_image(source, assets/f'piano{i}')
    # Slot 2 is explicitly a duplicate until a tutor photo is supplied.
    # tools/import_image.py replaces it; no inferred boundaries stored in ROM.
    for suffix in ('.hex','.mif','.png'):
        (assets/('piano2'+suffix)).write_bytes((assets/('piano1'+suffix)).read_bytes())
    write_memory(assets/'hamming',[round((.54-.46*math.cos(2*math.pi*n/1023))*32767) for n in range(1024)],16)
    write_memory(assets/'db',[round(20*math.log10(max(i,1))) for i in range(32769)],7)
    thresholds=[math.ceil(10**((d-.5)/20)) for d in range(1,91)]
    (ROOT/'rtl'/'db_thresholds.svh').write_text("localparam logic [15:0] DB_THRESHOLD[1:90]='{"+', '.join(map(str,thresholds))+"};\n")

if __name__=='__main__': main()
