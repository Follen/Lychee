local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.equipment-sets")
local C = I.Builtin.CatalogProvider
local function equipment(_,put,checkpoint)
    if not C_EquipmentSet then error("EQUIPMENT_API_UNAVAILABLE") end
    local ids=C_EquipmentSet.GetEquipmentSetIDs()
    if #ids>128 then error("LOADOUT_LIMIT") end
    for _,id in ipairs(ids) do
        local name,icon,_,equipped,_,_,_,lost=C_EquipmentSet.GetEquipmentSetInfo(id)
        if not name then error("EQUIPMENT_DATA_PENDING") end
        local subtitle=equipped and L["当前装备方案"] or ((lost or 0)>0 and L["部分装备缺失"] or L["点击装备方案"])
        put({id="equipment:"..id,title=name,kind="equipment-set",kindTitle=L["装备方案"],icon=icon,
            subtitle=subtitle,aliases={"装备","方案","equipment","gear"},payload={setID=id},actions={"equip"}},
            name.."\0"..tostring(icon).."\0"..subtitle)
        checkpoint()
    end
end
I.Builtin.EquipmentSets=C:New("builtin.equipment-sets",L["装备方案"],{"EQUIPMENT_SETS_CHANGED","PLAYER_EQUIPMENT_CHANGED"},equipment,
    {equip={title=L["装备方案"],run=function(entry)
        local name=C_EquipmentSet.GetEquipmentSetInfo(entry.payload.setID)
        if not name then return {ok=false,message=L["装备方案已删除"]} end
        local ok=C_EquipmentSet.UseEquipmentSet(entry.payload.setID)
        return {ok=ok==true,close=ok==true,message=not ok and L["无法装备此方案"] or nil}
    end}})
