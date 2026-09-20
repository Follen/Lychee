"""Build the original four-state checkbox vector atlas; never runs in game."""
from pathlib import Path
import io
import cairosvg
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
source = ROOT / "assets/ui/choice-checkbox.svg"
png = cairosvg.svg2png(url=str(source), output_width=1024, output_height=256)
atlas = Image.open(io.BytesIO(png)).convert("RGBA").resize((256,64), Image.Resampling.LANCZOS)
atlas.save(ROOT / "addon/Lychee/Media/choice-checkbox.tga")
atlas.save(ROOT / "assets/ui/choice-checkbox.png")
print("Choice checkbox: 256x64 RGBA; four shared 64x64 states")
