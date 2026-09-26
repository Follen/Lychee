"""Generate client TOCs from one ordered manifest; --check detects drift."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon/Lychee"


def validate(manifest):
    products = set(manifest['clients'])
    for product, client in manifest['clients'].items():
        if not client['minInterface'] <= client['supportedMinInterface'] <= client['interface'] <= client['supportedMaxInterface'] <= client['maxInterface']:
            raise ValueError('Invalid client interface range: ' + product)
        for other, row in manifest['clients'].items():
            if other != product and row['minInterface'] <= client['maxInterface'] and client['minInterface'] <= row['maxInterface']:
                raise ValueError('Overlapping client identity ranges')
    ids, modules, owned = set(), set(), set()
    for spec in manifest['providers']:
        if set(spec) - {'ranges'} != {'id', 'module', 'products', 'files', 'requires', 'locales'}:
            raise ValueError('Unknown or missing Provider declaration fields')
        if spec['id'] in ids or spec['module'] in modules:
            raise ValueError('Duplicate Provider identity')
        ids.add(spec['id']); modules.add(spec['module'])
        if not spec['products'] or len(set(spec['products'])) != len(spec['products']) or not set(spec['products']) <= products:
            raise ValueError('Invalid Provider products: ' + spec['id'])
        rows = provider_ranges(manifest, spec)
        if not isinstance(rows, list) or not rows or len(rows) > 8:
            raise ValueError('Provider ranges must cover its declared products')
        for at, row in enumerate(rows):
            if not isinstance(row, dict) or set(row) != {'product', 'minInterface', 'maxInterface', 'minBuild', 'maxBuild'}:
                raise ValueError('Invalid Provider range fields')
            if not isinstance(row['product'], str) or row['product'] not in spec['products']:
                raise ValueError('Invalid Provider range product')
            for suffix in ('Interface', 'Build'):
                low, high = row['min' + suffix], row['max' + suffix]
                if type(low) is not int or type(high) is not int or not 1 <= low <= high <= 9999999:
                    raise ValueError('Invalid Provider range bounds')
            client = manifest['clients'][row['product']]
            if row['minInterface'] < client['minInterface'] or row['maxInterface'] > client['maxInterface']:
                raise ValueError('Provider range crosses client identity')
            for old in rows[:at]:
                if old['product'] == row['product'] and all(old['min'+s] <= row['max'+s] and row['min'+s] <= old['max'+s] for s in ('Interface', 'Build')):
                    raise ValueError('Overlapping Provider ranges')
        if {row['product'] for row in rows} != set(spec['products']):
            raise ValueError('Provider ranges must cover its declared products')
        expected_locales = [f"Providers/{spec['module']}/Locales/{locale}.lua" for locale in ('enUS', 'zhCN')]
        if spec['locales'] != expected_locales:
            raise ValueError('Provider needs ordered enUS/zhCN locale files: ' + spec['id'])
        for path in [*spec['locales'], *spec['files']]:
            if Path(path).is_absolute() or '..' in Path(path).parts or '\\' in path:
                raise ValueError('Unsafe Provider path: ' + path)
            if path in owned:
                raise ValueError('File owned by multiple Providers: ' + path)
            owned.add(path)
        for symbol in spec.get('requires', []):
            if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)*', symbol):
                raise ValueError('Invalid capability: ' + symbol)
    references = [item['provider'] for item in manifest['files'] if 'provider' in item]
    if len(references) != len(ids) or set(references) != ids:
        raise ValueError('Every Provider needs exactly one load position')
    for item in manifest['files']:
        if item.get('providerLocales'):
            if item != {'providerLocales': True}:
                raise ValueError('Invalid locale load position')
            continue
        if 'path' in item and set(item) != {'path', 'products'}:
            raise ValueError('Unknown shared file fields')
        if 'provider' in item and set(item) != {'provider'}:
            raise ValueError('Provider load positions must not repeat products/files')
        if 'path' in item and item['path'] in owned:
            raise ValueError('Provider file repeated as shared: ' + item['path'])
        if 'path' in item and (not item['products'] or not set(item['products']) <= products):
            raise ValueError('Invalid shared products')
    if sum(item.get('providerLocales', False) for item in manifest['files']) != 1:
        raise ValueError('Provider locales need exactly one load position')


def provider_ranges(manifest, spec):
    return spec.get('ranges', [dict(product=product,
        minInterface=manifest['clients'][product]['supportedMinInterface'],
        maxInterface=manifest['clients'][product]['supportedMaxInterface'], minBuild=1, maxBuild=9999999)
        for product in spec['products']])


def lua_range(row):
    return '{product=%s,minInterface=%d,maxInterface=%d,minBuild=%d,maxBuild=%d}' % (
        json.dumps(row['product']), row['minInterface'], row['maxInterface'], row['minBuild'], row['maxBuild'])


def runtime_profiles(manifest):
    lines = ['-- Generated by tools/build_client_tocs.py; edit tools/client_manifest.json.',
        '_G.LycheeInternal = _G.LycheeInternal or {}', 'local I = _G.LycheeInternal', 'I.ClientProfiles = {']
    for product, client in manifest['clients'].items():
        lines.append('    [%s]={minInterface=%d,maxInterface=%d},' % (json.dumps(product), client['minInterface'], client['maxInterface']))
    return '\n'.join(lines + ['}']) + '\n'


def runtime_definitions(manifest):
    lines = ['-- Generated by tools/build_client_tocs.py; edit tools/client_manifest.json.',
             'local I = _G.LycheeInternal', 'I.ProviderModules = I.ProviderModules or {}',
             'I.ProviderModules.Definitions = {']
    def strings(values):
        return '{' + ','.join(json.dumps(value) for value in values) + '}'
    for spec in manifest['providers']:
        lines.append('    {id=%s,module=%s,scope={products=%s},ranges={%s},requires=%s},' % (
            json.dumps(spec['id']), json.dumps(spec['module']), strings(spec['products']),
            ','.join(lua_range(row) for row in provider_ranges(manifest, spec)), strings(spec.get('requires', []))))
    lines.append('}')
    return '\n'.join(lines) + '\n'


def file_list(manifest, product):
    providers = {spec['id']: spec for spec in manifest['providers']}
    paths = []
    for item in manifest['files']:
        if item.get('providerLocales'):
            paths.extend(path for spec in manifest['providers'] if product in spec['products'] for path in spec['locales'])
            continue
        spec = providers[item['provider']] if 'provider' in item else item
        if product in spec['products']:
            paths.extend(spec['files'] if 'provider' in item else [spec['path']])
    if len(set(paths)) != len(paths):
        raise ValueError('Duplicate loaded file: ' + product)
    return paths


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
        r'## IconTexture: Interface\AddOns\Lychee\Media\lychee-logo.tga',
        f'## Version: {manifest["version"]}',
        '## SavedVariables: LycheeDB',
        '## SavedVariablesPerCharacter: LycheeCharacterDB',
        '## Bindings: Bindings.xml',
        '',
    ]
    for path in file_list(manifest, product):
        if not (ADDON / path).is_file():
            raise SystemExit(f'Missing file: {path}')
        lines.append(path)
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'tools/client_manifest.json').read_text())
    validate(manifest)
    profiles = ADDON / 'Core/ClientProfiles.lua'
    if args.check:
        if not profiles.is_file() or profiles.read_text(encoding='utf-8') != runtime_profiles(manifest):
            raise SystemExit('Client profiles drift')
    else:
        profiles.write_text(runtime_profiles(manifest), encoding='utf-8')
    definitions = ADDON / 'Providers/Definitions.lua'
    generated = runtime_definitions(manifest)
    if args.check:
        if not definitions.is_file() or definitions.read_text(encoding='utf-8') != generated:
            raise SystemExit('Provider definitions drift')
    else:
        definitions.write_text(generated, encoding='utf-8')
    for product, client in manifest['clients'].items():
        text = render(manifest, product)
        names = [f'Lychee_{client["suffix"]}.toc']
        if product == 'forever':
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
    print('Client TOCs PASS: ' + ', '.join(manifest['clients']) + '; flat TOC = Forever, retail = Mainline')


if __name__ == '__main__':
    main()
