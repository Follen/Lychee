"""Build WoW menu textures from vendored IconPark SVGs (no network needed).

Requires CairoSVG 2.8.2 and Pillow 12.1.1. selection.json identifies existing
SVG elements to recolor; original geometry is unchanged. Only TGA and license ship.
"""
from __future__ import annotations
import hashlib
import html
import io
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path
import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets/menu-icons"
OUT = ROOT / "addon/Lychee/Media/MenuIcons"
DOCS = ROOT / "docs/architecture"
SIZE, SCALE, SAFE_INSET = 64, 4, 5
WHITE, RED, BACKGROUND = "#efeee8", "#d53c49", "#101012"
SVG_NS = "http://www.w3.org/2000/svg"
SHAPES = {"path", "circle", "rect", "ellipse", "line", "polyline", "polygon"}
ET.register_namespace("", SVG_NS)

def colored_svg(icon):
    source = ASSETS / "upstream" / (icon["source"] + ".svg")
    tree = ET.fromstring(source.read_text(encoding="utf-8"))
    shapes = [node for node in tree.iter() if node.tag.rsplit("}", 1)[-1] in SHAPES]
    assert all(-len(shapes) <= index < len(shapes) for index in icon["accent"])
    accents = {index % len(shapes) for index in icon["accent"]}
    for index, node in enumerate(shapes):
        color = RED if index in accents else WHITE
        for attribute in ("stroke", "fill"):
            if node.get(attribute) == "#000000":
                node.set(attribute, color)
    result = ET.tostring(tree, encoding="unicode")
    assert RED in result and WHITE in result, icon["id"]
    return result, source

def main():
    selection = json.loads((ASSETS / "selection.json").read_text(encoding="utf-8"))
    items = selection["icons"]
    provider = (ROOT / "addon/Lychee/Builtin/GameMenus/Provider.lua").read_text(encoding="utf-8")
    menu_ids = set(re.findall(r'^\s*\{"([^"\n]+)",', provider, re.MULTILINE))
    assert len(items) == len(menu_ids) == 34
    assert {icon["id"] for icon in items} == menu_ids
    OUT.mkdir(parents=True, exist_ok=True)
    columns, cell_width, cell_height, top = 4, 226, 106, 86
    sheet = Image.new("RGB", (columns * cell_width, top + math.ceil(len(items)/columns)*cell_height), BACKGROUND)
    drawing = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
    title_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 21)
    drawing.text((24, 17), "荔枝 · 菜单图标", font=title_font, fill=WHITE)
    drawing.text((24, 52), "IconPark  /  每组依次为 32px、34px 与 48px  /  保留红色点缀", font=font, fill="#99959a")
    svg_sheet = [f'<svg xmlns="{SVG_NS}" width="{sheet.width}" height="{sheet.height}" viewBox="0 0 {sheet.width} {sheet.height}">',
                 f'<rect width="100%" height="100%" fill="{BACKGROUND}"/>']
    manifest = []
    for index, icon in enumerate(items):
        svg, source = colored_svg(icon)
        glyph = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=(SIZE-2*SAFE_INSET)*SCALE,
                                                      output_height=(SIZE-2*SAFE_INSET)*SCALE))).convert("RGBA")
        glyph = glyph.resize((SIZE-2*SAFE_INSET, SIZE-2*SAFE_INSET), Image.Resampling.LANCZOS)
        raster = Image.new("RGBA", (SIZE, SIZE))
        raster.paste(glyph, (SAFE_INSET, SAFE_INSET))
        bbox = raster.getbbox()
        assert bbox and min(bbox[:2]) >= SAFE_INSET and max(bbox[2:]) <= SIZE-SAFE_INSET
        path = OUT / (icon["id"] + ".tga")
        raster.save(path, format="TGA", compression=None)
        with Image.open(path) as saved:
            assert saved.mode == "RGBA" and saved.size == (SIZE, SIZE)
        assert path.read_bytes()[2] == 2 and path.read_bytes()[16] == 32
        x, y = (index % columns)*cell_width, top + (index // columns)*cell_height
        inner = re.sub(r'^<svg[^>]*>|</svg>$', '', svg)
        for offset, size in ((26, 32), (85, 34), (148, 48)):
            preview = raster.resize((size, size), Image.Resampling.LANCZOS, box=(SIZE*.07, SIZE*.07, SIZE*.93, SIZE*.93))
            sheet.paste(preview, (x+offset, y+12+(48-size)//2), preview)
            # Same transparent padding and Host UV crop as the runtime texture.
            svg_sheet.append(f'<svg x="{x+offset}" y="{y+12+(48-size)//2}" width="{size}" height="{size}" viewBox="-.462222 -.462222 48.924444 48.924444">{inner}</svg>')
        drawing.text((x+cell_width/2, y+73), icon["label"], font=font, fill=WHITE, anchor="mt")
        svg_sheet.append(f'<text x="{x+cell_width/2}" y="{y+87}" text-anchor="middle" font-family="Microsoft YaHei,sans-serif" font-size="13" fill="{WHITE}">{html.escape(icon["label"])}</text>')
        manifest.append({**icon, "sourcePath": source.relative_to(ROOT).as_posix(),
                         "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                         "path": path.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    sheet.save(DOCS / "2026-09-10-menu-icons.png")
    (DOCS / "2026-09-10-menu-icons.svg").write_text("\n".join(svg_sheet + ["</svg>"]) + "\n", encoding="utf-8")
    (DOCS / "2026-09-10-menu-icons.json").write_text(json.dumps({
        "generator": "tools/build_menu_icons.py", "upstream": {k:v for k,v in selection.items() if k != "icons"},
        "size": SIZE, "safeInsetPx": SAFE_INSET, "hostCropUV": [.07, .93, .07, .93],
        "format": "RGBA TGA", "style": "IconPark outline, 3/48 stroke, ivory with selected Lychee red strokes",
        "icons": manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    notice = (f"Menu icons derived from IconPark by ByteDance ({selection['package']} {selection['version']}).\n"
              f"Source: {selection['repository']}\n"
              "Modified by Lychee: ivory/red recoloring, transparent padding, rasterization to 64x64 TGA.\n"
              "Original SVG geometry is unchanged. Licensed under Apache License 2.0, reproduced below.\n\n")
    (OUT / "LICENSE.txt").write_text(notice + (ASSETS / "LICENSE.txt").read_text(encoding="utf-8"), encoding="utf-8")
    print(f"Built and checked {len(items)} IconPark textures; preview: docs/architecture/2026-09-10-menu-icons.png")

if __name__ == "__main__":
    main()
