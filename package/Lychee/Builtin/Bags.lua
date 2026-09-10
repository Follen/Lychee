local I = _G.LycheeInternal
local C = I.Builtin.CatalogProvider
local highlight, highlightTimer
local function clearHighlight()
    if highlightTimer then highlightTimer:Cancel(); highlightTimer=nil end
    if highlight then
        highlight:UnregisterAllEvents()
        highlight:Hide()
        highlight:ClearAllPoints()
    end
end
local function showHighlight(button)
    clearHighlight()
    if not highlight then
        highlight=CreateFrame("Frame")
        highlight:EnableMouse(false)
        local edges={{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}
        for index,edge in ipairs(edges) do
            local texture=highlight:CreateTexture(nil,"OVERLAY")
            texture:SetColorTexture(0.94,0.20,0.29,1)
            texture:SetPoint(edge[1],highlight,edge[1],0,0)
            texture:SetPoint(edge[2],highlight,edge[2],0,0)
            if index<=2 then texture:SetHeight(2) else texture:SetWidth(2) end
        end
        local wash=highlight:CreateTexture(nil,"ARTWORK")
        wash:SetAllPoints();wash:SetColorTexture(1,0.85,0.65,0.12)
        highlight:SetScript("OnHide",clearHighlight)
        highlight:SetScript("OnEvent",clearHighlight)
    end
    highlight:SetParent(button)
    highlight:SetAllPoints(button)
    highlight:SetFrameLevel(button:GetFrameLevel()+5)
    highlight:RegisterEvent("BAG_UPDATE_DELAYED")
    highlight:RegisterEvent("PLAYER_REGEN_DISABLED")
    highlight:Show()
    highlightTimer=C_Timer.NewTimer(3,clearHighlight)
end
local function bagLast() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 end
local function build(self,put,checkpoint)
    if not C_Container then error("BAG_API_UNAVAILABLE") end
    local items, slots={},0
    for bag=0,bagLast() do
        local size=C_Container.GetContainerNumSlots(bag)
        slots=slots+size
        if slots>1024 then error("BAG_SLOT_LIMIT") end
        for slot=1,size do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info and info.itemID then
                local id=info.itemID
                local row=items[id]
                if not row then
                    local name=info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
                    if not name then self.pendingItem=id; error("ITEM_DATA_PENDING") end
                    row={name=name,icon=info.iconFileID,count=0,positions={}}
                    items[id]=row
                end
                row.count=row.count+(info.stackCount or 1)
                row.positions[#row.positions+1]=tostring(bag).."/"..tostring(slot)
            end
            checkpoint()
        end
    end
    for itemID,row in pairs(items) do
        local positions=table.concat(row.positions,"、")
        local subtitle="共 "..row.count.." 个 · 左键使用 · 右键定位"
        put({id="item:"..itemID,title=row.name,kind="item",kindTitle="背包",icon=row.icon,
            subtitle=subtitle,description="背包/格位："..positions,keywords="背包 物品 bags "..itemID,
            payload={itemID=itemID},actions={{id="use",title="使用物品",kind="secure-item",itemID=itemID},"locate"}},row.name.."\0"..tostring(row.icon).."\0"..row.count.."\0"..positions)
        checkpoint()
    end
    self.pendingItem=nil
end
local function locate(entry)
    if InCombatLockdown and InCombatLockdown() then return {ok=false,code="COMBAT_LOCKED"} end
    clearHighlight()
    local itemID=entry.payload.itemID
    local scanned=0
    for bag=0,bagLast() do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            scanned=scanned+1
            if scanned>1024 then return {ok=false,code="BAG_SLOT_LIMIT"} end
            if C_Container.GetContainerItemID(bag,slot)==itemID then
                local info=C_Container.GetContainerItemInfo(bag,slot)
                local name=info and (info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]")))
                if not name or not OpenAllBags or not C_Container.SetItemSearch then break end
                OpenAllBags()
                C_Container.SetItemSearch(name)
                local button=ContainerFrameUtil_GetItemButtonAndContainer and ContainerFrameUtil_GetItemButtonAndContainer(bag,slot)
                if not button or not button:IsVisible() then
                    return {ok=false,message="已打开背包搜索；当前背包界面不支持格子高亮"}
                end
                showHighlight(button)
                return {ok=true,close=true}
            end
        end
    end
    return {ok=false,code="ITEM_NOT_FOUND",message="物品已不在背包中"}
end
local M=C:New("builtin.bags","背包物品",{"BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED"},build,
    {locate={title="定位背包",run=locate}})
function M:onEvent(event,itemID)
    if event=="GET_ITEM_INFO_RECEIVED" and itemID~=self.pendingItem then return end
    self:MarkDirty()
end
function M:onStop() clearHighlight();self.pendingItem=nil end
I.Builtin.Bags=M
