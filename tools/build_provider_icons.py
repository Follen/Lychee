"""Export original vector icons to bounded runtime textures. No runtime drawing."""
from pathlib import Path
import io
import hashlib
import json
import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'addon/Lychee/Media/MenuIcons'
preview = Image.new('RGB', (480, 140), '#101012')
manifest = []
for index, name in enumerate(('reload', 'cooldown-manager', 'keystone')):
    source = ROOT / 'assets/provider-icons' / (name + '.svg')
    png = cairosvg.svg2png(url=str(source), output_width=256, output_height=256)
    image = Image.open(io.BytesIO(png)).convert('RGBA').resize((64, 64), Image.Resampling.LANCZOS)
    target = OUT / (name + '.tga')
    image.save(target)
    for offset, size in ((8, 28), (52, 34), (100, 48)):
        tile = image.resize((size, size), Image.Resampling.LANCZOS)
        preview.paste(tile, (index * 160 + offset, 24 + (48-size)//2), tile)
    ImageDraw.Draw(preview).text((index*160+8, 94), name, fill='#efeee8')
    manifest.append({'id': name, 'size': 64, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
(ROOT / 'assets/provider-icons/previews').mkdir(parents=True, exist_ok=True)
preview.save(ROOT / 'assets/provider-icons/previews/2026-09-10-provider-icons.png')
(ROOT / 'assets/provider-icons/previews/2026-09-10-provider-icons.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Exported 3 original 64x64 RGBA TGA icons; preview at 28/34/48 px.')
