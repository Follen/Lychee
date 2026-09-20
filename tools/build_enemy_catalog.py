"""Build the creature reference catalogue from a bounded factual snapshot.

--import-reference reads an analysis checkout, never changes or ships its code.
Ordinary builds/checks use only the checked-in snapshot. Public records stay named.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "assets/data/enemies.json"
OUTPUT = ROOT / "addon/Lychee/Providers/LDT/Data.lua"
# Xal'atath's Gift is affix noise, not a creature ability. Keep source facts intact.
EXCLUDED_SPELL_IDS = frozenset({1221063})

EXTRACT = r'''
local root=arg[1]..'/'
local m={AddonName='Reference',L=setmetatable({},{__index=function(_,k)return k end})}
for _,k in ipairs({'dungeonList','mapInfo','zoneIdToDungeonIdx','dungeonMaps','dungeonSubLevels','dungeonTotalCount','mapPOIs','dungeonEnemies','scaleMultiplier'}) do m[k]={} end
local file=assert(io.open(root..'Midnight/load_midnight.xml'));local xml=file:read('*a');file:close()
local env={ipairs=ipairs,pairs=pairs,type=type,tonumber=tonumber,tostring=tostring,math=math,string=string,table=table}
for path in xml:gmatch("file='([^']+)'") do
 assert(path:match('^[%w_]+%.lua$'))
 local fn=assert(loadfile(root..'Midnight/'..path));setfenv(fn,env);fn('Reference',m)
end
local function quote(s) return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
local function encode(v)
 if type(v)=='string' then return quote(v) end
 if type(v)~='table' then return tostring(v) end
 local result={};for k,value in pairs(v) do result[#result+1]=quote(tostring(k))..':'..encode(value) end
 table.sort(result);return '{'..table.concat(result,',')..'}'
end
local out={dungeons={}}
for index,enemies in pairs(m.dungeonEnemies) do
 local info=m.mapInfo[index]
 local dungeon={id=index,key=m.dungeonList[index],name=info.englishName,shortName=info.shortName,mapID=info.mapID,total=m.dungeonTotalCount[index].normal,enemies={}}
 for _,e in pairs(enemies) do
  local enemy={}
  for _,k in ipairs({'id','name','displayId','isBoss','health','level','count','creatureType','stealth','stealthDetect','characteristics'}) do enemy[k]=e[k] end
  enemy.spells={}
  for id,flags in pairs(e.spells or {}) do
   local spell={id=id}
   for _,k in ipairs({'interruptible','magic','curse','poison','disease','enrage','bleed'}) do if type(flags[k])=='boolean' then spell[k]=flags[k] end end
   enemy.spells[tostring(id)]=spell
  end
  dungeon.enemies[tostring(e.id)]=enemy
 end
 out.dungeons[tostring(index)]=dungeon
end
print(encode(out))
'''


def import_reference(path):
    result = subprocess.run(["lua", "-", str(path.resolve())], input=EXTRACT,
                            text=True, encoding="utf-8", capture_output=True, check=True)
    data = json.loads(result.stdout)
    # These are in-game proper names, not copied UI prose or implementation.
    locale = (path / "Locales/zhCN.lua").read_text(encoding="utf-8-sig")
    names = dict(re.findall(r'L\["([^"\n]+)"\]\s*=\s*"([^"\n]*)"', locale))
    instances = json.loads((ROOT / "docs/architecture/2026-09-10-journal-instances.json").read_text(encoding="utf-8-sig"))["data"]["rows"]
    encounters = json.loads((ROOT / "docs/architecture/2026-09-10-journal-encounters.json").read_text(encoding="utf-8-sig"))["data"]["rows"]
    instance_ids = {r["Name_lang"]: r["ID"] for r in instances}
    for dungeon in data["dungeons"].values():
        dungeon["nameZh"] = names.get(dungeon.pop("key"), dungeon["name"])
        dungeon["shortZh"] = names.get(dungeon["shortName"], dungeon["nameZh"])
        dungeon.pop("shortName")
        instance = instance_ids.get(dungeon["nameZh"])
        ordered = sorted((e for e in encounters if e["JournalInstanceID"] == instance), key=lambda e: (e["OrderIndex"], e["ID"]))
        order = {e["Name_lang"]: (i+1, e["ID"]) for i,e in enumerate(ordered)}
        for enemy in dungeon["enemies"].values():
            enemy["nameZh"] = names.get(enemy["name"], enemy["name"])
            if enemy.get("isBoss") and enemy["nameZh"] in order:
                enemy["bossOrder"], enemy["journalID"] = order[enemy["nameZh"]]
            enemy["spells"] = sorted(enemy["spells"].values(), key=lambda s: s["id"])
        dungeon["enemies"] = sorted(dungeon["enemies"].values(), key=lambda e:e["id"])
    data["dungeons"] = sorted(data["dungeons"].values(), key=lambda d:d["id"])
    data["schema"] = 1
    data["gameBuild"] = "12.1.0.69587"
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")


def lua(value):
    if value is None: return "nil"
    if isinstance(value,bool): return "true" if value else "false"
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,(int,float)): return str(value)
    if isinstance(value,list): return "{"+",".join(lua(v) for v in value)+"}"
    return "{"+",".join((k if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*",k) else "["+lua(k)+"]")+"="+lua(v) for k,v in sorted(value.items()))+"}"


def render(data):
    assert data["schema"] == 1 and 0 < len(data["dungeons"]) <= 64
    total = 0
    for d in data["dungeons"]:
        assert len(d["enemies"]) <= 256
        ids = set()
        for e in d["enemies"]:
            assert e["id"] not in ids and e["id"] > 0 and e["displayId"] > 0
            ids.add(e["id"])
            assert len(e["spells"]) <= 64
            assert len({s["id"] for s in e["spells"]}) == len(e["spells"])
            total += 1
    assert total <= 4096
    lines = ["-- Generated by tools/build_enemy_catalog.py from assets/data/enemies.json.",
             "-- Search borrows the caller's named scratch record; only details materialize full facts.",
             "local M={id=\"builtin.ldt\"}", "_G.LycheeInternal.ProviderModules.LDT=M",
             "M.dungeonIDs="+lua([d["id"] for d in data["dungeons"]]), "local loaders={"]
    for d in data["dungeons"]:
        lines += ["    ["+str(d["id"])+"]=function(npc,visit,enemy)",
                  "        local dungeon="+lua({k:v for k,v in d.items() if k!="enemies"})]
        for e in d["enemies"]:
            e = dict(e, spells=[spell for spell in e["spells"] if spell["id"] not in EXCLUDED_SPELL_IDS])
            fields = {k:e.get(k) for k in ("id","name","nameZh","isBoss","bossOrder")}
            fields["spellIDs"] = ",".join(str(s["id"]) for s in e["spells"])
            lines += ["        if visit then",
                      "            "+";".join("enemy."+k+"="+lua(v) for k,v in fields.items()),
                      "            visit(enemy,dungeon)",
                      "        elseif npc=="+str(e["id"])+" then return "+lua(e)+",dungeon end"]
        lines += ["    end,"]
    lines += ["}", "function M:ScanDungeon(id,visit,scratch)", "    local load=loaders[id]",
              "    if load then load(nil,visit,scratch) end", "end",
              "function M:LoadEnemy(id,npc)", "    local load=loaders[id]",
              "    if load then return load(npc) end", "end", ""]
    return "\n".join(lines)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-reference",type=Path)
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    if args.import_reference: import_reference(args.import_reference)
    data=json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    output=render(data)
    if args.check:
        assert OUTPUT.read_text(encoding="utf-8") == output, "Enemy catalogue generation drift"
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True)
        OUTPUT.write_text(output,encoding="utf-8",newline="\n")
    print(f"Enemy catalogue: {len(data['dungeons'])} dungeons, {sum(len(d['enemies']) for d in data['dungeons'])} creatures")


if __name__ == "__main__": main()
