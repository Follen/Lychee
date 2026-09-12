local I = _G.LycheeInternal
local P = {}
I.ProviderLocales = P
local locales = {enUS=true,enGB=true,zhCN=true,zhTW=true}
local function failure(code, field) return nil, {code=code,field=field} end
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
-- Compare argument conversion types, allowing presentation flags/width changes.
local function signature(value)
    local parts, widths, cursor, literalBytes = {}, {}, 1, 0
    while true do
        local at=value:find("%",cursor,true)
        if not at then literalBytes=literalBytes+#value-cursor+1;break end
        literalBytes=literalBytes+at-cursor
        if value:sub(at+1,at+1)=="%" then cursor=at+2;literalBytes=literalBytes+1
        else
            local flags,width,precision,token,ending=value:sub(at):match("^%%([-+ #0]*)(%d*)(%.?%d*)([cdiouxXeEfgGqs])()")
            if not token or #flags>5 or #width>2 or #precision>3 then return nil end
            parts[#parts+1]=token
            if #parts>16 then return nil end
            widths[#parts]=tonumber(width) or 0
            cursor=at+ending-1
        end
    end
    return table.concat(parts,","), #parts>0 and {tokens=parts,widths=widths,literalBytes=literalBytes} or nil
end
-- Lua's quoted strings may use four-byte decimal escapes for control bytes.
-- Count that conservative bound without constructing an escaped copy.
local function quotedBytes(value)
    local bytes=2
    for index=1,#value do
        local byte=value:byte(index)
        if byte<32 or byte==127 then bytes=bytes+4
        elseif byte==34 or byte==92 then bytes=bytes+2
        else bytes=bytes+1 end
    end
    return bytes
end
local Translator = {}
local translatorMeta={__index=Translator}
function Translator:Text(key, ...)
    local value=self.dictionary[key]
    if value==nil then return failure("INVALID_LOCALE_KEY", "i18n."..tostring(key)) end
    local count=select("#",...)
    if count==0 then return value end
    local plan=self.formatPlans[key]
    if count>16 or (plan and count<#plan.tokens) then return failure("INVALID_LOCALE_FORMAT","i18n."..key) end
    local upperBound=plan and plan.literalBytes or #value
    for index=1,count do
        local argument=select(index,...)
        local kind=type(argument)
        if (kind~="number" and kind~="string") or (kind=="string" and #argument>1024) then
            return failure("INVALID_LOCALE_FORMAT","i18n."..key)
        end
        local token=plan and plan.tokens[index]
        if token then
            -- IEEE double decimal expansion plus at most 99 precision digits
            -- fits this bound; width is limited to two digits at compilation.
            local bytes=512
            if kind=="string" and token=="s" then bytes=#argument
            elseif kind=="string" and token=="q" then bytes=quotedBytes(argument) end
            upperBound=upperBound+math.max(bytes,plan.widths[index])
            if upperBound>32768 then return failure("INVALID_LOCALE_FORMAT","i18n."..key) end
        end
    end
    local ok, formatted=pcall(string.format,value,...)
    if not ok or #formatted>32768 then return failure("INVALID_LOCALE_FORMAT", "i18n."..tostring(key)) end
    return formatted
end
Translator.Format=Translator.Text
function Translator:Resolve(value)
    if type(value)=="table" and rawget(value,"key")~=nil then
        if not plain(value) or type(value.key)~="string" or #value.key==0 then return failure("INVALID_SCHEMA","i18n.reference") end
        for key in pairs(value) do if key~="key" then return failure("INVALID_SCHEMA","i18n.reference") end end
        return self:Text(value.key)
    end
    return value
end
function P:Compile(resources, field)
    field=field or "i18n"
    if not plain(resources) or not plain(resources.enUS) then return failure("INVALID_LOCALES",field) end
    local bytes, count, formats=0,0,{}
    for key,value in pairs(resources.enUS) do
        if type(key)~="string" or #key==0 or #key>96 or type(value)~="string" or #value>1024 then return failure("INVALID_LOCALES",field..".enUS") end
        count=count+1;if count>256 then return failure("LOCALE_LIMIT",field) end
        local parsed=signature(value)
        if parsed==nil then return failure("INVALID_LOCALE_FORMAT",field..".enUS."..key) end
        formats[key]=parsed
    end
    for locale,entries in pairs(resources) do
        if not locales[locale] or not plain(entries) then return failure("INVALID_LOCALES",field) end
        local entriesCount=0
        for key,value in pairs(entries) do
            entriesCount=entriesCount+1
            if entriesCount>256 then return failure("LOCALE_LIMIT",field) end
            if type(key)~="string" or #key==0 or #key>96 or type(value)~="string" or #value>1024 then return failure("INVALID_LOCALES",field.."."..locale) end
            if resources.enUS[key]==nil then return failure("INVALID_LOCALE_KEY",field.."."..locale.."."..key) end
            if signature(value)~=formats[key] then return failure("INVALID_LOCALE_FORMAT",field.."."..locale.."."..key) end
            bytes=bytes+#key+#value
            if bytes>131072 then return failure("LOCALE_LIMIT",field) end
        end
    end
    local locale=I.Locale and I.Locale.code or (type(GetLocale)=="function" and GetLocale()) or "enUS"
    local family=(locale=="zhCN" or locale=="zhTW") and "zhCN" or "enUS"
    local exact,related=resources[locale],resources[family]
    local dictionary,formatPlans={},{}
    for key,value in pairs(resources.enUS) do
        dictionary[key]=(exact and exact[key]) or (related and related[key]) or value
        local _,plan=signature(dictionary[key]);formatPlans[key]=plan
    end
    return setmetatable({dictionary=dictionary,formatPlans=formatPlans}, translatorMeta)
end
