"""Capture video frames from the design for the demo."""
from pathlib import Path
import argparse
import csv
import json
import shutil
import subprocess
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render-only', action='store_true')
args = parser.parse_args()
build = ROOT/'build/demo'
build.mkdir(parents=True, exist_ok=True)
if not args.render_only:
    subprocess.run([sys.executable, str(ROOT/'tools/run_tests.py'), '--sim', 'modelsim', 'demo_visual'],
                   cwd=ROOT, check=True)
log = (ROOT/'build/demo_visual.log').read_text(encoding='utf-8')
if 'ALL TESTS PASSED: demo_visual' not in log:
    raise SystemExit('Demo did not pass; incomplete frames are not publishable.')
dest = ROOT/'docs/evidence/demo'
dest.mkdir(parents=True, exist_ok=True)
labels = {
    '01_untrained': '尚未录入：四个状态块为红色',
    '02_ready': '四类录入完成：状态块变绿',
    '03_countdown2': '第一个键：倒计时 2',
    '04_countdown1': '第一个键：倒计时 1，亮度增加',
    '05_hit_window': '第一个键：红色命中窗口',
    '06_wrong_vowel': '输入合成类别 1：类别错误，分数仍为 0',
    '07_correct_vowel': '输入合成类别 0：命中变绿，分数变为 1',
    '08_duplicate_ignored': '再次输入类别 0：分数仍为 1',
    '09_second_window': '第二个键：红色命中窗口',
    '10_miss': '未输入：第二个键超时，分数仍为 1',
}
view_names = {'edge_1d': '1-D 边缘图', 'edge_sobel': 'Sobel 边缘图',
              'profile': '列曲线与高低阈值', 'masks': '四键掩膜'}
for picture in range(2):
    for suffix, title in view_names.items():
        labels[f'p{picture}_{suffix}'] = f'图片 {picture}：{title}'
with (build/'events.csv').open(newline='') as stream:
    rows = list(csv.DictReader(stream))
if len(rows) != 18:
    raise SystemExit(f'Expected 18 captures, got {len(rows)}')
for row in rows:
    name = row['name']
    with Image.open(build/f'{name}.ppm') as source:
        if source.size != (640, 480) or source.mode != 'RGB':
            raise SystemExit(f'Invalid capture format: {name}')
        source.save(dest/f'{name}.png', optimize=True)
    row['label'] = labels[name]
    row['file'] = f'{name}.png'
    for field in ('picture', 'sobel', 'view', 'score', 'active', 'window', 'hit', 'trained', 'game_cycles'):
        row[field] = int(row[field])
manifest = {
    'kind': 'RTL output captures', 'resolution': [640, 480],
    'audio_input': 'Synthetic FFT magnitude frames; four one-bin templates, not recorded vowels',
    'timing': 'Game BEAT_CLKS=2000; game clock paused for frame capture; not real-time playback',
    'video_boundary': 'Actual video_source Avalon-ST RGB output; ready held high; no physical VGA sink/PLL model',
    'assertions': ['wrong class does not score', 'correct class scores once',
                   'duplicate input does not score again', 'miss does not score',
                   'all frames have 307200 known pixels and correct packet markers'],
    'frames': rows,
}
(dest/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
shutil.copy2(build/'events.csv', dest/'events.csv')
shutil.copy2(ROOT/'build/demo_visual.log', ROOT/'docs/evidence/demo_visual.log')
frames = [Image.open(dest/f'{row["name"]}.png').convert('RGB') for row in rows[:10]]
frames[0].save(dest/'game_steps.gif', save_all=True, append_images=frames[1:],
               duration=1100, optimize=False, disposal=2)
for frame in frames:
    frame.close()
print(f'PASS: rendered {len(rows)} actual RTL frames, game_steps.gif, manifest and event trace.')
