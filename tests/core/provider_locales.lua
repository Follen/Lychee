local function load(locale)
    LycheeInternal={Locale={code=locale}}
    dofile("addon/Lychee/Providers/Definitions.lua")
    dofile("addon/Lychee/Providers/Shared/Support.lua")
    dofile("addon/Lychee/Core/ProviderLocales.lua")
    return LycheeInternal.ProviderLocales
end
local resources={enUS={name="Launcher",count="%d items: %s (%%)",unicode="中文"},zhCN={name="启动器",count="%d 个：%s (%%)"},zhTW={name="啟動器"},enGB={name="British"}}
for _,locale in ipairs({"enUS","enGB","zhCN","zhTW","frFR"}) do
    local p=load(locale);local t=assert(p:Compile(resources))
    local expected=locale=="zhCN" and "启动器" or locale=="zhTW" and "啟動器" or locale=="enGB" and "British" or "Launcher"
    assert(t:Text("name")==expected)
    assert(t:Text("unicode")=="中文")
    assert(t:Resolve({key="name"})==expected)
    assert(t:Resolve("name")=="name")
    local literal={text="Literal"};assert(t:Resolve(literal)==literal)
    assert(t:Text("count",2,"x")==((locale=="zhCN" or locale=="zhTW") and "2 个：x (%)" or "2 items: x (%)"))
    local missing,err=t:Text("missing");assert(not missing and err.code=="INVALID_LOCALE_KEY")
end
local p=load("enUS")
local a=assert(p:Compile({enUS={same="A"}}));local b=assert(p:Compile({enUS={same="B"}}));assert(a:Text("same")=="A" and b:Text("same")=="B")
local input={enUS={same="Before"}};local t=assert(p:Compile(input));input.enUS.same="After";assert(t:Text("same")=="Before")
local function invalid(data,code)
 local t,e=p:Compile(data);assert(not t and e.code==code,(e and e.code or "accepted").." expected "..code)
end
invalid({},"INVALID_LOCALES")
invalid(setmetatable({enUS={}},{__index={}}),"INVALID_LOCALES")
invalid({enUS={},deDE={}},"INVALID_LOCALES")
invalid({enUS={x="%d"},zhCN={x="%s"}},"INVALID_LOCALE_FORMAT")
invalid({enUS={x="broken %"}},"INVALID_LOCALE_FORMAT")
invalid({enUS={x="%1000d"}},"INVALID_LOCALE_FORMAT")
invalid({enUS={x="%.1000f"}},"INVALID_LOCALE_FORMAT")
invalid({enUS=setmetatable({},{})},"INVALID_LOCALES")
assert(p:Compile({enUS={x="%02d %.2f %q %%"},zhCN={x="%d %f %q %%"}}))
invalid({enUS={x="x"},zhCN={extra="x"}},"INVALID_LOCALE_KEY")
invalid({enUS={x=string.rep("a",1025)}},"INVALID_LOCALES")
invalid({enUS={[string.rep("a",97)]="x"}},"INVALID_LOCALES")
local over={enUS={}};for i=1,257 do over.enUS["key"..i]="x" end;invalid(over,"LOCALE_LIMIT")
over={enUS={}};for i=1,140 do over.enUS["key"..i]=string.rep("a",1024) end;invalid(over,"LOCALE_LIMIT")
LycheeInternal.ProviderLocaleData={["builtin.bags"]={enUS={["名字"]="Name"},zhCN={["名字"]="名字"}}}
local builtin=assert(p:Module("builtin.bags"));assert(builtin["名字"]=="Name" and builtin.resources==LycheeInternal.ProviderLocaleData["builtin.bags"])
assert(builtin["未知"]=="未知")
local bounded=assert(p:Compile({enUS={name="Name",text="%s",quoted=string.rep("%q",16),number="%.99f"}}))
for _,reference in ipairs({{key=""},{key=3},{key="name",locale="zhCN"},{key="name",scope={locale="zhCN"}},{key="name",[1]="extra"},setmetatable({key="name"},{})}) do
    local result,err=bounded:Resolve(reference)
    assert(not result and err.code=="INVALID_SCHEMA","invalid key reference must be rejected")
end
for _,literal in ipairs({{enUS="English",zhCN="中文"},{{text="English",locale="enUS",scope={locale="enUS"}}}}) do
    assert(bounded:Resolve(literal)==literal,"ordinary localized values retain their metadata")
end
invalid({enUS={x=string.rep("%s",17)}},"INVALID_LOCALE_FORMAT")
local originalFormat,formatCalls=string.format,0
string.format=function(...) formatCalls=formatCalls+1;return originalFormat(...) end
local function rejectedBeforeFormat(...)
    local beforeCalls=formatCalls
    local result,err=bounded:Text(...)
    assert(not result and err.code=="INVALID_LOCALE_FORMAT")
    assert(formatCalls==beforeCalls,"invalid input must not reach string.format")
end
rejectedBeforeFormat("text",string.rep("x",1025))
rejectedBeforeFormat("text",{})
rejectedBeforeFormat("text",true)
rejectedBeforeFormat("text",nil)
local args={};for i=1,17 do args[i]="x" end
rejectedBeforeFormat("text",unpack(args))
for i=1,16 do args[i]=string.rep("\0",1024) end;args[17]=nil
rejectedBeforeFormat("quoted",unpack(args))
assert(bounded:Text("text",string.rep("x",1024))==string.rep("x",1024))
assert(bounded:Format("text","ok")=="ok")
assert(#bounded:Text("number",1e308)<32768)
for i=1,16 do args[i]=string.rep("x",1024) end
assert(#bounded:Text("quoted",unpack(args))==16416)
string.format=originalFormat
collectgarbage("collect");local before=collectgarbage("count")
local translators={};for i=1,16 do translators[i]=assert(p:Compile(resources)) end
collectgarbage("collect");print(string.format("Provider locale PASS; 16 selected dictionaries retained %.1f KiB",collectgarbage("count")-before))
