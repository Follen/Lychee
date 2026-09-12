"""Independent fixture checks for creature data, game-derived ordering and scope."""
import json
from pathlib import Path
from importlib.util import spec_from_file_location,module_from_spec
ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'assets/data/enemies.json').read_text(encoding='utf-8'))
assert 'spellNames' not in d
assert len(d['dungeons'])==16
enemies=[e for dungeon in d['dungeons'] for e in dungeon['enemies']]
assert len(enemies)==462
assert len({s['id'] for e in enemies for s in e['spells']})==1539
for e in enemies:
    assert e['displayId']>0 and 'clones' not in e
    assert all(set(s)<=set(('id','interruptible','magic','curse','poison','disease','enrage','bleed')) for s in e['spells'])
altar=next(x for x in d['dungeons'] if x['id']==164)
boss=next(e for e in altar['enemies'] if e['id']==259446)
assert boss['nameZh']=='扭缠盘蛇' and boss['bossOrder']==2 and boss['journalID']==2879
assert boss['displayId']==144156 and 1287798 in [s['id'] for s in boss['spells']]
for product in ('Classic','Titan','Anniversary'):
    toc=ROOT/f'addon/Lychee/Lychee_{product}.toc'
    if not toc.exists():
        manifest=json.loads((ROOT/'tools/client_manifest.json').read_text())
        continue
    assert 'Builtin/LDT/' not in toc.read_text()
manifest=json.loads((ROOT/'tools/client_manifest.json').read_text())
provider=next(x for x in manifest['providers'] if x['id']=='builtin.ldt')
assert provider['products']==['retail'] and provider['module']=='LDT'
for toc in (ROOT/'addon/Lychee').glob('Lychee*.toc'):
    text=toc.read_text(encoding='utf-8-sig')
    if toc.name not in ('Lychee.toc','Lychee_Mainline.toc'): assert 'Builtin/LDT/' not in text
    assert 'Builtin/MDT/' not in text
spec=spec_from_file_location('generator',ROOT/'tools/build_enemy_catalog.py');g=module_from_spec(spec);spec.loader.exec_module(g)
assert g.lua({'Shackle Undead':True})=='{["Shackle Undead"]=true}'
bad=json.loads(json.dumps(d));bad['dungeons'][0]['enemies'][0]['displayId']=0
try:g.render(bad)
except AssertionError:pass
else:raise AssertionError('generator accepted invalid display ID')
print('LDT data PASS: 16 dungeons, 462 creatures, 1539 spell IDs, retail only')
