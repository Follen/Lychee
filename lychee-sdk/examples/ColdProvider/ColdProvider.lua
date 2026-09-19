-- Copy this whole directory as Interface/AddOns/ColdProvider.
-- The TOC, not this file, lets the Host discover this provider while cold.
local addon = ...
local host = _G.Lychee
if not host or not host:Supports("1.0.0") then return end
local SDK = host.SDK
if not SDK or type(SDK.SupportsFeature) ~= "function"
    or not SDK.SupportsFeature("discovery", 1)
    or type(SDK.WhenSavedVariablesReady) ~= "function" then return end

host:RegisterReady(function()
    local token, waitError = SDK.WhenSavedVariablesReady(addon, function()
        local client = SDK.GetClient()
        if client.product ~= "retail" or client.interface < 120100 or client.interface > 120199
            or client.build < 1 or client.build > 9999999 then return end
        -- Never read/create SavedVariables before this addon's readiness callback.
        if ColdProviderDB == nil then ColdProviderDB = {schemaVersion=1, acknowledged=false} end
        if type(ColdProviderDB) ~= "table" or ColdProviderDB.schemaVersion ~= 1
            or type(ColdProviderDB.acknowledged) ~= "boolean" then
            error("ColdProvider: unsupported saved data; original value preserved")
        end
        local chinese = client.locale == "zhCN" or client.locale == "zhTW"
        local title = chinese and "冷加载示例" or "Cold example"
        local entryTitle = chinese and "测试冷加载动作" or "Test cold-loaded action"
        local actionTitle = chinese and "执行示例动作" or "Run example action"
        local handle, err = host:RegisterProvider({
            id="example.cold", addon=addon, apiVersion="1.0.0", version="1.0.0",
            title=title, scope={products={"retail"}, minInterface=120100, maxInterface=120199,
                minBuild=1, maxBuild=9999999},
            searchGlobal=false, searchPrefixes={"cold"}, searchKeywords={"coldexample"},
            resource={kind="file", id=134400},
            entries={{id="test", title=entryTitle, icon=134400, actions={"acknowledge"}}},
            actions={acknowledge={title=actionTitle, run=function()
                -- This is the business action. Loading/searching never acknowledges it.
                ColdProviderDB.acknowledged=true
                print(chinese and "冷加载示例：动作已执行。" or "Cold example: action executed.")
                return {ok=true, close=false}
            end}},
        })
        if not handle then error("ColdProvider registration: "..tostring(err and err.code)) end
    end)
    if not token then error("ColdProvider readiness: "..tostring(waitError and waitError.code)) end
end)
