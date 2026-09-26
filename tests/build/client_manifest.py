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
    paths = build.file_list(manifest, product)
    assert len(paths) == len(set(paths))
    for provider in manifest['providers']:
        for path in [*provider['locales'], *provider['files']]:
            assert (path in paths) == (product in provider['products']), (product, path)
        if product in provider['products']:
            assert all(paths.index(path) < paths.index(provider['files'][0]) for path in provider['locales'])
    assert all((build.ADDON / path).is_file() for path in paths)

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
rejects(lambda m: m['files'].append({'provider': m['providers'][0]['id']}))
rejects(lambda m: m['files'].append({'providerLocales': True}))
rejects(lambda m: m['files'].append({'path': m['providers'][0]['locales'][0], 'products': ['retail']}))
rejects(lambda m: m['providers'][0]['locales'].pop())
rejects(lambda m: m['providers'][0]['locales'].reverse())
# A support change propagates to both packing and registration metadata.
candidate = copy.deepcopy(manifest)
provider = candidate['providers'][0]
provider['products'] = ['retail']
build.validate(candidate)
assert all(path not in build.file_list(candidate, 'classic') for path in provider['files'])
assert 'scope={products={"retail"}}' in build.runtime_definitions(candidate).splitlines()[4]
range_row = dict(product='retail', minInterface=120100, maxInterface=120199, minBuild=69900, maxBuild=69999)
def set_ranges(m, rows):
    m['providers'][0]['products'] = ['retail']
    m['providers'][0]['ranges'] = rows
for invalid in (None, {}, [], [None], [{}], [dict(range_row, product='forever')],
                [dict(range_row, product=[])], [dict(range_row, minBuild=True)],
                [dict(range_row, minBuild=70000)], [dict(range_row, minInterface=16001)],
                [range_row, range_row]):
    rejects(lambda m, rows=invalid: set_ranges(m, rows))
set_ranges(candidate, [range_row, dict(range_row, minBuild=70000, maxBuild=70099)])
build.validate(candidate)
assert 'minBuild=70000,maxBuild=70099' in build.runtime_definitions(candidate)
rejects(lambda m: m['clients']['forever'].update(minInterface=120000, maxInterface=120199,
    interface=120100, supportedMinInterface=120100, supportedMaxInterface=120199))
print('Client manifest PASS: 5 clients, declared owners, invalid rules rejected, support change propagated')
