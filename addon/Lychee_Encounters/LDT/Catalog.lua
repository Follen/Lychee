local _,I=...
local M=I.Modules.LDT
local N=I.Search.Normalizer
local L=I.ProviderLocales:ForProvider(M.id)
local numbers={"一","二","三","四","五","六","七","八","九","十"}
local icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\skull.tga"
local function now() return debugprofilestop and debugprofilestop() or 0 end
function M:Name(value) return N.locale:sub(1,2)=="zh" and value.nameZh or value.name end
function M:SpellName(id)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
end
function M:Aliases(enemy,dungeon,reuse)
    local aliases=reuse or {}
    for index=#aliases,1,-1 do aliases[index]=nil end
    aliases[1],aliases[2],aliases[3]=enemy.name,enemy.nameZh,tostring(enemy.id)
    aliases[4],aliases[5],aliases[6]=dungeon.name,dungeon.nameZh,dungeon.shortZh
    local order=enemy.bossOrder
    if order then
        local digit=tostring(order)
        local cn=numbers[order] or digit
        aliases[#aliases+1]=dungeon.shortZh.."老"..cn
        aliases[#aliases+1]=dungeon.shortZh.."老"..digit
        aliases[#aliases+1]=dungeon.nameZh..cn.."号boss"
        aliases[#aliases+1]=dungeon.shortZh..digit.."号boss"
        aliases[#aliases+1]=dungeon.shortZh..cn.."号boss"
        aliases[#aliases+1]=dungeon.name.." boss "..digit
    end
    return aliases
end
function M:Record(enemy,dungeon,spellID)
    local spell=spellID and self:SpellName(spellID)
    local aliases=self:Aliases(enemy,dungeon)
    if spellID then aliases[#aliases+1]=spell or tostring(spellID);aliases[#aliases+1]=tostring(spellID) end
    return {id=dungeon.id.."/"..enemy.id..(spellID and "/"..spellID or ""),title=self:Name(enemy),
        kindTitle=L["荔枝大米助手"].." · "..L[enemy.isBoss and "首领" or "小怪"],kind="reference",icon=spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or icon,
        subtitle=self:Name(dungeon)..(spellID and (" · "..(spell or (L["技能"].." "..spellID))) or ""),aliases=aliases,
        payload={dungeonID=dungeon.id,npcID=enemy.id,spellID=spellID or 0},actions={"open"}}
end
function M:Find(dungeonID,npcID,spellID)
    local enemy,dungeon=self:LoadEnemy(dungeonID,npcID)
    if enemy then
        if spellID and spellID~=0 then
            local found=false
            for _,spell in ipairs(enemy.spells) do if spell.id==spellID then found=true;break end end
            if not found then return end
        end
        return enemy,dungeon
    end
end
function M:Resolve(id)
    if not self.active or type(id)~="string" then return end
    local did,npc,spell=id:match("^(%d+)/(%d+)/(%d+)$")
    if not did then did,npc=id:match("^(%d+)/(%d+)$") end
    local enemy,dungeon=self:Find(tonumber(did),tonumber(npc),tonumber(spell))
    if enemy then return self:Record(enemy,dungeon,tonumber(spell)) end
end
function M:Query(request,reply,context)
    if not self.active or request.filter and request.filter.sourceID and request.filter.sourceID~=self.id..":records" then reply({});return end
    local resources=context.resources
    local query=request.normalized or ""
    if query=="" and not (request.filter and request.filter.sourceID) then reply({});return end
    local finalDungeon=query:match("^(.-)尾王boss$") or query:match("^(.-)尾王$") or query:match("^(.-)最终boss$")
        or query:match("^(.-)%s+final%s+boss$") or query:match("^(.-)%s+last%s+boss$")
    if finalDungeon then finalDungeon=finalDungeon:match("^%s*(.-)%s*$");if finalDungeon=="" then finalDungeon=nil end end
    local terms=N:Terms(query)
    local numeric=tonumber(query)
    local exactEntity=false
    local selected,pending,fields={},{},{}
    local scratch,aliases={},{} -- Borrowed only by this query, including across coroutine yields.
    local awaiting,scanning,closed,loadedDuringScan=0,false,false,false
    local eventToken,deadline,task
    local limit=math.max(1,math.min(20,request.limit or 20))
    local ranker=(request.preferredEntryID or request.ranking) and assert(_G.Lychee.SDK.CreateRanker(request))
    local function dispose()
        closed=true;selected,pending,fields,scratch,aliases=nil,nil,nil,nil,nil
        if eventToken then eventToken:Cancel();eventToken=nil end
        if deadline then deadline:Cancel();deadline=nil end
        if task then task:Cancel();task=nil end
    end
    local owned=resources:Own("reference-query",dispose)
    if not owned then reply({});return end
    local function finish()
        if closed then return end
        local rows={}
        for _,row in ipairs(selected) do rows[#rows+1]=M:Record(row.enemy,row.dungeon,row.spellID) end
        dispose();reply(rows)
    end
    local function field(kind,value)
        if value and value~="" then
            local n=#fields;fields[n+1],fields[n+2],fields[n+3]=kind,value,N:Normalize(value,false)
        end
    end
    local function add(enemy,dungeon,rank,spellID)
        if not rank then return end
        local key=dungeon.id.."/"..enemy.id..(spellID and "/"..spellID or "")
        if ranker and rank<=1 then rank=ranker(key,rank) end
        local at=#selected+1
        for index,row in ipairs(selected) do
            if rank>row.rank or rank==row.rank and key<row.key then at=index;break end
        end
        if at<=limit then
            local row=#selected==limit and table.remove(selected) or {enemy={}}
            -- Never let a candidate retain the borrowed scan record.
            local copy=row.enemy
            copy.id,copy.name,copy.nameZh=enemy.id,enemy.name,enemy.nameZh
            copy.isBoss,copy.bossOrder=enemy.isBoss,enemy.bossOrder
            row.dungeon,row.rank,row.spellID,row.key=dungeon,rank,spellID,key
            table.insert(selected,at,row)
        end
    end
    local run
    local function work(scanSkills,requestMissing)
        selected={}
        local batch,started=0,now()
        local function checkpoint()
            batch=batch+1
            if batch>=128 or now()-started>=1 then coroutine.yield();batch,started=0,now() end
        end
        local finalEnemy,finalInfo,finalOrder
        local function visit(enemy,dungeon)
            if finalDungeon then
                if enemy.bossOrder and enemy.bossOrder>(finalOrder or 0)
                    and (finalDungeon==N:Normalize(dungeon.shortZh,false) or finalDungeon==N:Normalize(dungeon.nameZh,false) or finalDungeon==N:Normalize(dungeon.name,false)) then
                    finalEnemy=finalEnemy or {}
                    finalEnemy.id,finalEnemy.name,finalEnemy.nameZh=enemy.id,enemy.name,enemy.nameZh
                    finalEnemy.isBoss,finalEnemy.bossOrder=enemy.isBoss,enemy.bossOrder
                    finalInfo,finalOrder=dungeon,enemy.bossOrder
                end
                checkpoint();return
            end
            for i=#fields,1,-1 do fields[i]=nil end
            field("title",M:Name(enemy))
            for index,alias in ipairs(M:Aliases(enemy,dungeon,aliases)) do
                field("alias",alias)
                if (index<=3 or index>=7) and query==N:Normalize(alias,false) then exactEntity=true end
            end
            local base=#fields
            local rank=query=="" and 0 or N:ScoreCompiled(query,fields,terms,false)
            local best,bestSpell=rank,nil
            local bestRank=ranker and ranker(dungeon.id.."/"..enemy.id,rank) or rank
            if scanSkills then for spellText in enemy.spellIDs:gmatch("%d+") do
                local spellID=tonumber(spellText)
                if not numeric or numeric==spellID then
                    local name=M:SpellName(spellID)
                    if not name and requestMissing and not numeric and pending[spellID]==nil and C_Spell and C_Spell.RequestLoadSpellData and eventToken then
                        pending[spellID]=true;awaiting=awaiting+1
                        local ok=pcall(C_Spell.RequestLoadSpellData,spellID)
                        if not ok and pending[spellID]==true then pending[spellID]=false;awaiting=awaiting-1 end
                    end
                    field("alias",name);field("alias",spellText)
                    local score=query~="" and N:ScoreCompiled(query,fields,terms,false) or nil
                    local weighted=score and (ranker and ranker(dungeon.id.."/"..enemy.id.."/"..spellID,score) or score)
                    if weighted and (not bestRank or weighted>bestRank) then best,bestSpell,bestRank=score,spellID,weighted end
                    for i=#fields,base+1,-1 do fields[i]=nil end
                end
                checkpoint()
            end end
            add(enemy,dungeon,best,bestSpell);checkpoint()
        end
        for _,id in ipairs(M.dungeonIDs) do
            finalOrder,finalInfo=0,nil
            M:ScanDungeon(id,visit,scratch)
            if finalInfo then add(finalEnemy,finalInfo,1000,nil) end
        end
    end
    run=function(scanSkills,requestMissing)
        if closed then return end
        scanning=true
        local token=resources:Run("reference-scan",function() work(scanSkills,requestMissing) end,{
            complete=function()
                scanning=false
                if not scanSkills then
                    if finalDungeon or exactEntity or query=="" then finish() else run(true,true) end
                elseif requestMissing and awaiting==0 and loadedDuringScan then run(true,false)
                elseif not requestMissing or awaiting==0 then finish()
                else
                    deadline=resources:After("reference-load-deadline",2,function() run(true,false) end)
                    if not deadline then finish() end
                end
            end,
            error=function() dispose();reply({}) end,
            combat=function() dispose();reply({}) end,
        })
        task=token
        if not token then dispose();reply({}) end
    end
    eventToken=resources:OnEvent("SPELL_DATA_LOAD_RESULT",function(_,id)
        if closed or pending[id]~=true then return end
        pending[id]=false;awaiting=awaiting-1
        loadedDuringScan=true
        if awaiting==0 and not scanning then
            if deadline then deadline:Cancel();deadline=nil end
            run(true,false)
        end
    end)
    run(false,false)
    return dispose
end
