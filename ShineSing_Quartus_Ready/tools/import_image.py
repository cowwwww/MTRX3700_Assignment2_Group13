"""Load a photo: python tools/import_image.py photograph.png --slot 2"""
import argparse
from prepare_assets import ROOT, convert_image
p=argparse.ArgumentParser()
p.add_argument('image');p.add_argument('--slot',type=int,choices=range(3),default=2)
a=p.parse_args()
convert_image(a.image, ROOT/'assets'/f'piano{a.slot}')
