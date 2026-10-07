"""Prepare real H95 vowel segments for feature extraction by the RTL pipeline."""
from pathlib import Path
import hashlib
import io
import json
import wave
import zipfile
import numpy as np
from scipy.signal import resample_poly
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/h95'
LABELS={'iy':0,'ah':1,'uw':2,'aw':3}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    archive=ROOT/'data/h95/h95.zip'
    corpus=zipfile.ZipFile(archive)
    timing={}
    for line in corpus.read('timedata.dat').decode().splitlines():
        parts=line.split()
        if len(parts)==5 and parts[0][-2:] in LABELS:
            timing[parts[0]]=list(map(float,parts[1:]))
    records=[]
    with (OUT/'pcm.hex').open('w') as output:
        for group in ['men','women','kids']:
            audio=zipfile.ZipFile(io.BytesIO(corpus.read(group+'.zip')))
            for filename in sorted(audio.namelist()):
                token=Path(filename).stem.lower()
                if token not in timing: continue
                raw=audio.read(filename)
                with wave.open(io.BytesIO(raw)) as sound:
                    if (sound.getnchannels(),sound.getsampwidth(),sound.getframerate())!=(1,2,16000):
                        raise ValueError('Unexpected WAV format: '+filename)
                    pcm=np.frombuffer(sound.readframes(sound.getnframes()),dtype='<i2').astype(float)
                # Upsample to the codec rate; all later filtering is done by the real RTL.
                pcm48=np.clip(np.rint(resample_poly(pcm,3,1)),-32768,32767).astype(np.int64)
                start,end,c1,c2=timing[token]
                first=int(np.ceil(start*48));last=int(np.floor(end*48))
                frames=min(2,(last-first)//4096)
                if frames<1: continue
                centre=int(round((c1+c2)*24))
                begin=max(first,min(centre-frames*2048,last-frames*4096))
                segment=pcm48[begin:begin+frames*4096]
                if len(segment)!=frames*4096: raise ValueError(token)
                output.write(''.join(f'{int(v)&65535:04x}\n' for v in segment))
                records.append({'token':token,'speaker':token[:3],'class':LABELS[token[-2:]],
                    'archive_member':group+'.zip/'+filename,'wav_sha256':hashlib.sha256(raw).hexdigest(),
                    'start_sample_48k':begin,'frames':frames,
                    'split':'test' if int(token[1:3])%5==0 else 'train'})
    (OUT/'counts.hex').write_text(''.join(f'{r["frames"]:x}\n' for r in records))
    (OUT/'dimensions.svh').write_text(f'localparam int TOKENS={len(records)}, SAMPLES={sum(r["frames"]*4096 for r in records)};\n')
    manifest={'source':'user-supplied h95.zip','archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
      'mapping':{'ee':'iy (heed)','ah':'ah (hod/cot)','oo':'uw (who\'d)','aw':'aw (hawed)'},
      'resample':'16 kHz to 48 kHz with scipy.signal.resample_poly(up=3,down=1), round and saturate PCM16',
      'segments':'Up to two complete 85.33 ms frames near the labelled steady state, inside the vowel nucleus',
      'split':'All tokens of speakers whose number is divisible by 5 are held out; never used for training.',
      'records':records}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Prepared {len(records)} real recordings, {sum(r["frames"] for r in records)} frames',flush=True)

if __name__=='__main__':main()
