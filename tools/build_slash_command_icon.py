"""Export the slash command icon and actual-size acceptance preview."""
from pathlib import Path
from io import BytesIO
import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/provider-icons/slash-commands.svg'
image = Image.open(BytesIO(cairosvg.svg2png(url=str(source), output_width=256, output_height=256)))
image = image.convert('RGBA').resize((64, 64), Image.Resampling.LANCZOS)
image.save(ROOT / 'addon/Lychee/Media/MenuIcons/slash-commands.tga')
preview = Image.new('RGB', (180, 72), '#101012')
for x, size in ((12, 28), (62, 34), (116, 48)):
    tile = image.resize((size, size), Image.Resampling.LANCZOS)
    preview.paste(tile, (x, (72-size)//2), tile)
preview.save(ROOT / 'assets/provider-icons/previews/slash-commands.png')
print('Slash icon PASS: 64x64 RGBA, preview 28/34/48')
