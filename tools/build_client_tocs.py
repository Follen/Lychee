"""Generate client TOCs from one ordered manifest; --check detects drift."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "package/Lychee"


def render(manifest, product):
    client = manifest["clients"][product]
    lines = [
        f'## Interface: {client["interface"]}',
        '## Title: |cffd53c49Lychee|r Launcher',
        '## Title-zhCN: |cffd53c49荔枝|r启动器',
        '## Title-zhTW: |cffd53c49荔枝|r启动器',
        '## Notes: Universal launcher for World of Warcraft',
        '## Notes-zhCN: 魔兽世界万用启动器',
        '## Notes-zhTW: 魔兽世界万用启动器',
        '## Author: Lychee',
        f'## Version: {manifest["version"]}',
        '## SavedVariables: LycheeDB',
        '## Bindings: Bindings.xml',
        '',
    ]
    for item in manifest["files"]:
        if product in item["products"]:
            if not (ADDON / item["path"]).is_file():
                raise SystemExit(f'Missing file: {item["path"]}')
            lines.append(item["path"])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'tools/client_manifest.json').read_text())
    for product, client in manifest['clients'].items():
        text = render(manifest, product)
        names = [f'Lychee_{client["suffix"]}.toc']
        if product == 'retail':
            names.append('Lychee.toc')
        for name in names:
            target = ADDON / name
            if args.check:
                if not target.is_file() or target.read_text(encoding='utf-8') != text:
                    raise SystemExit(f'TOC drift: {name}')
            else:
                target.write_text(text, encoding='utf-8')
        fixture = ROOT / 'lychee-sdk/examples/ThirdPartyFixture'
        template = (fixture / 'ThirdPartyFixture.toc').read_text(encoding='utf-8')
        example = re.sub(r'^## Interface:.*$', f'## Interface: {client["interface"]}', template, flags=re.M)
        target = fixture / f'ThirdPartyFixture_{client["suffix"]}.toc'
        if args.check:
            if not target.is_file() or target.read_text(encoding='utf-8') != example:
                raise SystemExit(f'Example TOC drift: {target.name}')
        else:
            target.write_text(example, encoding='utf-8')
    print('Client TOCs PASS: retail, classic, titan, anniversary + retail fallback')


if __name__ == '__main__':
    main()
