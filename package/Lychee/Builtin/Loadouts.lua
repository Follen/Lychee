local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.talent-loadouts")
local C = I.Builtin.CatalogProvider
local function specID()
    local spec=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization()
    return spec and C_SpecializationInfo.GetSpecializationInfo(spec)
end
local function talents(_,put,checkpoint)
    local spec=specID()
    if not spec or not C_ClassTalents or not C_Traits then error("TALENTS_UNAVAILABLE") end
    local ids=C_ClassTalents.GetConfigIDsBySpecID(spec)
    if #ids>128 then error("LOADOUT_LIMIT") end
    local selected=C_ClassTalents.GetLastSelectedSavedConfigID(spec)
    for _,id in ipairs(ids) do
        local info=C_Traits.GetConfigInfo(id)
        if not info then error("TALENT_DATA_PENDING") end
        local current=selected==id
        put({id="talent:"..id,title=info.name,kind="talent-loadout",kindTitle=L["天赋方案"],
            icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\talents.tga",
            subtitle=current and L["当前方案"] or L["点击应用天赋方案"],aliases={"天赋","方案","talents","loadout"},
            payload={configID=id,specID=spec},actions={"apply"}},info.name.."\0"..spec.."\0"..tostring(current))
        checkpoint()
    end
end
local function applyTalent(entry)
    if specID()~=entry.payload.specID then return {ok=false,message=L["专精已改变，请重新搜索"]} end
    local found=false
    for _,id in ipairs(C_ClassTalents.GetConfigIDsBySpecID(entry.payload.specID)) do if id==entry.payload.configID then found=true;break end end
    if not found then return {ok=false,message=L["天赋方案已删除"]} end
    if not PlayerSpellsUtil or not PlayerSpellsUtil.OpenToClassTalentsTab then return {ok=false,code="UI_UNAVAILABLE"} end
    PlayerSpellsUtil.OpenToClassTalentsTab()
    local frame=PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not frame or not frame.LoadConfigInternal then return {ok=false,code="UI_UNAVAILABLE"} end
    local ok,reason=frame:LoadConfigInternal(entry.payload.configID,true)
    return {ok=ok==true,close=ok==true,message=not ok and reason or nil}
end
I.Builtin.TalentLoadouts=C:New("builtin.talent-loadouts",L["天赋方案"],
    {"TRAIT_CONFIG_UPDATED","TRAIT_CONFIG_LIST_UPDATED","PLAYER_SPECIALIZATION_CHANGED"},talents,{apply={title=L["应用方案"],run=applyTalent}})
function I.Builtin.TalentLoadouts:onEvent(event,unit)
    if event=="PLAYER_SPECIALIZATION_CHANGED" and unit~="player" then return end
    self:MarkDirty()
end

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

I.Builtin.EquipmentSets.products={"retail","classic","titan"}
