local I = _G.LycheeInternal
local N={locale=(GetLocale and GetLocale()) or "enUS", cache={}}
I.Search=I.Search or {}; I.Search.Normalizer=N
local function lower(s) return string.lower(tostring(s or "")) end
function N:Normalize(s)
    s=lower(s); local c=self.cache[s]; if c then return c end
    s=s:gsub("[%p%c]"," "):gsub("%s+"," "):gsub("^%s+"," "):gsub("%s+$",""); self.cache[s]=s; return s
end
function N:Terms(s) local out={}; for t in self:Normalize(s):gmatch("%S+") do out[#out+1]=t end; return out end
function N:MatchFields(q,title,aliases,keywords)
    local fields={title,aliases,keywords}; q=self:Normalize(q); if q=="" then return false end
    for i=1,#fields do
        local f=fields[i]
        if type(f)=="string" then
            if self:Normalize(f):find(q,1,true) then return true end
        elseif type(f)=="table" then
            for j=1,#f do
                local v=f[j]
                if type(v)=="table" then
                    if (v.locale==nil or v.locale==self.locale or v.locale=="default") and self:Normalize(v.text):find(q,1,true) then return true end
                elseif self:Normalize(v):find(q,1,true) then
                    return true
                end
            end
        end
    end
    return false
end
function N:AliasText(alias) if type(alias)=="table" then return alias.text end return alias end
