local I = _G.LycheeInternal
local M = {}
I.Builtin.Bosses = M

function M:Init()
    if self.handle then return true end
    local data, records = I.Builtin.JournalCatalog, {}
    for index = 1, #data.encounters do
        local encounter = data.encounters[index]
        local instance = data.instances[encounter[2]]
        records[#records+1] = {
            id="boss-" .. encounter[1], title=encounter[3], subtitle=instance[1], kindTitle="首领",
            icon=instance[2], aliases={instance[1]}, keywords={"首领", "boss"},
            payload={encounterID=encounter[1], instanceID=encounter[2]}, actions={"open"},
        }
    end
    local handle, err = _G.Lychee:RegisterProvider({
        id="builtin.bosses", apiVersion=2, version="1.0.0", title="首领", scope={product="retail"}, entries=records,
        actions={open={title="查看首领指南",run=function(entry)
            return I.Builtin.InterfaceActions:Run(function()
                return I.Builtin.InterfaceActions:OpenJournal(entry.payload.instanceID, entry.payload.encounterID)
            end)
        end}},
        onEnable=function() return function(reason) if reason == "unregister" then M.handle=nil end end end,
    })
    self.handle = handle
    return handle ~= nil, err
end
