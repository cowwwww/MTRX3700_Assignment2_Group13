"""Generate exact FIR/window fixtures plus an independent floating FFT reference."""
import numpy as np
from prepare_assets import ROOT
H=np.array([0,20,63,80,0,-245,-682,-1272,-1887,-2322,-2317,-1611,0,2605,6132,10336,14819,19083,22603,24925,25736,24925,22603,19083,14819,10336,6132,2605,0,-1611,-2317,-2322,-1887,-1272,-682,-245,0,80,63,20,0],dtype=np.int64)
window=np.array([int(s,16) for s in (ROOT/'assets'/'hamming.hex').read_text().split()],dtype=np.int64)
# Bin 80 at fs=12k; input sampled at fs=48k. Three consecutive frames, last twice as loud.
n=np.arange(3*4096);amp=np.where(n>=2*4096,12000,6000)
pcm=np.rint(amp*np.sin(2*np.pi*80*n/4096)).astype(np.int64)
fir=np.clip(np.convolve(pcm,H)[:len(pcm)]>>18,-32768,32767)
framed=(fir[3::4].reshape(-1,1024)*window)>>15
for name,values in [('audio_pcm',pcm),('audio_windowed',framed.flatten())]:
 (ROOT/'assets'/f'{name}.hex').write_text(''.join(f'{int(v)&65535:04x}\n' for v in values))
assert all(np.argmax(abs(np.fft.rfft(f))[1:512])+1==80 for f in framed)
print('Generated three exact FIR/Hamming frame fixtures; reference peak bin = 80.')
