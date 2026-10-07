"""Calculate expected image edges, column totals and peaks with numpy."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from prepare_assets import ROOT

def analyse(image, sobel, high=96, low=32, gap=12):
    a=np.asarray(image,dtype=np.int64);h,w=a.shape
    gx=np.zeros_like(a);gy=np.zeros_like(a)
    if sobel:
        gx[1:-1,1:-1]=(a[:-2,2:]+2*a[1:-1,2:]+a[2:,2:]-a[:-2,:-2]-2*a[1:-1,:-2]-a[2:,:-2])
        gy[1:-1,1:-1]=(a[2:,:-2]+2*a[2:,1:-1]+a[2:,2:]-a[:-2,:-2]-2*a[:-2,1:-1]-a[:-2,2:])
        edge=np.minimum(255,(abs(gx)+abs(gy))//4)
    else:
        gx[:,1:]=a[:,1:]-a[:,:-1]
        edge=abs(gx)
    raw=abs(gx)[h*7//10:h*17//20+1].sum(axis=0)
    maximum=int(raw.max())
    norm=np.minimum(255,raw*256//maximum) if maximum else raw*0
    candidates=[x for x in range(1,w-1) if norm[x]>norm[x-1] and norm[x]>=norm[x+1]]
    # Keep each low-threshold group only if one column passes the high threshold.
    keep=[];x=0
    while x<w:
        if norm[x]<low or norm[x]==0: x+=1;continue
        start=x
        while x<w and norm[x]>=low and norm[x]>0: x+=1
        peaks=[p for p in candidates if start<=p<x]
        if not peaks or norm[start:x].max()<high: continue
        best=max(peaks,key=lambda p:int(norm[p]))
        if keep and best-keep[-1]<gap:
            if norm[best]>norm[keep[-1]]: keep[-1]=best
        else: keep.append(best)
    return edge,norm,keep[:16]

def main():
    (ROOT/'build').mkdir(exist_ok=True)
    result={}
    for picture in range(2):
        a=Image.open(ROOT/'assets'/f'piano{picture}.png')
        for mode in range(2):
            edge,profile,keys=analyse(a,mode)
            prefix=ROOT/'assets'/f'expected_{picture}_{mode}'
            prefix.with_suffix('.hex').write_text(''.join(f'{int(x):02x}\n' for x in profile))
            Path(str(prefix)+'_edges.hex').write_text(''.join(f'{int(x):02x}\n' for x in edge.flat))
            Path(str(prefix)+'_keys.hex').write_text(''.join(f'{x:03x}\n' for x in [len(keys),*keys,*([0]*(16-len(keys)))]))
            Image.fromarray(edge.astype('uint8')).save(ROOT/'build'/f'edges_{picture}_{mode}.png')
            result[f'image{picture}_sobel{mode}']=keys
    (ROOT/'docs'/'reference_boundaries.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))
if __name__=='__main__': main()
