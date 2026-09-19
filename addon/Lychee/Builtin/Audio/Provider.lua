local I=_G.LycheeInternal
local L=I.ProviderLocales:Builtin("builtin.blizzard-settings")
local A=I.Builtin.AudioAdapter
local language=I.Builtin.AudioLanguage
local M={id="builtin.blizzard-settings"}
I.Builtin.Audio=M
local icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga"
local schema={percent={type="integer",min=0,max=100,step=1,required=true}}
local function target(channel) return {version=1,key={channel=channel}} end
local function trim(text) return (text:gsub("^%s+",""):gsub("%s+$","")) end
local function contains(words,text)
    for _,word in ipairs(words) do if text==word then return true end end
    return false
end
local function takePrefix(text,word)
    if text:sub(1,#word)~=word then return nil end
    local rest=text:sub(#word+1)
    -- English words must not consume prefixes of other words (set/reset, etc.).
    if word:find("[a-z]$") and rest~="" and not rest:find("^[%s:]") then return nil end
    return trim(rest)
end
local function optionalPrefix(text,words)
    for _,word in ipairs(words) do
        local rest=takePrefix(text,word)
        if rest then return rest end
    end
    return text
end
local function stripSuffix(text,words)
    for _,word in ipairs(words) do
        if text:sub(-#word)==word then
            local rest=text:sub(1,#text-#word)
            if not word:find("^[a-z]") or rest=="" or rest:find("%s$") then return trim(rest) end
        end
    end
    return text
end
local function hasWord(text,word)
    if word:find("^[a-z]") then return text:find("%f[%a]"..word.."%f[%A]")~=nil end
    return text:find(word,1,true)~=nil
end
local function matchHead(head,tail,key)
    local grammar=language[key]
    head=optionalPrefix(head,grammar.polite)
    head=optionalPrefix(head,grammar.verb)
    head=optionalPrefix(head,grammar.subject)
    tail=stripSuffix(tail,grammar.suffix)
    if not contains(grammar.units,tail) then return nil end
    if grammar.valuePrefix and head:sub(-#grammar.valuePrefix)==grammar.valuePrefix then
        if tail~="" then return nil end -- Do not accept two percentage units.
        head=trim(head:sub(1,#head-#grammar.valuePrefix))
    end
    for _,spec in ipairs(language.targets) do
        for _,word in ipairs(spec[key]) do
            local rest=takePrefix(head,word)
            if rest and contains(grammar.connector,rest) then return spec.id end
        end
    end
end
function M:Parse(text,explicit)
    if type(text)~="string" or #text>1024 then return nil end
    local settingsLanguage=I.Builtin.SettingsLanguage
    if settingsLanguage then
        local parsed=settingsLanguage.Parse(text)
        if parsed and parsed.spec.channel and parsed.code=="MISSING_ARGS" then return parsed.spec.channel,nil,"INCOMPLETE_ARGS" end
        if parsed and parsed.spec.channel and parsed.operation=="number" then
            local value=parsed.args.value
            if value%1==0 and value>=0 and value<=100 then return parsed.spec.channel,value end
            return parsed.spec.channel,nil,"INVALID_ARGS"
        end
    end
    text=trim(text:lower():gsub("：",":"):gsub("％","%%"):gsub("%s+"," "))
    local channel,matched,count="master",explicit==true,0
    for _,spec in ipairs(language.targets) do
        local found=false
        for _,word in ipairs(language.words[spec.id]) do
            if hasWord(text,word) then
                matched=true
                if not language.generic[word] then found=true end
            end
        end
        if found then channel=spec.id;count=count+1 end
    end
    if not matched then return nil end
    if count>1 then return channel,nil,"AMBIGUOUS_TARGET" end
    local first,last,percent=text:find("([+-]?%d+%.?%d*)")
    if not first then return channel,nil,"MISSING_ARGS" end
    local head,tail=trim(text:sub(1,first-1)),trim(text:sub(last+1))
    local value=tonumber(percent)
    if percent:find("^[+-]") or not value or value%1~=0 or value<0 or value>100 or tail:find("%d") then
        return channel,nil,"INVALID_ARGS"
    end
    -- Match the entire request. Unknown, negated and relative phrases cannot
    -- become absolute commands just because they contain a channel and a number.
    local resolved=matchHead(head,tail,"zh") or matchHead(head,tail,"en")
    if not resolved and explicit and head=="" and contains(language.en.units,tail) then resolved=channel end
    if not resolved then return channel,nil,"INVALID_ARGS" end
    return resolved,value
end
local function entry(channel,percent,reason)
    local spec=A.byID[channel];local value=A.Read(channel)
    local command={kind="command",product="retail",providerID=M.id,actionID="set-volume",actionVersion=1,target=target(channel)}
    local result={id="volume:"..channel..(percent and ":"..percent or ""),title=percent and L:Format("%s设为 %d%%",L[spec.title],percent) or L[spec.title],
        kind="command",kindTitle=L["暴雪设置"],icon=icon,aliases={"音量","volume","audio",spec.title,channel},
        subtitle=reason=="AMBIGUOUS_TARGET" and L["请选择一个音量通道"] or reason and L["请输入 0–100 的整数百分比"] or value and (percent and percent~=value and L:Format("当前 %d%% → 设置为 %d%%",value,percent) or L:Format("当前 %d%%",value)) or L["音量暂不可用"],
        payload={channel=channel},actions=percent and {"set-volume","adjust-volume"} or {"adjust-volume"}}
    if percent then
        command.kind="invocation";command.args={percent=percent};result.invocation=command
    else result.command=command;result.invocationError={code=reason or "MISSING_ARGS",field="percent"} end
    return result
end
function M:Attach(owner)
    if owner.audioAttached then return end
    owner.audioAttached=true
    owner.actions["set-volume"]={title=L["设置音量"],actionVersion=1,absolute=true,conflictKey="setting",panel="controls",schema=schema,
        run=function(invocation) return A.Write(invocation.target.key.channel,invocation.args.percent) end}
    owner.actions["adjust-volume"]={title=L["直接调整"],run=function(record)
        local channel=record.payload and record.payload.channel
        if not A.byID[channel] then return {ok=false,code="AUDIO_UNAVAILABLE"} end
        return {ok=true,view="controls",state={channel=channel}}
    end}
    owner.resolveTarget=function(value)
        local id=type(value)=="table" and value.version==1 and type(value.key)=="table" and value.key.channel
        if A.Read(id)==nil then return {status="temporarilyUnavailable"} end
        return {status="ready",target=value,identity=A.byID[id].cvar}
    end
    owner.describe=function(value) return {available=A.Read(value.key.channel)~=nil,revision=1,schema=schema} end
    owner.observe=function(value,context,publish) return A.Observe(value.key.channel,publish) end
    owner.views={controls={create=I.Builtin.AudioView.Create,stateSchema={channel="string"}}}
    owner.query=function(request,reply)
        local channel,percent,reason=M:Parse(request.raw or request.normalized)
        -- A bare setting name is a normal catalog row, not a missing argument.
        local parsed=channel and reason~="MISSING_ARGS"
        reply(parsed and {entry(channel,percent,reason)} or {},parsed==true)
    end
    owner.resolve=function(id)
        local channel,value=id:match("^volume:([a-z]+):(%d+)$")
        if not A.byID[channel] then return nil end
        local percent=tonumber(value)
        if percent and (percent<0 or percent>100) then return nil end
        return entry(channel,percent)
    end
end
