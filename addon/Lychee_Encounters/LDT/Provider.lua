local _,I=...
local M=I.Modules.LDT
local L=I.ProviderLocales:ForProvider(M.id)
function M:Init()
    if self.handle and self.handle:GetState() then return true end
    local handle,err=I.Modules.Support:Register({
        id=self.id,title=L["荔枝大米助手"],version="1.0.0",apiVersion=3,minApiRevision=1,i18n=L.resources,
        scope=I.Modules.Support:Scope(self.id),searchGlobal=true,searchPrefixes={"ldt"},catalog={},
        query=function(request,reply,context) return M:Query(request,reply,context) end,
        resolve=function(id) return M:Resolve(id) end,
        actions={open={title=L["查看资料"],run=function(record)
            if InCombatLockdown and InCombatLockdown() then return {ok=false,code="COMBAT_LOCKED",message=L["请先脱离战斗"]} end
            local current=M:Resolve(record.id)
            if not current then return {ok=false,code="ENTRY_UNAVAILABLE",message=L["资料暂不可用"]} end
            return {ok=true,view="creature",state=current.payload}
        end}},
        views={creature={stateSchema={dungeonID="integer",npcID="integer",spellID="integer"},create=function() return M:CreateView() end}},
        onEnable=function()
            M.active=true
            return function()
                M.active=false
                if M.panel then M.panel:Unmount() end
            end
        end,
    })
    self.handle=handle
    return handle~=nil,err
end
