GetLocale=function() return "enUS" end
GetBuildInfo=function() return "12.1.0","70000","",120100 end
InCombatLockdown=function() return false end
C_Timer={NewTimer=function() return {Cancel=function() end} end}
dofile("tests/support/runtime.lua").Load("provider",{"Search/ProviderPolicy.lua"})
local I=LycheeInternal;I.Registry:SetReady(true)
local description={key="DESCRIPTION"}
local locales={enUS={DESCRIPTION="Original description"},zhCN={DESCRIPTION="Original translated description"}}
local handle,err=Lychee:RegisterProvider({id="fixture.metadata",apiVersion="1.0.0",version="1.0.0",title="Metadata",
    description=description,i18n=locales,entries={{id="one",title="One"}}})
assert(handle,err and err.code)
local token=assert(I.ProviderManagement:GetInstance(handle.id))
local function read() return assert(I.ProviderManagement:Read(handle.id,token)) end
assert(read().description=="Original description","management text must be resolved before reaching FontString:SetText")
description.key="changed";locales.enUS.DESCRIPTION="Changed externally"
assert(read().description=="Original description","caller edits must not change accepted provider metadata")
assert(handle:SetAvailability(false,"Dependency not available"))
local row=read()
assert(row.status=="owner-disabled" and row.statusReason=="Dependency not available")
for _,bad in ipairs({true,7,{},string.rep("x",257)}) do
    local ok,why=handle:SetAvailability(true,bad)
    assert(not ok and type(why)=="table","bad reason must fail without changing availability")
    row=read();assert(row.status=="owner-disabled" and row.statusReason=="Dependency not available")
end
assert(handle:SetAvailability(false,string.rep("x",256)))
assert(read().statusReason==string.rep("x",256))
assert(handle:SetAvailability(true))
assert(read().ownerEnabled==true and read().statusReason==nil,"restoring availability clears its old reason")
assert(handle:SetAvailability(false))
assert(read().statusReason==nil,"omitted reason must not resurrect an earlier reason")
assert(handle:SetAvailability(true))
for _,field in ipairs({"source","order"}) do
    local definition={id="fixture.unsupported",apiVersion="1.0.0",version="1",title="Unsupported",entries={{id="one",title="One"}}}
    definition[field]=field=="source" and {id="example",title="Example"} or 1
    local registered,problem=Lychee:RegisterProvider(definition)
    assert(not registered and problem.code=="INVALID_SCHEMA","undocumented management fields must remain rejected")
end
print("Provider metadata PASS: localized isolated description, bounded availability reason, atomic rejection and explicit unsupported fields")
