"""Independent full capture-to-runtime relation comparison; no generator import."""
import hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
folder=root/"docs/architecture/raid-journal"
raw=(folder/"retail-zhCN.tsv").read_bytes();meta=json.loads((folder/"manifest.json").read_text(encoding="utf-8"))
assert hashlib.sha256(raw).hexdigest()==meta["sha256"] and meta["complete"] and not meta["outputTruncated"]
instances,bosses,diffs,relations={},{},{},{}
for line in raw.decode().splitlines():
    a=line.split("\t")
    if a[0]=="D":diffs[int(a[1])]=int(a[2])
    elif a[0]=="I":instances[int(a[1])]=a[2]
    elif a[0]=="B":bosses[int(a[1])]=(int(a[2]),a[3],int(a[4]))
    elif a[0]=="A":
        for entry in filter(None,a[2].split(";")):
            spell,section,mask=map(int,entry.split(":"))
            for bit,d in diffs.items():
                if bit&mask:
                    key=(int(a[1]),spell,d);relations[key]=min(section,relations.get(key,section))
script=r'''local ns={Modules={}};assert(loadfile("addon/Lychee_Encounters/Bosses/JournalCatalog.lua"))("Lychee_Encounters",ns)
local c=ns.Modules.JournalCatalog
for i=1,#c.encounters,3 do
 local id,owner,name=c.encounters[i],c.encounters[i+1],c.encounters[i+2]
 io.write("B\t",id,"\t",owner,"\t",name,"\t",c.instances[owner][1],"\t",c.difficulties[id],"\n")
end
for boss,encoded in pairs(c.abilities) do
 local previousSpell=0
 for spell,section,mask in encoded:gmatch("([0-9a-z]+):([0-9a-z]+):([0-9a-z]+)") do
  spell,section,mask=tonumber(spell,c.numberBase),tonumber(section,c.numberBase),tonumber(mask,c.numberBase)
  spell=spell+previousSpell;previousSpell=spell
  for i,d in ipairs({3,4,5,6,9,14,15,16}) do
   if math.floor(tonumber(mask)/2^(i-1))%2==1 then io.write("S\t",boss,"\t",spell,"\t",d,"\t",section,"\n") end
  end
 end
end'''
actual={};seen=set()
for line in subprocess.check_output(["lua","-e",script],cwd=root).decode().splitlines():
 a=line.split("\t")
 if a[0]=="B":
  id,owner=int(a[1]),int(a[2]);assert id not in seen;seen.add(id)
  ref=bosses[id];assert (owner,a[3],a[4])==(ref[0],ref[1],instances[owner])
  assert set(map(int,a[5].split(",")))=={d for bit,d in diffs.items() if bit&ref[2]}
 else:
  key=tuple(map(int,a[1:4]));assert key not in actual;actual[key]=int(a[4])
assert seen==set(bosses) and actual==relations
assert 89 not in seen and 2879 not in seen, "dungeon bosses excluded"
assert 1519 in seen and not any(k[0]==1519 for k in relations), "legacy raid boss remains without invented abilities"
print(f"Journal runtime capture equivalence PASS: {len(bosses)} bosses, {len(relations)} difficulty relations")
