-- Cold declarations enter through native metadata and the public registration seam.
local function package(name, ids, rows)
    local metadata={ ["X-Lychee-Protocol"]="1",["X-Lychee-Package"]=name,["X-Lychee-Providers"]=table.concat(ids,",") }
    for index,providerID in ipairs(ids) do metadata["X-Lychee-Provider-"..providerID]=rows[index] end
    return {name=name,metadata=metadata}
end
local base="title=Equipment;title.zhCN=%E8%A3%85%E5%A4%87;global=1;prefixes=gear;keywords=equipment;ranges=retail:120100:120199:0:9999999;icon=addon:Media/equipment.tga;requires=Lychee"
local function setup(packages, identity)
    local environment={timers={},info=0,metadata=0,now=0,step=0}
    local map={Lychee={name="Lychee",metadata={}}}
    for _,row in ipairs(packages) do map[row.name]=row end
    _G.LycheeInternal={Providers={entries={},QueryTime=function() local current=environment.now;environment.now=environment.now+environment.step;return current end},
        Search={RuntimeIdentity={Current=function() return identity or {product="retail",interface=120100,build="70000",locale="enUS"} end}}}
    local I=LycheeInternal
    C_Timer={NewTimer=function(delay,callback)
        local token={delay=delay,callback=callback,Cancel=function(self) self.cancelled=true end}
        environment.timers[#environment.timers+1]=token;return token
    end}
    C_AddOns={GetNumAddOns=function() return #packages end,
        GetAddOnInfo=function(value) environment.info=environment.info+1;local row=type(value)=="number" and packages[value] or map[value];return row and row.name end,
        GetAddOnMetadata=function(name,key) environment.metadata=environment.metadata+1;return map[name] and map[name].metadata[key] end,
        GetAddOnEnableState=function(name,character) assert(character=="Player-1-ABC");return map[name] and not map[name].disabled and 2 or 0 end,
        IsAddOnLoadable=function(name,character,demand) assert(character=="Player-1-ABC" and demand==true);return not map[name].unloadable,map[name].unloadable end}
    UnitGUID=function(unit) assert(unit=="player");return "Player-1-ABC" end
    CreateFrame=function() error("discovery may not create frames") end
    dofile("addon/Lychee/Core/AddonDiscovery.lua")
    Lychee={RegisterProvider=function(_,definition)
        local ok,err=I.AddonDiscovery:ValidateRegistration(definition)
        if not ok then return nil,err end
        local entry={id=definition.id,definition=definition}
        I.Providers.entries[entry.id]=entry
        I.AddonDiscovery:Registered(entry.id,entry)
        return entry
    end}
    function environment:Drain()
        local timers=self.timers;self.timers={}
        for _,timer in ipairs(timers) do if not timer.cancelled then timer.callback() end end
    end
    environment.map=map
    return I.AddonDiscovery,environment
end
local function definition()
    return {id="abc.equipment",addon="ABC_Lychee",title="Equipment",apiVersion="1.0.0",version="1",
        scope={products={"retail"},minInterface=120100,maxInterface=120199,minBuild=0,maxBuild=9999999},
        i18n={enUS={NAME="Equipment"}},searchGlobal=true,searchPrefixes={"gear"},searchKeywords={"equipment"},
        resource={kind="addon",path="Media/equipment.tga"},query=function() end}
end
local function rejected(def,code)
    local accepted,err=Lychee:RegisterProvider(def)
    assert(not accepted and err.code==code,"expected "..code..", got "..tostring(err and err.code))
end

local D,env=setup({package("ABC_Lychee",{"abc.equipment","abc.status"},{base,"title=Status;global=0;prefixes=status;keywords=;ranges=retail:120100:120199:0:9999999;icon=file:134400"})})
assert(env.info==0 and env.metadata==0,"TOC evaluation must not scan")
local completed=0
assert(D:Scan(function(result) assert(result.complete and not result.error);completed=completed+1 end))
assert(completed==1 and #D:Definitions()==2)
local equipment=D:Get("abc.equipment")
assert(equipment.addon=="ABC_Lychee" and equipment.title=="Equipment" and equipment.icon=="Interface\\AddOns\\ABC_Lychee\\Media\\equipment.tga")
assert(equipment.scope.minInterface==120100 and equipment.searchPrefixes[1]=="gear")
local first=assert(Lychee:RegisterProvider(definition()))
assert(equipment.entry==first and equipment.status=="registered")
local reads=env.info+env.metadata
D:Scan();D:Get("abc.equipment");D:Definitions();assert(env.info+env.metadata==reads,"warm access must not rescan")
local bad=definition();bad.addon=nil;rejected(bad,"ADDON_MISMATCH")
bad=definition();bad.scope.maxInterface=120200;rejected(bad,"SCOPE_MISMATCH")
bad=definition();bad.scope.products={"retail","classic"};rejected(bad,"SCOPE_MISMATCH")
bad=definition();bad.scope.minBuild=70001;rejected(bad,"SCOPE_MISMATCH")
bad=definition();bad.resource.path="../Lychee/Media/equipment.tga";rejected(bad,"RESOURCE_MISMATCH")
bad=definition();bad.icon="Interface\\AddOns\\Sibling\\Media\\equipment.tga";rejected(bad,"RESOURCE_MISMATCH")
bad=definition();bad.title="Other title";rejected(bad,"DECLARATION_MISMATCH")
bad=definition();bad.searchGlobal=false;rejected(bad,"DECLARATION_MISMATCH")
bad=definition();bad.id="abc.undeclared";rejected(bad,"UNDECLARED_PROVIDER")
bad=definition();bad.addon="Unknown";rejected(bad,"ADDON_MISMATCH")
assert(Lychee:RegisterProvider({id="old.provider",scope={products={"retail"}},title="Legacy"}),"undeclared old 1.0.0 remains supported")
assert(D:Availability(equipment))
env.map.ABC_Lychee.disabled=true;local _,reason=D:Availability(equipment);assert(reason=="ADDON_DISABLED")
env.map.ABC_Lychee.disabled=nil;env.map.Lychee=nil;_,reason=D:Availability(equipment);assert(reason=="DEPENDENCY_MISSING")

D=setup({package("ABC_Lychee",{"abc.equipment"},{base})},{product="retail",interface=120100,build=70000,locale="zhCN"})
D:Scan();assert(D:Get("abc.equipment").title=="装备")
bad=definition();bad.title={key="NAME"};bad.i18n.zhCN={NAME="装备"};assert(Lychee:RegisterProvider(bad))
for _,locale in ipairs({"zhTW","enGB"}) do
    D=setup({package("ABC_Lychee",{"abc.equipment"},{base})},{product="retail",interface=120100,build=70000,locale=locale})
    D:Scan();assert(D:Get("abc.equipment").title==(locale=="zhTW" and "装备" or "Equipment"))
    bad=definition();bad.title={key="NAME"};bad.i18n.zhCN={NAME="装备"};assert(Lychee:RegisterProvider(bad))
end

for _,range in ipairs({"retail:120100:120199:0:9999999,retail:120199:120300:0:9999999", "unknown:1:2:1:2", "retail:2:1:0:9999999", "retail:120100:120199:1.5:5"}) do
    D=setup({package("ABC_Lychee",{"abc.equipment"},{base:gsub("ranges=[^;]+","ranges="..range)})})
    D:Scan();rejected(definition(),"INVALID_DECLARATION")
end
for _,identity in ipairs({{product="retail",interface=120099,build=70000},{product="retail",interface=120200,build=70000},{product="unknown",interface=120100,build=70000}}) do
    D=setup({package("ABC_Lychee",{"abc.equipment"},{base})},identity);D:Scan();assert(D:Get("abc.equipment").reason=="UNSUPPORTED_CLIENT")
end
local twoRanges=base:gsub("ranges=[^;]+","ranges=retail:120100:120199:0:69999,retail:120100:120199:70000:9999999")
D=setup({package("ABC_Lychee",{"abc.equipment"},{twoRanges})});D:Scan();assert(D:Get("abc.equipment").selected.minBuild==70000)
bad=definition();rejected(bad,"SCOPE_MISMATCH");bad.scope.minBuild=70000;assert(Lychee:RegisterProvider(bad))

for _,row in ipairs({base..";global=1",base..";unknown=x",base:gsub("title=Equipment","title=%%GG"),base:gsub("title=Equipment","title=%%C0%%AF"),
    base:gsub("title=Equipment","title=%%00"),base:gsub("title=Equipment","title=Equipment,other"),(base:gsub("prefixes=gear","prefixes=gear,GEAR"))}) do
    D=setup({package("ABC_Lychee",{"abc.equipment"},{row})});D:Scan();rejected(definition(),"INVALID_DECLARATION")
end
for _,path in ipairs({"../bad.tga","/bad.tga","Media/../bad.tga","Media/.. /bad.tga","C:/bad.tga","Media//bad.tga","Media\\bad.tga","Media/%252E%252E/bad.tga"}) do
    D=setup({package("ABC_Lychee",{"abc.equipment"},{(base:gsub("addon:Media/equipment.tga",function() return "addon:"..path end))})})
    D:Scan();rejected(definition(),"INVALID_RESOURCE")
end
D=setup({package("ABC_Lychee",{"abc.equipment"},{string.rep("x",4097)})});D:Scan();rejected(definition(),"DECLARATION_LIMIT")
local invalidPackage=package("ABC_Lychee",{"abc.equipment"},{base});invalidPackage.metadata["X-Lychee-Protocol"]="2"
D=setup({invalidPackage});D:Scan();rejected(definition(),"INVALID_DECLARATION")
bad=definition();bad.addon=nil;rejected(bad,"INVALID_DECLARATION")
invalidPackage.metadata["X-Lychee-Protocol"]=nil
D=setup({invalidPackage});D:Scan();rejected(definition(),"INVALID_DECLARATION")
bad=definition();bad.addon=nil;rejected(bad,"INVALID_DECLARATION")
local other=base:gsub("prefixes=gear","prefixes=other"):gsub("keywords=equipment","keywords=other")
D=setup({package("ABC_Lychee",{"abc.equipment"},{base}),package("Other_Lychee",{"abc.equipment"},{other})});D:Scan()
assert(#D:Definitions()==2 and D:Definitions()[1].reason=="DUPLICATE_PROVIDER" and D:Definitions()[2].reason=="DUPLICATE_PROVIDER")
rejected(definition(),"DUPLICATE_PROVIDER")
D=setup({package("ABC_Lychee",{"abc.equipment"},{base}),package("Other_Lychee",{"other.equipment"},{base})});D:Scan()
assert(D:Get("abc.equipment").reason=="ROUTE_CONFLICT" and D:Get("other.equipment").reason=="ROUTE_CONFLICT")

local many={}
for index=1,80 do many[index]={name="Irrelevant"..index,metadata={}} end
many[80]=package("ABC_Lychee",{"abc.equipment"},{base})
D,env=setup(many)
local scan=assert(D:Scan(function() completed=completed+1 end))
assert(not D.complete and env.info==32 and #env.timers==1,"one batch is at most32 addons")
scan:Cancel();local old=env.timers[1];old.callback();assert(env.info==32,"late cancelled scan must not resume")
local count=completed
D:Scan(function() completed=completed+1 end);assert(env.info==64)
env:Drain();assert(D.complete and completed==count+1 and D:Get("abc.equipment"))
assert(Lychee:RegisterProvider(definition()))
D,env=setup(many);env.step=0.0006;D:Scan();assert(env.info<32,"one millisecond is also a yield boundary")
while not D.complete do env:Drain() end

many={}
for index=1,129 do many[index]=package("Package"..index,{"provider."..index},{"title=Test;global=1;ranges=retail:0:9999999:0:9999999"}) end
D,env=setup(many);D:Scan();while not D.complete do env:Drain() end
assert(D.error=="DISCOVERY_LIMIT" and #D:Definitions()==128,"package capacity must fail explicitly")
print("addon_discovery: public cold declaration, resources, collisions, ranges and bounded scan passed")
