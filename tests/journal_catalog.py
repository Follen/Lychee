"""Compare shipped compact records against the immutable source snapshots."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = root / "docs/architecture"
instances = json.loads((data / "2026-09-10-journal-instances.json").read_text(encoding="utf-8-sig"))["data"]["rows"]
encounters = json.loads((data / "2026-09-10-journal-encounters.json").read_text(encoding="utf-8-sig"))["data"]["rows"]
owners = {row["ID"]: row for row in instances if row.get("Name_lang")}
expected = sorted((row for row in encounters if row.get("Name_lang") and row["JournalInstanceID"] in owners),
                  key=lambda row: (row["JournalInstanceID"], row["OrderIndex"], row["ID"]))
script = '''LycheeInternal={Builtin={}}; dofile("package/Lychee/Builtin/Bosses/JournalCatalog.lua")
local c=LycheeInternal.Builtin.JournalCatalog; assert(#c.encounters==c.encounterCount*3)
for i=1,#c.encounters,3 do
 local id,owner,name=c.encounters[i],c.encounters[i+1],c.encounters[i+2]
 local instance=assert(c.instances[owner])
 io.write(id,"\\t",owner,"\\t",name,"\\t",instance[1],"\\t",tostring(instance[2]),"\\n")
end'''
lines = subprocess.check_output(["lua", "-e", script], cwd=root).decode("utf-8").splitlines()
assert len(lines) == len(expected)
for line, row in zip(lines, expected):
    owner = owners[row["JournalInstanceID"]]
    icon = owner["ButtonSmallFileDataID"] or owner["ButtonFileDataID"]
    assert line.split("\t") == [str(row["ID"]), str(row["JournalInstanceID"]), row["Name_lang"],
                               owner["Name_lang"], str(icon) if icon > 0 else "nil"]
print(f"Journal snapshot equivalence PASS: {len(lines)} full rows, order, owners, names, icons")
