from pathlib import Path
import io
import json
import hashlib
import cairosvg
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent.parent
source = root / 'assets/provider-icons/addon-inspector.svg'
target = root / 'addon/Lychee/Media/MenuIcons/addon-inspector.tga'
data = cairosvg.svg2png(url=str(source), output_width=256, output_height=256)
icon = Image.open(io.BytesIO(data)).convert('RGBA').resize((64,64), Image.Resampling.LANCZOS)
icon.save(target)
preview = Image.new('RGB', (440,190), '#0e0e10')
draw = ImageDraw.Draw(preview)
for row,name in enumerate(('settings','addon-inspector','achievements')):
    image = Image.open(target.parent / (name+'.tga')).convert('RGBA')
    draw.text((12, row*62+20), name, fill='#efeee8')
    for x,size in ((190,28),(258,34),(330,48)):
        tile=image.resize((size,size),Image.Resampling.LANCZOS)
        preview.paste(tile,(x,row*62+(54-size)//2),tile)
(root / 'assets/provider-icons/previews').mkdir(parents=True, exist_ok=True)
preview.save(root / 'assets/provider-icons/previews/2026-09-10-addon-inspector-icons.png')
(root / 'assets/provider-icons/previews/2026-09-10-addon-inspector-icon.json').write_text(json.dumps({'source':str(source.relative_to(root)), 'size':[64,64], 'mode':icon.mode, 'sha256':hashlib.sha256(target.read_bytes()).hexdigest()},indent=2)+'\n')
print('Exported editable vector to 64x64 RGBA TGA and 28/34/48 px comparison.')
