-- Independent materialized localization/UTF-8 oracle for streaming compilation.
local locale = "zhCN"
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0", "69587", "today", 120100 end
LycheeInternal={Search={}}
dofile("package/Lychee/Search/RuntimeIdentity.lua")
dofile("package/Lychee/Search/Normalizer.lua")
dofile("package/Lychee/Search/Storage.lua");dofile("package/Lychee/Search/StaticIndex.lua")
local I=LycheeInternal
local N,R,Index=I.Search.Normalizer,I.Search.RuntimeIdentity,I.Search.StaticIndex
local values={"普通文本 mixed words", "", false, 42,
    {text="scoped text",locale="enUS",scope={minBuild=69000}},
    {default="fallback",zhCN="中文",zhTW="繁體",enUS="English",enGB="British",deDE="Deutsch"},
    {"default alias",{text="中文别名",locale="zhCN"},{title="English alias",locale="enUS"},
        {text="rejected build",scope={minBuild=999999}},{default="plain fallback"}},
    {text="parent must still match",scope={product="retail"}},
}
local scopes={false,{}, {product="retail"}, {product="classic"}, {locale="zhCN"},
    {products={"classic","retail"},minInterface=120000,maxBuild=70000}, {minBuild=999999}}
local cases=0
for _,lang in ipairs({"zhCN","zhTW","enUS","enGB","deDE"}) do
    locale=lang;N.locale=lang;R:Refresh()
    for _,value in ipairs(values) do for _,rawScope in ipairs(scopes) do
        local scope=rawScope or nil
        local expected,actual={},{}
        for _,entry in ipairs(N:Localized(value,scope)) do
            if N:LocaleRank(entry.locale) and R:MatchesScope(scope,entry) then
                local text=N:Normalize(entry.text)
                if text~="" then local n=#expected;expected[n+1],expected[n+2],expected[n+3]="alias",entry.text,text end
            end
        end
        N:AppendFields(actual,"alias",value,scope)
        assert(#actual==#expected,"localized field count differs")
        for k=1,#expected do assert(actual[k]==expected[k],"localized order/text differs") end
        cases=cases+1
    end end
end
locale="zhCN";N.locale=locale;R:Refresh()
local index=Index:New()
local allBytes={};for n=1,255 do allBytes[n]=string.char(n) end
local raw="重重 repeated aa "..table.concat(allBytes).." 中文"
local records={{id="one",title=raw,aliases={raw,"repeated repeated"}},{id="two",title="重重 repeated"}}
assert(index:RegisterSource({id="utf8"}))
assert(index:CommitSnapshot("utf8",records))
local function checkPostings()
    local expected={}
    for key,entry in pairs(index.entries) do
        if entry.fields then for n=1,#entry.fields,3 do
            local text,starts=entry.fields[n+2],{}
            for offset=1,#text do local byte=text:byte(offset);if byte<128 or byte>=192 then starts[#starts+1]=offset end end
            starts[#starts+1]=#text+1
            for offset=1,#starts-1 do
                local gram=text:sub(starts[offset],starts[offset+1]-1)
                if gram~=" " then expected[gram]=expected[gram] or {};expected[gram][key]=true end
            end
        end end
    end
    for gram,members in pairs(expected) do
        local actual=index.grams[gram];assert(actual,"missing character membership")
        for key in pairs(members) do
            local found=actual==key
            if type(actual)=="table" then for _,member in ipairs(actual) do if member==key then found=true end end end
            assert(found,"missing entry membership")
        end
    end
    for gram,actual in pairs(index.grams) do
        assert(expected[gram],"unexpected character")
        if type(actual)=="string" then assert(expected[gram][actual])
        else local seen={};for _,key in ipairs(actual) do assert(expected[gram][key] and not seen[key]);seen[key]=true end end
    end
end
checkPostings()
assert(index:Remove("utf8","one"));checkPostings()
assert(index:TouchSource("utf8",false));checkPostings()
assert(index:TouchSource("utf8",true));checkPostings()
print("Search compile PASS: "..cases.." locale/scope cases; all-byte UTF-8 membership, duplicate fields, removal and enable lifecycle")
