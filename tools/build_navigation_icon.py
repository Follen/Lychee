"""Export the editable, monochrome return icon to a 64px RGBA game texture."""
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def main():
    svg = ET.parse(ROOT / "assets/back-search.svg").getroot()
    factor = 4
    image = Image.new("RGBA", (64 * factor, 64 * factor))
    draw = ImageDraw.Draw(image)
    width = round(float(svg.attrib["stroke-width"]) * factor)
    for shape in svg:
        if shape.tag.endswith("circle"):
            x, y, r = (float(shape.attrib[k]) * factor for k in ("cx", "cy", "r"))
            # ImageDraw strokes inward; center it on the SVG circle path.
            draw.ellipse((x-r-width/2, y-r-width/2, x+r+width/2, y+r+width/2), outline="white", width=width)
        else:
            points = [tuple(float(v)*factor for v in pair.split(",")) for pair in shape.attrib["points"].split()]
            draw.line(points, fill="white", width=width, joint="curve")
            for x, y in points:
                draw.ellipse((x-width/2,y-width/2,x+width/2,y+width/2), fill="white")
    image = image.resize((64,64), Image.Resampling.LANCZOS)
    image.save(ROOT / "addon/Lychee/Media/back-search.tga", compression=None)


if __name__ == "__main__":
    main()
