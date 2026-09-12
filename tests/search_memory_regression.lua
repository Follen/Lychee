-- Independent full-scan ranking and quadratic-distance oracles for the index.
function GetLocale() return "zhCN" end
LycheeInternal={Search={}}
dofile("package/Lychee/Search/Normalizer.lua")
dofile("package/Lychee/Search/StaticIndex.lua")
local N,Index=LycheeInternal.Search.Normalizer,LycheeInternal.Search.StaticIndex
local function distance(a,b)
    local p,c={},{}
    for j=0,#b do p[j]=j end
    for i=1,#a do
        c[0]=i
        for j=1,#b do c[j]=math.min(c[j-1]+1,p[j]+1,p[j-1]+(a:byte(i)==b:byte(j) and 0 or 1)) end
        p,c=c,p
    end
    return p[#b]
end
local words={"a","ab","ba","abc","aabb","abab","baba","cab","cabca","acabc","传送红玉","传送红雨","峰值测试坐骑1499","峰值测试坐骑1500"}
local seed=314159
local function random(max) seed=(seed*16807)%2147483647;return seed%max+1 end
for i=1,80 do
    local text=""
    for j=1,random(12) do local value=random(3);text=text..("abc"):sub(value,value) end
    words[#words+1]=text
end
for _,a in ipairs(words) do for _,b in ipairs(words) do
    if not b:find(a,1,true) then
        local expected=distance(a,b)
        local confidence,kind,actual=N:ScoreNormalized(a,b,"title",true)
        if #a<=2 and a:match("^[a-z]+$") then assert(not confidence,"short English cannot fuzzy-match")
        elseif expected<=2 then assert(kind=="fuzzy" and actual==expected,"banded distance differs from oracle")
        else assert(not confidence,"false fuzzy match") end
    end
end end
local index=Index:New()
local records={}
for i=1,650 do
    records[i]={id=string.format("%04d",i),title="共同标记 星光坐骑 "..i,
        aliases={"shared mount "..i,i%2==0 and "蓝色" or "红色"},keywords={i%3==0 and "团队" or "副本"}}
end
assert(index:RegisterSource({id="large",priority=3}))
assert(index:CommitSnapshot("large",records,1))
assert(index:RegisterSource({id="small",priority=9}))
assert(index:CommitSnapshot("small",{{id="same",title="shared mount",aliases={"共同标记"}}},1))
local function oracle(query,filter)
    local out,terms={},N:Terms(query)
    for _,entry in pairs(index.entries) do
        if entry.source.enabled and (not filter or entry.sourceID==filter.sourceID) then
            -- Derive the oracle from source records, independent of compiled layout.
            local fields={}
            for _,pair in ipairs({{"title","title"},{"aliases","alias"},{"keywords","keyword"}}) do
                for _,value in ipairs(N:Localized(entry.record[pair[1]])) do
                    fields[#fields+1]={normalized=N:Normalize(value.text),field=pair[2]}
                end
            end
            local best,field
            local all=#terms>1
            for _,term in ipairs(terms) do
                local found=false
                for _,value in ipairs(fields) do if value.normalized:find(term,1,true) then found=true;break end end
                if not found then all=false;break end
            end
            if all then
                local weakest=1
                for _,term in ipairs(terms) do
                    local strongest=0
                    for _,value in ipairs(fields) do strongest=math.max(strongest,N:ScoreNormalized(term,value.normalized,value.field,false) or 0) end
                    weakest=math.min(weakest,strongest)
                end
                best,field=weakest*.9,"tokens"
            end
            for _,value in ipairs(fields) do
                local score=N:ScoreNormalized(query,value.normalized,value.field,false)
                if score and (not best or score>best or score==best and value.field<field) then best,field=score,value.field end
            end
            if best and best>.56 then out[#out+1]={id=entry.stableID,score=best,priority=entry.source.priority,field=field} end
        end
    end
    table.sort(out,function(a,b) if a.score~=b.score then return a.score>b.score end;if a.priority~=b.priority then return a.priority>b.priority end;return a.id<b.id end)
    while #out>20 do out[#out]=nil end
    return out
end
local queries={"共","共同","共同标记","共同标记 星光坐骑 649","星光","坐骑","红色 团队","蓝色 副本","shared","shared mount","shared mount 650","mount 549","团队"}
for round=1,3 do for _,query in ipairs(queries) do
    for _,filter in ipairs({false,{sourceID="large"},{sourceID="small"}}) do
        local expected,actual=oracle(query,filter),index:Search(query,20,filter or nil)
        for i,entry in ipairs(expected) do
            assert(actual[i] and actual[i].stableID==entry.id and actual[i].confidence==entry.score and actual[i].evidence.matchedField==entry.field,
                "full-scan ranking differs: "..query.." / "..i)
        end
    end
end end
assert(#index:Search("共同标记",0)==0)
assert(index:TouchSource("large",false))
for key in pairs(index.sources.large.entryKeys) do assert(not index.entries[key].fields and not index.entries[key].indexed) end
assert(index:TouchSource("large",true))
assert(index:Search("shared mount 650",1)[1].record.id=="0650","enable restores complete index")
assert(index:ApplyDelta("large",{{id="0650",title="修改后专属名称"}},{}))
assert(index:Search("修改后专属名称",1)[1].record.id=="0650")
assert(index:UnregisterSource("large") and index:UnregisterSource("small"))
assert(next(index.grams)==nil,"character postings are released after removal")
N:ClearCache()
for i=1,10000 do N:Normalize("cache bound "..i) end
local cached=0;for _ in pairs(N.cache) do cached=cached+1 end
assert(cached<=1024 and #N.cacheKeys<=1024,"normalizer retains unbounded query strings")
print("Search memory regression PASS: 8,836 distance pairs, full-scan ranking, disable/re-enable, removal and bounded cache")
