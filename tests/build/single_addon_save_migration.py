"""Synthetic-only tests; no access to real SavedVariables."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('migration',Path(__file__).resolve().parents[2]/'tools/migrate_single_addon_saves.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class MigrationTests(unittest.TestCase):
    def root(self):
        return {'LycheeCharacterDB':{'settingsVersion':1,'pinned':{
            1:{'providerID':'lychee.player-spells','entryID':'spell:123','sourceID':'lychee.player-spells:records','title':'中文'},
            2:{'kind':'invocation','product':'retail','providerID':'lychee.blizzard-settings','actionID':'set-volume','actionVersion':1,'target':{'version':1,'key':{'channel':'master'}},'args':{'percent':30}}},
            'palette':{'providerSearch':{1:{'id':'lychee.player-spells','global':False,'prefixes':{1:'法术'}}}},
            'disabledProviders':{'lychee.player-spells':True}}}
    def test_parser_literals_roundtrip(self):
        source='-- saved\nLycheeCharacterDB = { settingsVersion=1, ["s"]="中文\\010\\034\\092", [3]=false, [5]={1,2,3}, }'
        parsed=m.Parser(source).parse()
        self.assertEqual(m.Parser('\n'.join(k+'='+m.lua(v) for k,v in parsed.items())).parse(),parsed)
    def test_reject_code_duplicate_and_budget(self):
        for source in ['A=os.execute("bad")','A=(1+2)','A={x=1,x=2}','A={ [true]=1 }','A="\\999"','A=function()end','A=1 A=2','A={'+('{'*18)+('}'*18)+'}']:
            with self.subTest(source=source),self.assertRaises(m.InvalidSave): m.Parser(source).parse()
    def test_map_without_mutating_source(self):
        source=self.root();result,events=m.migrate(source)
        self.assertEqual(source['LycheeCharacterDB']['pinned'][1]['providerID'],'lychee.player-spells')
        self.assertEqual(result['LycheeCharacterDB']['pinned'][1]['providerID'],'builtin.player-spells')
        self.assertEqual(result['LycheeCharacterDB']['pinned'][2]['args'],{'percent':30})
        self.assertEqual(result['LycheeCharacterDB']['disabledProviders'],{'builtin.player-spells':True})
        self.assertEqual(result['LycheeCharacterDB']['palette']['providerSearch'][1]['id'],'builtin.player-spells')
        self.assertTrue(events)
        again,changes=m.migrate(result);self.assertEqual(again,result);self.assertEqual(changes,[])
    def test_unknown_and_conflict_preserved(self):
        source=self.root();data=source['LycheeCharacterDB']
        data['pinned'][3]={'providerID':'builtin.player-spells','entryID':'spell:123'}
        data['pinned'][4]={'providerID':'lychee.unknown','entryID':'x'}
        data['disabledProviders']['builtin.player-spells']=False
        data['palette']['providerSearch'][2]={'id':'builtin.player-spells','global':True}
        result,events=m.migrate(source)
        self.assertEqual(result['LycheeCharacterDB']['pinned'][1],data['pinned'][1])
        self.assertEqual(result['LycheeCharacterDB']['pinned'][4],data['pinned'][4])
        self.assertEqual(result['LycheeCharacterDB']['disabledProviders'],data['disabledProviders'])
        self.assertEqual(sum(e['status']=='conflict' for e in events),3)
    def test_all_bundled_ordinary_refs_and_preferences(self):
        cases={'mounts':'mount:1','achievements':'achievement:2','bags':'item:3',
               'talent-loadouts':'talent:4','equipment-sets':'equipment:0','bosses':'boss-5-spell-6-16',
               'ldt':'11/122056/244750','keystones':'key:Player-1-0000ABCD','game-menus':'character',
               'crests':'crests','great-vault':'great-vault','addon-inspector':'inspect',
               'ellesmere':'page/EllesmereUI/Test-20Page','exwind':'edit/Exwind/Test-20Page'}
        for suffix,entry in cases.items():
            with self.subTest(suffix=suffix):
                old='lychee.'+suffix;new='builtin.'+suffix
                data={'settingsVersion':1,'pinned':{1:{'providerID':old,'entryID':entry}},
                      'disabledProviders':{old:False},'palette':{'providerSearch':{1:{'id':old,'global':False}}}}
                result,_=m.migrate({'LycheeCharacterDB':data});out=result['LycheeCharacterDB']
                self.assertEqual(out['pinned'][1],{'providerID':new,'entryID':entry})
                self.assertEqual(out['disabledProviders'],{new:False})
                self.assertEqual(out['palette']['providerSearch'][1]['id'],new)
        for owner,entry in [('lychee.bosses','boss-1'),('lychee.bosses','boss-1-difficulty-16'),
                            ('lychee.ellesmere','option/123/456'),('lychee.exwind','app/test'),('lychee.exwind','tool/test')]:
            self.assertTrue(m.ordinary_entry(owner,entry))
        for owner,entry in [('lychee.ellesmere','status'),('lychee.exwind','status'),('lychee.game-menus','lychee-settings'),
                            ('lychee.mounts','spell:1'),('lychee.ellesmere','page/a/-ZZ')]:
            self.assertFalse(m.ordinary_entry(owner,entry))
    def test_personalization_collision_preserves_both(self):
        source=self.root();palette=source['LycheeCharacterDB']['palette']
        old={'providerID':'lychee.player-spells','entryID':'spell:123'}
        new={'providerID':'builtin.player-spells','entryID':'spell:123'}
        palette['searchPersonalization']={'aliases':{1:{'ref':old,'product':'retail','alias':'a'},2:{'ref':new,'product':'retail','alias':'b'}}}
        result,events=m.migrate(source)
        self.assertEqual(result['LycheeCharacterDB']['palette']['searchPersonalization'],palette['searchPersonalization'])
        self.assertTrue(any(e['status']=='conflict' for e in events))
    def test_unknown_action_schema_and_dynamic_setting_preserved(self):
        source=self.root();data=source['LycheeCharacterDB']
        data['pinned'][2]['actionVersion']=2
        data['pinned'][3]={'providerID':'lychee.blizzard-settings','entryID':'setting:1:音量'}
        result,events=m.migrate(source)
        self.assertEqual(result['LycheeCharacterDB']['pinned'][2],data['pinned'][2])
        self.assertEqual(result['LycheeCharacterDB']['pinned'][3],data['pinned'][3])
        data['settingsVersion']=99
        with self.assertRaises(m.InvalidSave): m.migrate(source)
    def test_dry_run_new_directory_backup_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);host=base/'Lychee.lua';business=base/'Lychee_Player.lua';target=base/'output'
            original=('LycheeCharacterDB='+m.lua(self.root()['LycheeCharacterDB'])).encode()
            host.write_bytes(original);business.write_bytes(b'opaque business original')
            report=m.run(host,target,business=[business])
            self.assertFalse(target.exists());self.assertTrue(report['dryRun'])
            report=m.run(host,target,True,[business])
            self.assertEqual(host.read_bytes(),original)
            self.assertEqual((target/'originals'/'0-Lychee.lua').read_bytes(),original)
            self.assertEqual((target/'originals'/'1-Lychee_Player.lua').read_bytes(),business.read_bytes())
            self.assertEqual(json.loads((target/'report.json').read_text(encoding='utf-8')),report)
            with self.assertRaises(m.InvalidSave):m.run(host,target,True)
            self.assertEqual(m.Parser((target/'Lychee.lua').read_text(encoding='utf-8')).parse()['LycheeCharacterDB']['pinned'][1]['providerID'],'builtin.player-spells')

if __name__=='__main__':unittest.main()
