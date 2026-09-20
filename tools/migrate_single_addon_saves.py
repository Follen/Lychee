"""Offline, non-executing SavedVariables migration; dry-run unless --write.

Usage: python tools/migrate_single_addon_saves.py --host CHARACTER/Lychee.lua
  [--business CHARACTER/Lychee_Player.lua] [--output NEW_DIRECTORY --write]
Never point output at the live SavedVariables directory. Output has a migrated
host file, byte-identical originals, and a SHA-256 report. Install separately
only after review, with WoW exited. Account and other characters are not inferred.

Proven reference contracts (donor f715f0a -> single-addon port):
PlayerSpells/Provider.lua BuildSearchRecords keeps spell:<ID>, cast/spellID.
Historical Audio/Provider.lua (retired in 0.2.2) defined set-volume v1, target v1 {channel}, integer percent.
Historical BlizzardSettings/Invocations.lua defined setting-/stage- actions v1
and target v1 {setting}. Retired actions remain unavailable at runtime; this
migration only preserves their references and never executes them.
All 16 bundled module identities are whitelisted for preferences; ordinary entry
patterns preserve their original IDs. Unknown actions/records are retained.
Business settings have no proved consuming migration in this port: preserve and
report them, never flatten SDK envelopes speculatively. Caches are not imported.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import tempfile

MAX_FILE = 32 * 1024 * 1024
SPACE = re.compile(r"\s+|--[^\r\n]*")
IDENT = re.compile(r"[A-Za-z_][A-Za-z_0-9]*")
NUMBER = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
# Provider ownership proved by corresponding Provider Definitions and donor
# modules. Preference mapping is independent of individual record recoverability.
PROVIDERS = {"lychee."+name: "builtin."+name for name in ('player-spells', 'blizzard-settings', 'mounts', 'achievements', 'bags', 'talent-loadouts', 'equipment-sets', 'bosses', 'ldt', 'keystones', 'game-menus', 'crests', 'great-vault', 'addon-inspector', 'ellesmere', 'exwind')}
# Both versions retain these ID builders and consume the same payload in their
# actions: summon(spellID), open(achievementID), use(itemID), activate(configID),
# equip(setID), journal(encounter/spell/difficulty), LDT(dungeon/npc/spell),
# teleport(member GUID), and menu key. Removed/unavailable data stays a runtime
# restoration failure, never a guessed replacement entry or executed action.
ENTRY_PATTERNS = {
    "player-spells": r"spell:[1-9]\d*", "mounts": r"mount:[1-9]\d*",
    "achievements": r"achievement:[1-9]\d*", "bags": r"item:[1-9]\d*",
    "talent-loadouts": r"talent:\d+", "equipment-sets": r"equipment:\d+",
    "bosses": r"boss-\d+(?:-difficulty-\d+|-spell-\d+-\d+)?",
    "ldt": r"\d+/\d+(?:/\d+)?", "keystones": r"key:Player-\d+-[0-9A-Fa-f]+",
    "crests": r"crests", "great-vault": r"great-vault", "addon-inspector": r"inspect",
}
MENU_IDS = {'spellbook', 'mounts', 'talents', 'specialization', 'professions', 'dungeon-finder', 'tutorials', 'game-menu', 'appearances', 'achievements', 'warband-scenes', 'map', 'friends', 'journal', 'reputation', 'premade-groups', 'settings', 'calendar', 'journal-raids', 'suggested-content', 'heirlooms', 'currency', 'group-finder', 'pvp', 'journal-dungeons', 'travelers-log', 'macros', 'toys', 'guild', 'quests', 'raid-finder', 'pets', 'character', 'journeys'}
ENCODED_SEGMENT = r"(?:[A-Za-z0-9_.]|-[0-9A-Fa-f]{2})+"
def ordinary_entry(owner, entry):
    if not isinstance(entry,str) or not entry or len(entry.encode('utf-8')) > 1024: return False
    suffix = owner.removeprefix('lychee.')
    if suffix in ENTRY_PATTERNS: return re.fullmatch(ENTRY_PATTERNS[suffix],entry) is not None
    if suffix == 'game-menus': return entry in MENU_IDS
    if suffix == 'blizzard-settings': return entry in ('reload','cdm')
    # Ellesmere uses reversible page segments / stable double-hash option keys;
    # Resolve rechecks captured option and page, and open uses that same owner.
    if suffix == 'ellesmere':
        return entry == 'unlock' or (len(entry)<=128 and
            (re.fullmatch('page/'+ENCODED_SEGMENT+'/'+ENCODED_SEGMENT,entry) is not None
             or re.fullmatch(r'option/\d+/\d+',entry) is not None))
    # Exwind Find enumerates current destinations and matches the full same ID.
    if suffix == 'exwind':
        return entry == 'unlock' or re.fullmatch('(?:app|tool)/'+ENCODED_SEGMENT+'|edit/'+ENCODED_SEGMENT+'/'+ENCODED_SEGMENT,entry) is not None
    return False
# Audited against donor f715f0a. Paths are relative to each package's module;
# the current counterpart is addon/Lychee/Providers/<module>/<file>.
REFERENCE_EVIDENCE = {
    'player-spells':'PlayerSpells/Provider.lua:252,266; spell ID -> secure cast',
    'mounts':'Mounts/Provider.lua:23-25; mount ID -> summon spell',
    'achievements':'Achievements/Provider.lua Record/resolve/open; achievement ID -> select/share',
    'bags':'Bags/Provider.lua:67-69; item ID -> use/locate current bag item',
    'talent-loadouts':'TalentLoadouts/Provider.lua:18-28; config ID -> activate current config',
    'equipment-sets':'EquipmentSets/Provider.lua:12-22; set ID -> UseEquipmentSet',
    'bosses':'Bosses/Provider.lua ResolveReference/detail; encounter/spell/difficulty -> journal section',
    'ldt':'LDT/Catalog.lua Record/Find/Resolve; dungeon/NPC/spell -> current creature detail',
    'keystones':'Keystones/Provider.lua:135-142; member GUID -> current key/teleport',
    'game-menus':'GameMenus/Provider.lua menus/opens; same explicit menu ID -> same open function',
    'crests':'Crests/Provider.lua:105-110; crests -> currency overview',
    'great-vault':'GreatVault/Provider.lua:14-20; great-vault -> weekly rewards',
    'addon-inspector':'AddonInspector/Provider.lua:320-327 (donor Lychee_Inspector/Provider.lua); inspect -> inspector',
    'ellesmere':'Ellesmere/Provider.lua pageID/optionID/Resolve/actions; same encoding/hash -> revalidated page',
    'exwind':'Exwind/Provider.lua destinations/Find/Resolve/actions; app/tool/edit IDs -> revalidated destination',
    'blizzard-settings':'Historical Audio/Provider.lua target/schema/actions; set-volume v1, channel v1, integer percent 0..100',
}
CHANNELS = {"master", "music", "sfx", "ambience", "dialog"}

class InvalidSave(ValueError):
    pass

class Parser:
    """Strict literal grammar, not Lua execution. Tables retain numeric keys."""
    def __init__(self, text):
        self.text, self.at, self.nodes = text, 0, 0
    def skip(self):
        while True:
            match = SPACE.match(self.text, self.at)
            if not match: return
            self.at += len(match[0])
    def take(self, token):
        self.skip()
        if self.text.startswith(token, self.at):
            self.at += len(token)
            return True
        return False
    def need(self, token):
        if not self.take(token): raise InvalidSave(f"expected {token!r} at {self.at}")
    def name(self):
        self.skip()
        match = IDENT.match(self.text, self.at)
        if not match: raise InvalidSave(f"expected name at {self.at}")
        self.at = match.end()
        return match[0]
    def string(self):
        quote = self.text[self.at]; self.at += 1
        result = bytearray()
        escapes = {'a':7, 'b':8, 'f':12, 'n':10, 'r':13, 't':9, 'v':11,
                   '\\':92, '"':34, "'":39}
        while self.at < len(self.text):
            char = self.text[self.at]; self.at += 1
            if char == quote:
                try: return result.decode('utf-8')
                except UnicodeDecodeError as error: raise InvalidSave('non-UTF8 string') from error
            if char in '\r\n': raise InvalidSave('literal newline in string')
            if char != '\\': result.extend(char.encode('utf-8')); continue
            if self.at == len(self.text): break
            char = self.text[self.at]; self.at += 1
            if char in escapes: result.append(escapes[char])
            elif char.isascii() and char.isdigit():
                digits = char
                for _ in range(2):
                    if self.at < len(self.text) and self.text[self.at] in '0123456789':
                        digits += self.text[self.at]; self.at += 1
                    else: break
                if int(digits) > 255: raise InvalidSave('escape out of range')
                result.append(int(digits))
            else: raise InvalidSave('unsupported string escape')
        raise InvalidSave('unterminated string')
    def value(self, depth=0):
        self.skip(); self.nodes += 1
        if depth > 16 or self.nodes > 250000: raise InvalidSave('save exceeds parser budget')
        if self.at >= len(self.text): raise InvalidSave('missing value')
        char = self.text[self.at]
        if char in '\"\'': return self.string()
        if self.take('{'):
            result, index = {}, 1
            while not self.take('}'):
                self.skip()
                if self.take('['):
                    key = self.value(depth+1); self.need(']'); self.need('=')
                else:
                    start = self.at; match = IDENT.match(self.text, self.at)
                    if match:
                        self.at = match.end()
                        if self.take('='): key = match[0]
                        else: self.at = start; key = index; index += 1
                    else: key = index; index += 1
                if type(key) not in (str, int) or key in result: raise InvalidSave('invalid or duplicate key')
                result[key] = self.value(depth+1)
                if self.take('}'): return result
                if not self.take(',') and not self.take(';'): raise InvalidSave('expected table separator')
            return result
        match = NUMBER.match(self.text, self.at)
        if match:
            self.at = match.end(); raw = match[0]
            value = float(raw) if any(c in raw for c in '.eE') else int(raw)
            if isinstance(value, float) and not math.isfinite(value): raise InvalidSave('nonfinite number')
            return value
        word = self.name()
        if word not in ('true', 'false', 'nil'): raise InvalidSave('only literal values supported')
        return {'true':True, 'false':False, 'nil':None}[word]
    def parse(self):
        result = {}
        self.skip()
        while self.at < len(self.text):
            name = self.name()
            if name in result: raise InvalidSave('duplicate global')
            self.need('='); result[name] = self.value(); self.take(';'); self.skip()
        return result

def lua(value, depth=0):
    if value is None: return 'nil'
    if value is True: return 'true'
    if value is False: return 'false'
    if isinstance(value, (int, float)): return repr(value)
    if isinstance(value, str):
        out = '"'
        for char in value:
            if char == '"': out += '\\"'
            elif char == '\\': out += '\\\\'
            elif ord(char) < 32 or ord(char) == 127: out += '\\%03d' % ord(char)
            else: out += char
        return out+'"'
    pad = '  '*(depth+1)
    return '{\n'+''.join(pad+'['+lua(key)+'] = '+lua(item,depth+1)+',\n' for key,item in value.items())+'  '*depth+'}'

def rows(value):
    return value.items() if isinstance(value, dict) else []

def migrate(globals):
    result = copy.deepcopy(globals)
    events = []
    def note(path, status, reason): events.append({'path':path,'status':status,'reason':reason})
    data = result.get('LycheeCharacterDB')
    if not isinstance(data, dict): raise InvalidSave('expected LycheeCharacterDB table; use the character host save')
    if data.get('settingsVersion') != 1: raise InvalidSave('unknown character settingsVersion; original preserved')
    def ref(item, path, siblings=()):
        if not isinstance(item, dict): note(path,'preserved','invalid reference'); return
        owner = item.get('providerID')
        if owner not in PROVIDERS:
            if isinstance(owner,str) and owner.startswith('lychee.'):
                note(path,'preserved','unproven provider identity')
            return
        kind = item.get('kind')
        valid = False
        if kind in (None,'legacy-entry'):
            valid = ordinary_entry(owner,item.get('entryID')) and not any(key in item for key in ('actionID','actionVersion','args','target'))
        elif owner == 'lychee.blizzard-settings' and kind in ('target','command','invocation'):
            target = item.get('target',{})
            key = target.get('key',{}) if isinstance(target,dict) else {}
            action = item.get('actionID')
            version_ok = kind == 'target' or item.get('actionVersion') == 1
            target_ok = isinstance(target,dict) and target.get('version') == 1
            if isinstance(key,dict) and set(key) == {'channel'} and key['channel'] in CHANNELS:
                args = item.get('args',{})
                valid = target_ok and version_ok and (kind == 'target' or action == 'set-volume')
                if kind == 'invocation':
                    valid = valid and isinstance(args,dict) and set(args)=={'percent'} and type(args['percent']) is int and 0 <= args['percent'] <= 100
            # Setting IDs are generated from runtime metadata. Preserve instead
            # of guessing when locale/build changes; reviewed runtime recovery
            # may map them later.
        if not valid: note(path,'preserved','unproven entry/action/target'); return
        identity_keys = ('kind','product','providerID','entryID','actionID','actionVersion','target','args')
        candidate = dict(item); candidate['providerID'] = PROVIDERS[owner]
        identity = {key:candidate.get(key) for key in identity_keys}
        if any(other is not item and isinstance(other,dict) and
               {key:other.get(key) for key in identity_keys} == identity for other in siblings):
            note(path,'conflict','target reference already exists'); return
        item['providerID'] = PROVIDERS[owner]
        if item.get('sourceID') == owner+':records': item['sourceID'] = PROVIDERS[owner]+':records'
        note(path,'mapped',owner+' -> '+PROVIDERS[owner])
    for index,item in rows(data.get('pinned')): ref(item,f'pinned[{index}]',data['pinned'].values())
    palette = data.get('palette',{})
    if isinstance(palette,dict):
        for index,item in rows(palette.get('recent')): ref(item,f'palette.recent[{index}]',palette['recent'].values())
        personalization = palette.get('searchPersonalization',{})
        if isinstance(personalization,dict):
            for field in ('aliases','choices'):
                for index,item in rows(personalization.get(field)):
                    if isinstance(item,dict):
                        peers = [other.get('ref') for _,other in rows(personalization.get(field))
                                 if isinstance(other,dict) and other.get('product') == item.get('product')
                                 and (field == 'aliases' or (other.get('query') == item.get('query')
                                      and other.get('locale') == item.get('locale')))]
                        ref(item.get('ref'),f'personalization.{field}[{index}]',peers)
        overrides = palette.get('providerSearch',{})
        ids = {row.get('id') for _,row in rows(overrides) if isinstance(row,dict)}
        for index,row in rows(overrides):
            if not isinstance(row,dict): continue
            owner = row.get('id'); target = PROVIDERS.get(owner)
            if target:
                if target in ids: note(f'providerSearch[{index}]','conflict','target already exists')
                else: row['id']=target; ids.add(target); note(f'providerSearch[{index}]','mapped',owner)
            elif isinstance(owner,str) and owner.startswith('lychee.'): note(f'providerSearch[{index}]','preserved','unproven provider')
    disabled = data.get('disabledProviders',{})
    if isinstance(disabled,dict):
        for owner in disabled:
            if isinstance(owner,str) and owner.startswith('lychee.') and owner not in PROVIDERS:
                note('disabledProviders.'+owner,'preserved','unproven provider')
        for owner,target in PROVIDERS.items():
            if owner not in disabled: continue
            if target in disabled: note('disabledProviders.'+owner,'conflict','target already exists')
            elif type(disabled[owner]) is bool:
                disabled[target] = disabled[owner]; del disabled[owner]
                note('disabledProviders.'+owner,'mapped',target)
            else: note('disabledProviders.'+owner,'preserved','invalid boolean')
    return result, events

def run(host, output=None, write=False, business=()):
    paths = [Path(host), *map(Path,business)]
    blobs = []
    for path in paths:
        if path.stat().st_size > MAX_FILE: raise InvalidSave('file exceeds 32 MiB budget')
        blobs.append(path.read_bytes())
    parsed = Parser(blobs[0].decode('utf-8-sig')).parse()
    migrated, events = migrate(parsed)
    encoded = ('\n'.join(name+' = '+lua(value) for name,value in migrated.items())+'\n').encode('utf-8')
    if Parser(encoded.decode()).parse() != migrated: raise InvalidSave('serialization roundtrip failed')
    report = {'version':1,'dryRun':not write,'events':events,'referenceEvidence':REFERENCE_EVIDENCE,
              'sources':[{'path':str(path.resolve()),'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob)} for path,blob in zip(paths,blobs)],
              'outputSHA256':hashlib.sha256(encoded).hexdigest(),
              'limitations':['16 bundled provider identities; reviewed ordinary IDs and set-volume v1 mapped.',
                              'Unknown references and conflicts preserved; no claimed full recovery.',
                              'Runtime availability and localized dynamic setting IDs are not guessed offline.',
                              'Business settings and caches preserved as originals, not imported.',
                              'No game files modified; review before installing with WoW exited.']}
    if write:
        if output is None: raise InvalidSave('--write requires --output NEW_DIRECTORY')
        target = Path(output).resolve()
        if target.exists(): raise InvalidSave('output exists; refusing overwrite')
        if not target.parent.is_dir(): raise InvalidSave('output parent must exist')
        stage = Path(tempfile.mkdtemp(prefix='.lychee-migration-',dir=target.parent))
        try:
            (stage/'originals').mkdir()
            for index,(path,blob) in enumerate(zip(paths,blobs)):
                (stage/'originals'/f'{index}-{path.name}').write_bytes(blob)
            (stage/'Lychee.lua').write_bytes(encoded)
            (stage/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
            if target.exists(): raise InvalidSave('output appeared; refusing overwrite')
            os.rename(stage,target)
        finally:
            if stage.exists(): shutil.rmtree(stage)
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--host',required=True,type=Path)
    parser.add_argument('--business',action='append',default=[],type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--write',action='store_true')
    args = parser.parse_args()
    try: print(json.dumps(run(args.host,args.output,args.write,args.business),ensure_ascii=False,indent=2))
    except (OSError,UnicodeError,InvalidSave) as error: parser.exit(2,str(error)+'\n')
if __name__ == '__main__': main()
