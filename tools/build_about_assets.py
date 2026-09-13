"""Compile approved about/social artwork into deterministic WoW textures."""
from pathlib import Path
import hashlib
import io
import json
import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def build():
    source = ROOT / 'assets/about'
    target = ROOT / 'addon/Lychee/Media/About'
    target.mkdir(parents=True, exist_ok=True)
    records = []
    for name in ('github', 'paypal', 'x', 'wechat', 'support'):
        svg = source / 'icons' / (name + '.svg')
        png = cairosvg.svg2png(url=str(svg), output_width=64, output_height=64)
        image = Image.open(io.BytesIO(png)).convert('RGBA')
        # White artwork receives the shared theme color at runtime.
        white = Image.new('RGBA', image.size, (255, 255, 255, 0))
        white.putalpha(image.getchannel('A'))
        output = target / (name + '.tga')
        white.save(output, compression=None)
        records.append({'file': output.relative_to(ROOT).as_posix(), 'size': [64, 64],
                        'sha256': hashlib.sha256(output.read_bytes()).hexdigest()})
    for name in ('wechat-support', 'wechat-contact'):
        original = source / (name + '-v1.png')
        image = Image.open(original).convert('RGBA').resize((512, 512), Image.Resampling.LANCZOS)
        output = target / (name + '.tga')
        image.save(output, compression=None)
        records.append({'file': output.relative_to(ROOT).as_posix(), 'size': [512, 512],
                        'sourceSha256': hashlib.sha256(original.read_bytes()).hexdigest(),
                        'sha256': hashlib.sha256(output.read_bytes()).hexdigest()})
    (source / 'textures.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
    print(f'About assets: {len(records)} RGBA textures')

if __name__ == '__main__':
    build()
