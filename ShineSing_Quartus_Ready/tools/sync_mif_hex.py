"""Update simulation HEX files after replacing a MIF file; use --slot 2."""
from pathlib import Path
import argparse, re

def parse_mif(text):
    text = re.sub(r'%.*?%', '', text, flags=re.S)
    text = re.sub(r'--[^\n]*', '', text).upper()
    def field(name):
        match = re.search(r'\b'+name+r'\s*=\s*(\w+)\s*;', text)
        if not match:
            raise ValueError(f'Missing {name}')
        return match[1]
    width, depth = int(field('WIDTH')), int(field('DEPTH'))
    if (width, depth) != (8, 320*240):
        raise ValueError(f'Expected 320x240 grayscale (WIDTH=8, DEPTH=76800); got {width}, {depth}. Convert the source image with import_image.py or adapt dimensions explicitly.')
    bases = {'BIN': 2, 'OCT': 8, 'DEC': 10, 'UNS': 10, 'HEX': 16}
    ab, db = bases[field('ADDRESS_RADIX')], bases[field('DATA_RADIX')]
    content = re.search(r'CONTENT\s+BEGIN(.*?)END\s*;', text, re.S)
    if not content:
        raise ValueError('Missing CONTENT BEGIN ... END;')
    values = [None]*depth
    for entry in content[1].split(';'):
        if not entry.strip():
            continue
        address, data = entry.split(':')
        if '[' in address:
            first, last = (int(s.strip(), ab) for s in address.strip().strip('[]').split('..'))
        else:
            first = last = int(address.strip(), ab)
        value = int(data.strip(), db)
        if not (0 <= first <= last < depth and 0 <= value < 256):
            raise ValueError(f'Out-of-range MIF entry: {entry}')
        values[first:last+1] = [value]*(last-first+1)
    if None in values:
        raise ValueError('MIF must define every pixel explicitly or with ranges.')
    return values

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--slot', type=int, choices=range(3), default=2)
    args = parser.parse_args()
    base = Path(__file__).resolve().parents[1]/'assets'/f'piano{args.slot}'
    values = parse_mif(base.with_suffix('.mif').read_text())
    base.with_suffix('.hex').write_text(''.join(f'{v:02x}\n' for v in values))
    print(f'Synchronized {len(values)} pixels in {base.name}.hex; hardware reads the MIF directly.')
