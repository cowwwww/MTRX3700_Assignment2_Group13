"""Convert actual RTL edge-map captures to portable PNGs for visual inspection."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
dest=ROOT/'docs/evidence';dest.mkdir(exist_ok=True)
captures=list((ROOT/'build').glob('rtl_edge_*.ppm'))
if len(captures)!=4: raise SystemExit('Run tb_piano_detector first; expected four RTL edge captures.')
for file in captures:
 Image.open(file).save(dest/(file.stem+'.png'))
print(f'Rendered {len(captures)} actual RTL captures.')
