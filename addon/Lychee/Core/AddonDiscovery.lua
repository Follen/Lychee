local I = _G.LycheeInternal
local D = { packages = {}, definitions = {}, byID = {}, listeners = {}, index = 1, packageCount = 0 }
I.AddonDiscovery = D

-- This is a cold, bounded declaration index. It never evaluates addon code.
local MAX_PACKAGES, MAX_PROVIDERS, MAX_PER_PACKAGE = 128, 256, 16
local MAX_ROW, MAX_PACKAGE, MAX_WAITERS = 4096, 65536, 64
local products = { retail = true, classic = true, titan = true, anniversary = true }
local allowed = { title=true, description=true, global=true, prefixes=true, keywords=true,
    ranges=true, icon=true, requires=true, optional=true, purpose=true }
for _, locale in ipairs({ "enGB", "zhCN", "zhTW" }) do
    allowed["title." .. locale], allowed["description." .. locale] = true, true
end
local function errorValue(code, field) return { code = code, field = field, retryable = code == "DISCOVERY_PENDING" } end
local function time() return I.Providers and I.Providers:QueryTime() or 0 end
local function cancel(timer) if timer and type(timer.Cancel) == "function" then pcall(timer.Cancel, timer) end end
local function id(value) return type(value)=="string" and #value>0 and #value<=64 and value:match("^[a-z0-9][a-z0-9%.%-]*$") end
local function addonName(value)
    return type(value)=="string" and #value>0 and #value<=128 and not value:find("[%c%s/\\:;=,%%]") and value~="." and value~=".."
end
local function split(value, separator, limit, empty)
    if type(value)~="string" then return end
    if value=="" then return empty and {} or nil end
    local out, start = {}, 1
    while true do
        if #out>=limit then return end
        local at=value:find(separator,start,true)
        local word=value:sub(start,at and at-1 or #value)
        if word=="" then return end
        out[#out+1]=word
        if not at then return out end
        start=at+#separator
    end
end
local function utf8(value)
    local at, length=1,#value
    while at<=length do
        local byte=value:byte(at)
        if byte<32 or byte==127 then return false end
        if byte<128 then at=at+1
        else
            local count=byte>=194 and byte<=223 and 1 or byte>=224 and byte<=239 and 2 or byte>=240 and byte<=244 and 3
            if not count or at+count>length then return false end
            local second=value:byte(at+1)
            if (byte==224 and second<160) or (byte==237 and second>=160)
                or (byte==240 and second<144) or (byte==244 and second>=144) then return false end
            for offset=1,count do local nextByte=value:byte(at+offset);if nextByte<128 or nextByte>191 then return false end end
            at=at+count+1
        end
    end
    return true
end
local function decode(value, max, nonempty)
    if type(value)~="string" or #value>max*3 or value:find(",",1,true) then return end
    local at=1
    while true do
        at=value:find("%",at,true)
        if not at then break end
        if not value:sub(at+1,at+2):match("^[0-9A-F][0-9A-F]$") then return end
        at=at+3
    end
    value=value:gsub("%%([0-9A-F][0-9A-F])",function(hex) return string.char(tonumber(hex,16)) end)
    if #value>max or (nonempty and value=="") or not utf8(value) then return end
    return value
end
local function terms(value, keyword)
    local list=split(value or "",",",8,true)
    if not list then return end
    local seen={}
    for index,word in ipairs(list) do
        word=decode(word,48,true)
        if not word then return end
        word=word:lower():match("^%s*(.-)%s*$")
        if not keyword and I.Search and I.Search.Normalizer then word=I.Search.Normalizer:Normalize(word) end
        if word=="" or word:find("[%s%c|:,]") or word:find("：",1,true) or word:find("，",1,true) or seen[word] then return end
        list[index],seen[word]=word,true
    end
    return list
end
local function dependencies(value)
    local list=split(value or "",",",8,true)
    if not list then return end
    local seen={}
    for index,name in ipairs(list) do
        name=decode(name,128,true)
        if not addonName(name) or seen[name] then return end
        list[index],seen[name]=name,true
    end
    return list
end
local function numeric(value)
    if type(value)~="string" or not value:match("^%d+$") or #value>7 then return end
    local number=tonumber(value)
    if number and number<=9999999 then return number end
end
local function ranges(value)
    local list=split(value,",",8)
    if not list then return end
    local out={}
    for _,word in ipairs(list) do
        local parts=split(word,":",5)
        if not parts or #parts~=5 or not products[parts[1]] then return end
        local row={product=parts[1],minInterface=numeric(parts[2]),maxInterface=numeric(parts[3]),minBuild=numeric(parts[4]),maxBuild=numeric(parts[5])}
        if not row.minInterface or not row.maxInterface or not row.minBuild or not row.maxBuild
            or row.minInterface>row.maxInterface or row.minBuild>row.maxBuild then return end
        for _,old in ipairs(out) do
            if old.product==row.product and old.minInterface<=row.maxInterface and row.minInterface<=old.maxInterface
                and old.minBuild<=row.maxBuild and row.minBuild<=old.maxBuild then return end
        end
        out[#out+1]=row
    end
    return out
end
local function resource(value, owner)
    value=decode(value,256,true)
    if not value then return end
    local kind,body=value:match("^([a-z]+):(.+)$")
    if kind=="addon" then
        if body:find("[\\:%%]") or body:sub(1,1)=="/" then return end
        local parts=split(body,"/",32)
        if not parts then return end
        for _,part in ipairs(parts) do if part=="." or part==".." or part:find('[<>"|?*]') or part:find("[%.%s]$") then return end end
        return {kind="addon",path=body},"Interface\\AddOns\\"..owner.."\\"..body:gsub("/","\\")
    elseif kind=="file" then
        local number=body:match("^%d+$") and tonumber(body)
        if not number or number<=0 or number>2147483647 then return end
        return {kind="file",id=number},number
    elseif kind=="atlas" and #body<=128 and body:match("^[%w_%-]+$") then return {kind="atlas",name=body} end
end
local function client()
    local identity=I.Search and I.Search.RuntimeIdentity
    return identity and identity:Current() or {product="unknown",interface=0,build=0,locale="enUS"}
end
local function matches(row, current)
    local build,interface=tonumber(current.build),tonumber(current.interface)
    return row.product==current.product and build and interface and interface>=row.minInterface and interface<=row.maxInterface
        and build>=row.minBuild and build<=row.maxBuild
end
local function parse(raw, owner, providerID)
    if type(raw)~="string" or #raw>MAX_ROW then return nil,"DECLARATION_LIMIT" end
    local fields=split(raw,";",20)
    if not fields then return nil,"INVALID_DECLARATION" end
    local values={}
    for _,field in ipairs(fields) do
        local key,value=field:match("^([%w%.]+)=(.*)$")
        if not key or not allowed[key] or values[key]~=nil or value:find("=",1,true) then return nil,"INVALID_DECLARATION" end
        values[key]=value
    end
    local titles,descriptions={},{}
    for _,locale in ipairs({"enUS","enGB","zhCN","zhTW"}) do
        local suffix=locale=="enUS" and "" or "."..locale
        if values["title"..suffix] then
            titles[locale]=decode(values["title"..suffix],1024,true)
            if not titles[locale] then return nil,"INVALID_DECLARATION" end
        end
        if values["description"..suffix] then
            descriptions[locale]=decode(values["description"..suffix],1024,false)
            if not descriptions[locale] then return nil,"INVALID_DECLARATION" end
        end
    end
    if not titles.enUS or (values.global~="0" and values.global~="1") then return nil,"INVALID_DECLARATION" end
    local prefixes,keywords,scopeRanges=terms(values.prefixes),terms(values.keywords,true),ranges(values.ranges)
    local required,optional=dependencies(values.requires),dependencies(values.optional)
    if not prefixes or not keywords or not scopeRanges or not required or not optional then return nil,"INVALID_DECLARATION" end
    if values.global=="0" and #prefixes==0 and #keywords==0 then return nil,"INVALID_DECLARATION" end
    local purpose=values.purpose and decode(values.purpose,256,true)
    if values.purpose and not purpose then return nil,"INVALID_DECLARATION" end
    local image,icon
    if values.icon then image,icon=resource(values.icon,owner);if not image then return nil,"INVALID_RESOURCE" end end
    local current,selected=client()
    for _,row in ipairs(scopeRanges) do if matches(row,current) then selected=row end end
    local family=type(current.locale)=="string" and current.locale:sub(1,2)=="zh" and "zhCN" or "enUS"
    local result={id=providerID,addon=owner,title=titles[current.locale] or titles[family] or titles.enUS,
        description=descriptions[current.locale] or descriptions[family] or descriptions.enUS,titles=titles,descriptions=descriptions,
        searchGlobal=values.global=="1",searchPrefixes=prefixes,searchKeywords=keywords,ranges=scopeRanges,
        resource=image,icon=icon,requires=required,optional=optional,purpose=purpose,selected=selected,
        status=selected and "cold" or "unsupported",reason=not selected and "UNSUPPORTED_CLIENT" or nil}
    if selected then result.scope={products={selected.product},minInterface=selected.minInterface,maxInterface=selected.maxInterface,minBuild=selected.minBuild,maxBuild=selected.maxBuild} end
    return result
end
local function meta(name,key)
    local ok,value=pcall(C_AddOns.GetAddOnMetadata,name,key)
    if ok and type(value)=="string" and value~="" then return value end
end
local function mark(row,reason) row.status,row.reason="failed",reason end
local function readPackage(index)
    local ok,name=pcall(C_AddOns.GetAddOnInfo,index)
    if not ok or not addonName(name) then return end
    local protocol=meta(name,"X-Lychee-Protocol")
    local identity,raw=meta(name,"X-Lychee-Package"),meta(name,"X-Lychee-Providers")
    if not protocol and not identity and not raw then return end
    D.packageCount=D.packageCount+1
    if D.packageCount>MAX_PACKAGES then return "DISCOVERY_LIMIT" end
    local package={name=name,providers={}}
    D.packages[name]=package
    local ids=raw and #raw<=MAX_PER_PACKAGE*65 and split(raw,",",MAX_PER_PACKAGE)
    if not ids then package.reason="INVALID_DECLARATION";return end
    if protocol~="1" or identity~=name then package.reason="INVALID_DECLARATION" end
    local seen,bytes={},#(protocol or "")+#(identity or "")+#raw
    for _,providerID in ipairs(ids) do
        if not id(providerID) or seen[providerID] then package.reason="INVALID_DECLARATION";break end
        seen[providerID]=true
        local rowText=meta(name,"X-Lychee-Provider-"..providerID)
        if rowText then bytes=bytes+#rowText end
        if bytes>MAX_PACKAGE then package.reason="DECLARATION_LIMIT";break end
        local row,reason=parse(rowText,name,providerID)
        if not row then row={id=providerID,addon=name,status="failed",reason=reason};package.reason=reason end
        package.providers[#package.providers+1]=row
    end
    for _,row in ipairs(package.providers) do
        if #D.definitions>=MAX_PROVIDERS then return "DISCOVERY_LIMIT" end
        if package.reason then mark(row,package.reason) end
        D.definitions[#D.definitions+1]=row
        local old=D.byID[row.id]
        if old then mark(old,"DUPLICATE_PROVIDER");mark(row,"DUPLICATE_PROVIDER") else D.byID[row.id]=row end
    end
end
local function finishScan(reason)
    D.complete,D.error=true,reason
    D.timerEpoch=(D.timerEpoch or 0)+1
    local timer=D.timer;D.timer=nil;D.running=nil;D.demand=nil
    cancel(timer)
    if not reason then
        local prefixOwners,keywordOwners={},{}
        for _,row in ipairs(D.definitions) do
            if row.selected and (not row.reason or row.reason=="ROUTE_CONFLICT") then
                for _,pair in ipairs({{row.searchPrefixes,prefixOwners},{row.searchKeywords,keywordOwners}}) do
                    for _,word in ipairs(pair[1] or {}) do
                        local old=pair[2][word]
                        if old and old.id~=row.id then mark(old,"ROUTE_CONFLICT");mark(row,"ROUTE_CONFLICT") else pair[2][word]=row end
                    end
                end
            end
        end
    end
    local listeners=D.listeners;D.listeners={}
    for _,listener in ipairs(listeners) do
        local callback=listener.callback;listener.callback=nil
        if callback then pcall(callback,{complete=true,error=reason}) end
    end
end
local function scanBatch()
    D.timer=nil
    if D.complete or (not D.demand and #D.listeners==0) then D.running=nil;return end
    local start,count=time(),0
    while D.index<=D.count do
        local reason=readPackage(D.index)
        D.index=D.index+1;count=count+1
        if reason then finishScan(reason);return end
        if count>=32 or time()-start>=0.001 then break end
    end
    if D.index>D.count then finishScan();return end
    if not C_Timer or type(C_Timer.NewTimer)~="function" then finishScan("SCHEDULER_UNAVAILABLE");return end
    D.timerEpoch=(D.timerEpoch or 0)+1
    local epoch=D.timerEpoch
    local ok,timer=pcall(C_Timer.NewTimer,0,function() if D.timerEpoch==epoch then scanBatch() end end)
    if not ok or not timer or type(timer.Cancel)~="function" then finishScan("SCHEDULER_UNAVAILABLE");return end
    if not D.complete and D.running then D.timer=timer else cancel(timer) end
end
function D:Scan(callback)
    if callback~=nil and type(callback)~="function" then return nil,errorValue("INVALID_CALLBACK") end
    if #self.listeners>=MAX_WAITERS then return nil,errorValue("RESOURCE_LIMIT") end
    local listener={callback=callback}
    local token={}
    function token:Cancel()
        listener.callback=nil
        for at,row in ipairs(D.listeners) do if row==listener then table.remove(D.listeners,at);break end end
        if #D.listeners==0 and not D.demand then local timer=D.timer;D.timer=nil;D.running=nil;D.timerEpoch=(D.timerEpoch or 0)+1;cancel(timer) end
        return true
    end
    if self.complete then if callback then pcall(callback,{complete=true,error=self.error}) end;listener.callback=nil;return token end
    if callback then self.listeners[#self.listeners+1]=listener else self.demand=true end
    if not self.count then
        if not C_AddOns or type(C_AddOns.GetNumAddOns)~="function" or type(C_AddOns.GetAddOnInfo)~="function" or type(C_AddOns.GetAddOnMetadata)~="function" then
            self.count=0
        else
            local ok,count=pcall(C_AddOns.GetNumAddOns)
            if not ok or type(count)~="number" or count<0 or count%1~=0 or count>1000000 then finishScan("DISCOVERY_UNAVAILABLE");return token end
            self.count=count
        end
    end
    if not self.running then self.running=true;scanBatch() end
    return token
end
function D:Get(providerID) return self.byID[providerID] end
function D:Definitions() return self.definitions end
local function sameResource(first,second)
    if first==nil or second==nil then return first==second end
    if type(second)~="table" or getmetatable(second)~=nil then return false end
    for key,value in pairs(first) do if second[key]~=value then return false end end
    for key in pairs(second) do if first[key]==nil then return false end end
    return true
end
local function sameTerms(first,second,keyword)
    second=second or {}
    if type(second)~="table" or #first~=#second then return false end
    for key in pairs(second) do if type(key)~="number" or key%1~=0 or key<1 or key>#second then return false end end
    for at,value in ipairs(second) do
        if type(value)~="string" then return false end
        value=value:lower():match("^%s*(.-)%s*$")
        if not keyword and I.Search and I.Search.Normalizer then value=I.Search.Normalizer:Normalize(value) end
        if first[at]~=value then return false end
    end
    return true
end
local function textValue(value,definition)
    if type(value)=="string" then return value end
    if type(value)=="table" and type(value.key)=="string" and type(definition.i18n)=="table" then
        local locale=client().locale
        local family=type(locale)=="string" and locale:sub(1,2)=="zh" and "zhCN" or "enUS"
        local dictionary=definition.i18n[locale] or definition.i18n[family] or definition.i18n.enUS
        return dictionary and dictionary[value.key] or definition.i18n.enUS and definition.i18n.enUS[value.key]
    end
end
function D:ValidateRegistration(definition)
    if type(definition)~="table" or not id(definition.id) then return nil,errorValue("INVALID_SCHEMA","id") end
    self:Scan()
    if not self.complete then return nil,errorValue("DISCOVERY_PENDING") end
    if self.error then return nil,errorValue(self.error) end
    local row=self.byID[definition.id]
    local package=definition.addon and self.packages[definition.addon]
    if package and package.reason then return nil,errorValue(package.reason,"addon") end
    if not row then
        if package then return nil,errorValue("UNDECLARED_PROVIDER","id") end
        if definition.addon~=nil then return nil,errorValue("UNDECLARED_ADDON","addon") end
        return true -- Existing, already loaded API 1.0.0 packages have no cold declaration.
    end
    if row.reason then return nil,errorValue(row.reason,"id") end
    if definition.addon~=row.addon then return nil,errorValue("ADDON_MISMATCH","addon") end
    local scope,selected=definition.scope,row.selected
    if type(scope)~="table" or type(scope.products)~="table" or #scope.products~=1 or scope.products[1]~=selected.product then return nil,errorValue("SCOPE_MISMATCH","scope.products") end
    for key in pairs(scope.products) do if key~=1 then return nil,errorValue("SCOPE_MISMATCH","scope.products") end end
    for _,pair in ipairs({{"minInterface",0},{"maxInterface",9999999},{"minBuild",0},{"maxBuild",9999999}}) do
        local value=scope[pair[1]]
        if value==nil then value=pair[2] end
        if type(value)~="number" or value%1~=0 or value<0 or value>9999999 then return nil,errorValue("SCOPE_MISMATCH","scope."..pair[1]) end
        if pair[1]:sub(1,3)=="min" and value<selected[pair[1]] or pair[1]:sub(1,3)=="max" and value>selected[pair[1]] then return nil,errorValue("SCOPE_MISMATCH","scope."..pair[1]) end
    end
    local hot={product=scope.products[1],minInterface=scope.minInterface or 0,maxInterface=scope.maxInterface or 9999999,minBuild=scope.minBuild or 0,maxBuild=scope.maxBuild or 9999999}
    if not matches(hot,client()) or (scope.locale and scope.locale~=client().locale) then return nil,errorValue("SCOPE_MISMATCH","scope") end
    if textValue(definition.title,definition)~=row.title then return nil,errorValue("DECLARATION_MISMATCH","title") end
    if row.description and textValue(definition.description,definition)~=row.description then return nil,errorValue("DECLARATION_MISMATCH","description") end
    if (definition.searchGlobal~=false)~=row.searchGlobal or not sameTerms(row.searchPrefixes,definition.searchPrefixes) or not sameTerms(row.searchKeywords,definition.searchKeywords,true) then return nil,errorValue("DECLARATION_MISMATCH","search") end
    if not sameResource(row.resource,definition.resource) then return nil,errorValue("RESOURCE_MISMATCH","resource") end
    if definition.icon~=nil and definition.icon~=row.icon then return nil,errorValue("RESOURCE_MISMATCH","icon") end
    return true
end
function D:Registered(providerID,entry)
    local row=self.byID[providerID]
    if row and not row.reason then row.entry=entry;row.status=entry and "registered" or "cold" end
    if I.AddonLoader then I.AddonLoader:Registered(providerID,entry) end
end
function D:Availability(row)
    if not row then return nil,"UNKNOWN_PROVIDER" end
    if row.reason then return nil,row.reason end
    if not C_AddOns or type(C_AddOns.GetAddOnEnableState)~="function" or type(C_AddOns.IsAddOnLoadable)~="function" then return nil,"UNSUPPORTED_CLIENT" end
    local character=type(UnitGUID)=="function" and UnitGUID("player")
    if not character or character=="" then return nil,"CHARACTER_UNAVAILABLE" end
    local ok,state=pcall(C_AddOns.GetAddOnEnableState,row.addon,character)
    if not ok or type(state)~="number" then return nil,"ADDON_STATE_UNAVAILABLE" end
    if state==0 then return nil,"ADDON_DISABLED" end
    for _,name in ipairs(row.requires or {}) do
        local exists,actual=pcall(C_AddOns.GetAddOnInfo,name)
        if not exists or not actual then return nil,"DEPENDENCY_MISSING" end
        local enabled,value=pcall(C_AddOns.GetAddOnEnableState,name,character)
        if not enabled or not value or value==0 then return nil,"DEPENDENCY_DISABLED" end
    end
    local checked,loadable,reason=pcall(C_AddOns.IsAddOnLoadable,row.addon,character,true)
    if not checked then return nil,"ADDON_STATE_UNAVAILABLE" end
    if not loadable then return nil,type(reason)=="string" and reason~="" and reason or "ADDON_UNLOADABLE" end
    return true
end
