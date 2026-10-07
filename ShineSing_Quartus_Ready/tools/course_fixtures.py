"""Calculate regression results from the supplied mini-project datasets."""
from pathlib import Path
import re
import numpy as np
from image_reference import analyse
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/course_expected'
OUT.mkdir(exist_ok=True)
for picture,name in enumerate(['barcode','barcode2']):
    pixels=np.array([int(v,16) for v in (ROOT/f'course_sources/video/images/{name}.hex').read_text().split()]).reshape(240,320)
    for mode in range(2):
        edge,profile,keys=analyse(pixels,mode,gap=3)
        for suffix,values,width in [('',profile,2),('_edges',edge.flat,2),('_keys',[len(keys),*keys,*([0]*(16-len(keys)))],3)]:
            (OUT/f'image_{picture}_{mode}{suffix}.hex').write_text(''.join(f'{int(v):0{width}x}\n' for v in values))
# Read the exact tap values from the supplied FIR, not a second copied table.
source=(ROOT/'course_sources/fir/low_pass_conv.sv').read_text()
coeff=np.array([int(v,16) for v in re.findall(r"32'h([0-9a-f]+)",source)],dtype=np.int64)
coeff=np.where(coeff>=2**31,coeff-2**32,coeff)
assert len(coeff)==41
wave=np.array([int(v,16) for v in (ROOT/'course_sources/audio/test_waveform.hex').read_text().split()],dtype=np.int64)
wave=np.where(wave>=32768,wave-65536,wave)
pcm=np.tile(wave,12)
window=np.array([int(v,16) for v in (ROOT/'assets/hamming.hex').read_text().split()])
filtered=np.clip(np.convolve(pcm,coeff)[:len(pcm)]>>18,-32768,32767)
frames=(filtered[3::4].reshape(3,1024)*window)>>15
peaks=[np.argmax(abs(np.fft.rfft(frame))[1:512])+1 for frame in frames]
for name,values in [('pcm',pcm),('windowed',frames.flat),('peaks',peaks)]:
    (OUT/f'{name}.hex').write_text(''.join(f'{int(v)&65535:04x}\n' for v in values))
print('Course waveform FFT peaks:',peaks)
