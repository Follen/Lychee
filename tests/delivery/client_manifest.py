"""Build rules and real generated load paths must agree on every client."""
import copy
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
module_spec = importlib.util.spec_from_file_location('client_build', root / 'tools/build_client_tocs.py')
build = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(build)
manifest = json.loads((root / 'tools/client_manifest.json').read_text())
build.validate(manifest)
for product in manifest['clients']:
    for package in manifest['packages']:
        paths=build.file_list(manifest,product,package)
        assert len(paths)==len(set(paths))
        for provider in manifest['providers']:
            if provider['package']!=package: continue
            for path in [provider['locales'],*provider['files']]:
                assert (path in paths)==(product in provider['products']),(product,package,path)
            if product in provider['products']:
                assert paths.index(provider['locales'])<paths.index(provider['files'][0])
        assert all((build.ADDON/package/path).is_file() for path in paths)

def rejects(change):
    candidate = copy.deepcopy(manifest)
    change(candidate)
    try:
        build.validate(candidate)
    except ValueError:
        return
    raise AssertionError('Invalid manifest accepted')

rejects(lambda m: m['providers'].append(copy.deepcopy(m['providers'][0])))
rejects(lambda m: m['providers'][0]['products'].append('unknown'))
rejects(lambda m: m['providers'][0]['products'].append('retail'))
rejects(lambda m: m['providers'][0]['requires'].append('x();run()'))
rejects(lambda m: m['providers'][0]['files'].append('../escape.lua'))
rejects(lambda m: m['packages']['Lychee_Player']['files'].append({'provider': m['providers'][0]['id']}))
rejects(lambda m: m['packages']['Lychee_Player']['files'].append({'providerLocales': True}))
rejects(lambda m: m['packages']['Lychee_Player']['files'].append({'path': next(p for p in m['providers'] if p['package']=='Lychee_Player')['locales'], 'products': ['retail']}))
# A support change propagates to both packing and registration metadata.
candidate = copy.deepcopy(manifest)
provider = candidate['providers'][0]
provider['products'] = ['retail']
build.validate(candidate)
assert all(path not in build.file_list(candidate, 'classic',provider['package']) for path in provider['files'])
assert 'scope={products={"retail"}}' in build.runtime_definitions(candidate,provider['package'])
print('Client manifest PASS: 4 clients, 16 providers / 5 packages, invalid rules rejected, support change propagated')

rejects(lambda m: m['packages']['Lychee']['files'].append(dict(m['packages']['Lychee']['files'][0])))
rejects(lambda m: m['packages']['Lychee']['files'].append({'path':'Another.lua','unknown':True}))
