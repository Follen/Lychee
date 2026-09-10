-- Independent lexical oracle: no production scorer is used to derive expectations.
function GetLocale() return "enUS" end
LycheeInternal={Search={}};Lychee={UI={Theme={MatchColorCode="|cffabcdef"}}}
local base=os.getenv("LYCHEE_QUALITY_BASE") or "package/Lychee/"
dofile(base.."Search/Normalizer.lua");dofile(base.."Search/StaticIndex.lua")
dofile("package/Lychee/UI/TextHighlight.lua")
local N,Index=LycheeInternal.Search.Normalizer,LycheeInternal.Search.StaticIndex
local cases={
 {"rl","heirlooms",false},{"rl","rl",true},{"rl","open rltools",true},
 {"rl","heirlooms rltool",true},{"rl","world",false},{"rl","2rl",false},
 {"rlo","heirlooms",true},{"hei","heirlooms",true},{"rl","中文rl",false},
 {"rl","中文 rl",true},{"rl","open-rl",true},{"rl foo","heirl foo",false},
 {"rl foo","open rl foo",true},{"foo rl","foo rlooms",true},
 {"红玉","传送红玉",true},{"12","item123",true},
}
for _,row in ipairs(cases) do
 local match=N:MatchText(row[1],row[2],"alias",{allowFuzzy=true})
 assert((match~=nil)==row[3],"lexical case: "..row[1].." / "..row[2])
end
local H=Lychee.UI.TextHighlight
assert(H:Format("heirlooms rltool","rl")=="heirlooms |cffabcdefrl|rtool")
local records={
 {id="reload",title="重载界面",aliases={"rl","reload"}},
 {id="heirloom",title="传家宝",aliases={"heirlooms"}},
 {id="a-description",title="Other",description="Common unrelated label"},
 {id="z-title",title="Important Common label"},
 {id="mixed",title="Common",aliases={"rltools"}},
}
local index=Index:New();assert(index:RegisterSource({id="quality"}));assert(index:CommitSnapshot("quality",records,1))
local function includes(query,id)
 for _,hit in ipairs(index:Search(query,20)) do if hit.record.id==id then return true end end
 return false
end
assert(includes("r","reload"));assert(not includes("rl","heirloom"));assert(includes("rlo","heirloom"),"relaxed third character survives candidate reuse")
assert(index:Search("Common label",20)[1].record.id=="z-title","literal title outranks scattered description")
assert(includes("common rl","mixed") and not includes("common rl","heirloom"))
-- Compare every exact/word-start/substring result with a separate word-splitting oracle.
local weights={title={1,.9,.74},alias={.98,.86,.72}}
local function literal(q,t)
 if t==q then return 1 end
 if t:sub(1,#q)==q then return 2 end
 if #q<=2 and q:match("^[a-z]+$") then
  for word in t:gmatch("[^ ]+") do if word:sub(1,#q)==q then return 3 end end
 elseif t:find(q,1,true) then return 3 end
end
local entries={}
for n=1,120 do entries[n]={id=string.format("%03d",n),title="neutral "..n,aliases={n%3==0 and "heirlooms" or n%3==1 and "open rltool" or "reload"}} end
local scan=Index:New();scan.fuzzyLimit=0;assert(scan:RegisterSource({id="scan"}));assert(scan:CommitSnapshot("scan",entries,1))
local function compare(q)
 local expected={}
 for _,r in ipairs(entries) do
  local best=0
  for _,field in ipairs({"title","alias"}) do
   local text=field=="title" and r.title or r.aliases[1]
   local kind=literal(q,text);if kind then best=math.max(best,weights[field][kind]) end
  end
  if best>0 then expected[#expected+1]={id=r.id,score=best} end
 end
 table.sort(expected,function(a,b) return a.score>b.score or a.score==b.score and a.id<b.id end)
 local actual=scan:Search(q,20)
 assert(#actual==math.min(20,#expected),"oracle count "..q)
 for i,hit in ipairs(actual) do assert(hit.record.id==expected[i].id and hit.confidence==expected[i].score,"oracle order "..q) end
end
for _,q in ipairs({"r","rl","rlo","rl","hei","looms","open","re"}) do compare(q) end
assert(scan:TouchSource("scan",false));assert(#scan:Search("rl",20)==0);assert(scan:TouchSource("scan",true));compare("rl")
local all={};for n=1,600 do all[n]={id=string.format("%04d",n),title="Entry "..n} end
local browse=Index:New();assert(browse:RegisterSource({id="browse"}));assert(browse:CommitSnapshot("browse",all,1))
for i,hit in ipairs(browse:Search("",20,{sourceID="browse"})) do assert(hit.record.id==string.format("%04d",i),"scope must sort before limiting") end
print("Search quality PASS: lexical oracle, short words, phrase weights, highlight, incremental typing, scope TopK")
