"""Build Lychee's semantic menu glyphs from deterministic vector primitives.

Runtime receives transparent, uncompressed 64px TGA files only. The SVG sheet
is the editable vector reference; the PNG sheet previews the glyphs on dark UI.
Requires Pillow for build-time rasterization. No fonts or drawing code ship.
"""
from __future__ import annotations

import hashlib
import html
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "package/Lychee/Media/MenuIcons"
DOCS = ROOT / "docs/architecture"
SIZE, SCALE = 64, 4
SAFE_INSET = 5  # Host crops every icon to UV 0.07..0.93.
WHITE, RED = "#efeee8", "#d53c49"
STROKE = 1.65


class Icon:
    def __init__(self):
        self.image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
        self.draw = ImageDraw.Draw(self.image)
        self.svg: list[str] = []
        self.scale = SIZE * SCALE / 24

    def xy(self, value):
        return tuple(v * self.scale for v in value)

    def path(self, data, color=WHITE, fill=None, width=STROKE):
        self.svg.append(f'<path d="{data}" stroke="{color}" stroke-width="{width}" fill="{fill or "none"}" stroke-linecap="round" stroke-linejoin="round"/>')
        tokens = re.findall(r"[MLCQZ]|-?\d+(?:\.\d+)?", data)
        index, points, cursor, start = 0, [], (0, 0), (0, 0)

        def flush():
            if not points:
                return
            pixels = [self.xy(p) for p in points]
            if fill:
                self.draw.polygon(pixels, fill=fill)
            self.draw.line(pixels, fill=color, width=round(width * self.scale), joint="curve")
            radius = width * self.scale / 2
            for x, y in (pixels[0], pixels[-1]):
                self.draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)

        while index < len(tokens):
            command = tokens[index]
            index += 1
            count = {"M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0}[command]
            values = [float(v) for v in tokens[index:index+count]]
            index += count
            if command == "M":
                flush()
                cursor = start = tuple(values)
                points = [cursor]
            elif command == "L":
                cursor = tuple(values)
                points.append(cursor)
            elif command == "Z":
                points.append(start)
                cursor = start
            else:
                origin = cursor
                for step in range(1, 25):
                    t, u = step / 24, 1 - step / 24
                    if command == "Q":
                        point = tuple(u*u*origin[a] + 2*u*t*values[a] + t*t*values[a+2] for a in range(2))
                    else:
                        point = tuple(u*u*u*origin[a] + 3*u*u*t*values[a] + 3*u*t*t*values[a+2] + t*t*t*values[a+4] for a in range(2))
                    points.append(point)
                cursor = points[-1]
        flush()

    def circle(self, x, y, radius, color=WHITE, fill=None, width=STROKE):
        self.svg.append(f'<circle cx="{x}" cy="{y}" r="{radius}" stroke="{color}" stroke-width="{width}" fill="{fill or "none"}"/>')
        self.draw.ellipse(self.xy((x-radius, y-radius, x+radius, y+radius)), fill=fill, outline=color, width=round(width*self.scale))

    def rect(self, x, y, w, h, radius=1.4, color=WHITE, fill=None):
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" stroke="{color}" stroke-width="{STROKE}" fill="{fill or "none"}"/>')
        self.draw.rounded_rectangle(self.xy((x, y, x+w, y+h)), radius=radius*self.scale, fill=fill, outline=color, width=round(STROKE*self.scale))

    def line(self, *points, color=WHITE, width=STROKE):
        self.path("M " + " L ".join(f"{x} {y}" for x, y in points), color, width=width)

    def star(self, x, y, radius=4, color=RED):
        points=[]
        for n in range(8):
            angle = math.pi*n/4 - math.pi/2
            length = radius if n % 2 == 0 else radius*.32
            points.append((round(x+math.cos(angle)*length,3), round(y+math.sin(angle)*length,3)))
        self.path("M " + " L ".join(f"{px} {py}" for px,py in points) + " Z", color)

    def person(self, x, y, small=False, color=WHITE):
        r = 1.6 if small else 2.2
        self.circle(x, y, r, color)
        self.path(f"M {x-r-1} {y+7} L {x-r-1} {y+5.5} Q {x} {y+2} {x+r+1} {y+5.5} L {x+r+1} {y+7}", color)

    def book(self, bookmark=False):
        self.path("M 12 6 Q 7 3 3 5 L 3 19 Q 7 17 12 20 Q 17 17 21 19 L 21 5 Q 17 3 12 6 L 12 20")
        if bookmark:
            self.line((16,5),(16,11),(18,9),(20,11),(20,5), color=RED)

    def door(self):
        self.path("M 5 21 L 5 10 C 5 1 19 1 19 10 L 19 21 M 3 21 L 21 21")
        self.path("M 9 20 L 9 11 Q 12 7 15 11 L 15 20", RED)

    def skull(self, center=12, top=3):
        x,y=center,top
        self.path(f"M {x-3} {y+12} L {x-3} {y+9} C {x-10} {y+5} {x-5} {y} {x} {y} C {x+5} {y} {x+10} {y+5} {x+3} {y+9} L {x+3} {y+12} Z")
        self.circle(x-2.5,y+5.5,.8,RED,RED)
        self.circle(x+2.5,y+5.5,.8,RED,RED)
        self.line((x,y+10),(x,y+12))

    def magnifier(self, x=17, y=17):
        self.circle(x,y,3.2,RED)
        self.line((x+2.4,y+2.4),(22,22), color=RED)


def draw_icon(key):
    i=Icon()
    if key == "character":
        i.path("M 8 3 L 4 6 L 5 11 L 7 11 L 6 21 L 18 21 L 17 11 L 19 11 L 20 6 L 16 3")
        i.path("M 8 3 Q 12 9 16 3 M 8 13 L 16 13", RED)
    elif key == "reputation":
        i.circle(12,9,6)
        i.path("M 8 14 L 6 22 L 11 19 M 16 14 L 18 22 L 13 19")
        i.star(12,9,3,RED)
    elif key == "currency":
        i.circle(14.5,9.5,6,RED)
        i.line((14.5,6.5),(14.5,12.5), color=RED)
        i.path("M 4 10 Q 1 12 4 14 Q 8 17 12 14 M 3 13 L 3 18 Q 8 22 13 18 L 13 16 M 3 16 Q 7 19 10 17")
    elif key == "talents":
        i.line((12,7),(12,12),(5,12),(5,16))
        i.line((12,12),(19,12),(19,16))
        i.circle(12,4.5,2.5,RED)
        i.circle(5,19,2.5); i.circle(19,19,2.5)
    elif key == "specialization":
        i.path("M 12 21 L 12 15 C 12 9 5 10 5 4 M 2 7 L 5 4 L 8 7")
        i.path("M 12 15 C 12 9 19 10 19 4 M 16 7 L 19 4 L 22 7", RED)
    elif key == "spellbook":
        i.book(True)
    elif key == "professions":
        i.path("M 3 4 L 7 3 L 12 8 L 9 11 L 4 6 Z M 10 10 L 20 20 L 18 22 L 8 12")
        i.path("M 14 8 L 15 3 L 17 7 L 21 5 L 20 10 L 16 12 M 10 15 L 4 21 L 2 19 L 8 13",RED)
    elif key == "mounts":
        i.path("M 6 21 C 6 16 10 16 11 12 L 6 13 L 3 10 L 8 5 L 10 2 L 12 5 C 20 4 22 13 19 21 Z")
        i.path("M 13 6 C 17 10 18 15 15 20",RED)
        i.circle(9.5,8,0.6,WHITE,WHITE)
    elif key == "pets":
        for x,y in ((5,9),(9,5),(15,5),(19,9)): i.circle(x,y,2)
        i.path("M 6 18 C 6 15 9 12 12 12 C 15 12 18 15 18 18 C 18 23 14 19 12 20 C 10 19 6 23 6 18 Z",RED)
    elif key == "toys":
        i.rect(3,10,11,8); i.rect(14,5,6,13)
        i.line((2,18),(22,18))
        i.circle(6,20,2,RED); i.circle(18,20,2,RED)
        i.line((6,10),(6,6),(10,6),(10,10),color=RED)
        i.line((17,8),(17,11))
    elif key == "heirlooms":
        i.path("M 4 3 C 4 10 8 12 12 12 C 16 12 20 10 20 3")
        i.path("M 12 11 L 17 16 L 12 22 L 7 16 Z",RED)
        i.line((12,14),(12,19),color=RED)
    elif key == "appearances":
        i.path("M 9 6 Q 9 1 13 3 Q 17 6 12 9 L 12 11 M 12 11 L 3 17 Q 1 20 5 20 L 19 20 Q 23 20 21 17 Z")
        i.line((8,17),(16,17),color=RED)
    elif key == "warband-scenes":
        i.path("M 3 20 L 12 4 L 21 20 Z M 8 20 L 12 12 L 16 20",WHITE)
        i.line((10,3),(14,3),color=RED)
        i.path("M 20 9 Q 17 8 20 5 Q 24 8 20 9 Z",RED)
    elif key == "achievements":
        i.path("M 7 3 L 17 3 L 16 11 Q 12 17 8 11 Z M 12 14 L 12 20 M 8 21 L 16 21 M 7 5 L 3 5 Q 2 11 8 11 M 17 5 L 21 5 Q 22 11 16 11")
        i.star(12,8,2.4,RED)
    elif key == "quests":
        i.path("M 6 3 L 19 3 Q 22 3 21 7 L 17 7 M 6 3 Q 9 3 8 7 L 8 18 Q 8 23 4 21 L 3 18 L 15 18 Q 17 18 17 21 L 17 6 Q 17 3 19 3")
        i.line((12,8),(12,12),color=RED); i.circle(12,15,.7,RED,RED)
    elif key == "map":
        i.path("M 3 5 L 9 3 L 15 5 L 21 3 L 21 19 L 15 21 L 9 19 L 3 21 Z M 9 3 L 9 19 M 15 5 L 15 21")
        i.path("M 6 15 L 11 10 L 17 13",RED); i.circle(18,12,1.5,RED)
    elif key == "friends":
        i.person(8,7); i.person(17,8,True)
        i.path("M 10 19 Q 12 16 14 19",RED)
    elif key == "guild":
        i.path("M 4 3 L 20 3 L 20 14 Q 19 19 12 22 Q 5 19 4 14 Z")
        i.path("M 8 7 L 16 7 L 16 14 L 12 12 L 8 14 Z",RED)
    elif key == "group-finder":
        i.person(6,6,True); i.person(14,6,True)
        i.magnifier()
    elif key == "dungeon-finder":
        i.path("M 4 19 L 4 9 C 4 0 17 0 17 9 L 17 12 M 8 19 L 8 10 Q 11 6 13 10")
        i.magnifier()
    elif key == "raid-finder":
        i.skull(10,2); i.magnifier(17,18)
    elif key == "premade-groups":
        i.person(6,6,True); i.person(14,6,True)
        i.line((18,14),(18,22),color=RED); i.line((14,18),(22,18),color=RED)
    elif key == "pvp":
        i.path("M 4 3 L 8 5 L 17 16 L 15 18 L 5 8 Z M 13 18 L 18 13 M 17 18 L 20 21")
        i.path("M 20 3 L 16 5 L 11 11 M 9 14 L 7 16 L 9 18 M 11 18 L 6 13 M 7 18 L 4 21",RED)
    elif key == "journal":
        i.rect(4,3,16,18)
        i.line((8,3),(8,21))
        i.star(14,11,4,RED)
        i.line((12,18),(17,18))
    elif key == "calendar":
        i.rect(3,5,18,17)
        i.line((3,10),(21,10)); i.line((7,2),(7,7)); i.line((17,2),(17,7))
        i.rect(7,14,3,3,.3,RED,RED)
        i.line((14,15),(17,15)); i.line((14,18),(17,18))
    elif key == "macros":
        i.path("M 7 6 L 2 12 L 7 18 M 17 6 L 22 12 L 17 18")
        i.line((14,4),(10,20),color=RED)
    elif key == "settings":
        points=[]
        for n in range(32):
            angle=math.pi*n/16
            radius=9 if n%4 in (1,2) else 7
            points.append((round(12+math.cos(angle)*radius,3),round(12+math.sin(angle)*radius,3)))
        i.path("M " + " L ".join(f"{x} {y}" for x,y in points) + " Z")
        i.circle(12,12,3,RED)
    elif key == "game-menu":
        for y in (6,12,18):
            i.circle(4,y,.8,RED,RED)
            i.line((9,y),(21,y))
    elif key == "journeys":
        i.path("M 4 21 L 10 21 C 17 21 17 15 12 15 L 9 15 C 3 15 3 9 9 9 L 14 9")
        i.path("M 15 12 L 15 2 L 22 5 L 15 8",RED)
    elif key == "travelers-log":
        i.rect(4,3,15,18)
        i.line((8,3),(8,21))
        i.path("M 11 10 L 13 12 L 17 7",RED)
        i.line((11,16),(16,16)); i.line((11,19),(14,19))
    elif key == "suggested-content":
        i.star(11,12,8,WHITE)
        i.star(20,4,2,RED)
        i.line((18,18),(21,21),color=RED)
    elif key == "journal-dungeons":
        i.door()
    elif key == "journal-raids":
        i.skull(12,3)
        i.line((5,18),(19,22),color=RED); i.line((5,22),(19,18),color=RED)
    elif key == "tutorials":
        i.path("M 2 8 L 12 3 L 22 8 L 12 13 Z M 6 11 L 6 17 Q 12 22 18 17 L 18 11")
        i.line((22,9),(22,17),color=RED); i.circle(22,19,1,RED,RED)
    else:
        raise ValueError(key)
    return i


ITEMS = [
    ("character","角色"),("reputation","声望"),("currency","货币"),("talents","天赋"),
    ("specialization","专精"),("spellbook","法术书"),("professions","专业技能"),("mounts","坐骑"),
    ("pets","宠物手册"),("toys","玩具箱"),("heirlooms","传家宝"),("appearances","外观"),
    ("warband-scenes","战团营地"),("achievements","成就"),("quests","任务日志"),("map","世界地图"),
    ("friends","好友"),("guild","公会与社区"),("group-finder","地下城和团队"),("dungeon-finder","地下城查找器"),
    ("raid-finder","团队查找器"),("premade-groups","预创建队伍"),("pvp","PvP"),("journal","冒险指南"),
    ("calendar","日历"),("macros","宏命令"),("settings","设置"),("game-menu","游戏菜单"),
    ("journeys","旅程"),("travelers-log","旅行者日志"),("suggested-content","推荐玩法"),
    ("journal-dungeons","地下城"),("journal-raids","团队副本"),("tutorials","教程"),
]


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    columns, cell_width, cell_height = 6, 132, 104
    rows=math.ceil(len(ITEMS)/columns)
    sheet=Image.new("RGB",(columns*cell_width,rows*cell_height),"#101012")
    drawing=ImageDraw.Draw(sheet)
    font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",13)
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{sheet.width}" height="{sheet.height}" viewBox="0 0 {sheet.width} {sheet.height}">',
         '<rect width="100%" height="100%" fill="#101012"/>']
    manifest=[]
    for index,(key,label) in enumerate(ITEMS):
        icon=draw_icon(key)
        glyph=icon.image.resize((SIZE-2*SAFE_INSET,SIZE-2*SAFE_INSET),Image.Resampling.LANCZOS)
        raster=Image.new("RGBA",(SIZE,SIZE))
        raster.paste(glyph,(SAFE_INSET,SAFE_INSET))
        assert raster.getbbox() and raster.getpixel((0,0))[3] == 0
        path=OUT/f"{key}.tga"
        raster.save(path,format="TGA",compression=None)
        x,y=(index%columns)*cell_width,(index//columns)*cell_height
        preview=raster.resize((40,40),Image.Resampling.LANCZOS,box=(SIZE*.07,SIZE*.07,SIZE*.93,SIZE*.93))
        sheet.paste(preview,(x+(cell_width-40)//2,y+15),preview)
        drawing.text((x+cell_width/2,y+68),label,font=font,fill=WHITE,anchor="mt")
        svg.append(f'<g id="{key}" transform="translate({x+(cell_width-40)/2} {y+15}) scale({40/24})"><title>{html.escape(label)}</title>'+"".join(icon.svg)+"</g>")
        svg.append(f'<text x="{x+cell_width/2}" y="{y+82}" text-anchor="middle" font-family="Microsoft YaHei,sans-serif" font-size="13" fill="{WHITE}">{html.escape(label)}</text>')
        manifest.append({"id":key,"label":label,"path":str(path.relative_to(ROOT)).replace("\\","/"),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    svg.append("</svg>")
    sheet.save(DOCS/"2026-09-10-menu-icons.png")
    (DOCS/"2026-09-10-menu-icons.svg").write_text("\n".join(svg)+"\n",encoding="utf-8")
    (DOCS/"2026-09-10-menu-icons.json").write_text(json.dumps({"generator":"tests/build_menu_icons.py","size":SIZE,"safeInsetPx":SAFE_INSET,"hostCropUV":[.07,.93,.07,.93],"format":"RGBA TGA","style":"semantic vector glyphs, ivory and Lychee red, transparent","icons":manifest},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Generated {len(ITEMS)} transparent {SIZE}x{SIZE} TGA icons; preview: docs/architecture/2026-09-10-menu-icons.png")


if __name__ == "__main__":
    main()
