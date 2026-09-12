local _,I=...
local Store={}
I.Store=Store
local function ordinary(value) return type(value)=="table" and getmetatable(value)==nil end
function Store:Data()
    if not I.savedVariablesReady then error("STORAGE_NOT_READY") end
    local data=LycheePlayerCharacterDB
    if not ordinary(data) or data.schema~=1 then error("INVALID_PLAYER_STORAGE") end
    return data
end
function Store:Settings(id,version,migrations)
    return I.LycheeSDK.Storage.Open({id=id,version=version or 1,migrations=migrations,
        ready=function() return I.savedVariablesReady==true end,
        root=function() return self:Data().settings end})
end
function Store:Initialize()
    if not I.savedVariablesReady then return false,"STORAGE_NOT_READY" end
    if LycheePlayerCharacterDB==nil then LycheePlayerCharacterDB={schema=1,settings={}} end
    local data=LycheePlayerCharacterDB
    if not ordinary(data) or data.schema~=1 or not ordinary(data.settings) then
        self.error="INVALID_PLAYER_STORAGE";return false,self.error
    end
    -- One-time relocation is owned by this package. Unknown Provider namespaces
    -- are not ours to remove, and failed imports preserve their source verbatim.
    local source=ordinary(LycheeCharacterDB) and LycheeCharacterDB.providerSettings
    if ordinary(source) then
        for _,definition in ipairs(I.Modules.Definitions) do
            local id=definition.id
            local oldID=source[id]~=nil and id or id:gsub("^lychee%.","builtin.")
            local values=source[oldID]
            if values~=nil then
                local settings=self:Settings(id,1)
                local ok,err=settings:Import(values);settings:Close()
                if ok and source[oldID]==values then source[oldID]=nil
                elseif err then self.error=err.code end
            end
        end
        if next(source)==nil and LycheeCharacterDB.providerSettings==source then LycheeCharacterDB.providerSettings=nil end
    end
    return true
end
