local I = _G.LycheeInternal
local L = I.ProviderLocales:Module("builtin.bags")
local C = I.ProviderModules.CatalogProvider
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
local function bagLast() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end
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
        local subtitle=L:Format("共 %d 个 · 左键使用 · 右键更多",row.count)
        put({id="item:"..itemID,title=row.name,kind="item",kindTitle=L["背包"],icon=row.icon,
            subtitle=subtitle,description=L["背包/格位："]..positions,keywords="背包 物品 bags "..itemID,
            payload={itemID=itemID},actions={{id="use",title=L["使用物品"],kind="secure-item",itemID=itemID},"locate"}},row.name.."\0"..tostring(row.icon).."\0"..row.count.."\0"..positions)
        checkpoint()
    end
    self.pendingItem=nil
end
-- Adapter reads only: no persistent hooks, no global item-name filter.
local function clearSearch(box)
    if box and box.GetText and box.SetText and box:GetText()~="" then box:SetText("") end
end
local function visible(button) return button and button.IsVisible and button:IsVisible() end
local function euiButton(frame,itemID)
    local child=frame._scrollChild
    if not child or not child.GetChildren then return end
    local parents={child:GetChildren()}
    local checked=0
    for index=1,math.min(#parents,2048) do
        local parent=parents[index]
        if visible(parent) and parent.GetID and parent.GetChildren then
            local bag=parent:GetID()
            if bag and bag>=0 and bag<=bagLast() then
                local children={parent:GetChildren()}
                for i=1,math.min(#children,16) do
                    local button=children[i]
                    checked=checked+1
                    if checked>1024 then return end
                    local slot=button.GetID and button:GetID()
                    if slot and slot>0 and visible(button) and C_Container.GetContainerItemID(bag,slot)==itemID then
                        local sf=frame._scrollFrame
                        if sf and sf.GetTop and button.GetTop and sf:GetTop() and button:GetTop() then
                            local offset=sf:GetVerticalScroll()+sf:GetTop()-button:GetTop()-8
                            sf:SetVerticalScroll(math.max(0,math.min(sf:GetVerticalScrollRange(),offset)))
                        end
                        return button
                    end
                end
            end
        end
    end
end
local function findButton(bag,slot,itemID)
    local eui=_G.EUI_Bags
    if visible(eui) and eui.SetSelectedView and eui.RefreshInventory then
        clearSearch(eui._searchBox)
        eui:SetSelectedView(0)
        eui:RefreshInventory()
        return euiButton(eui,itemID)
    end
    local elv=_G.ElvUI and _G.ElvUI[1]
    local bags=elv and elv.GetModule and elv:GetModule("Bags",true)
    local frame=bags and bags.BagFrame
    if visible(frame) then
        clearSearch(frame.editBox)
        return frame.Bags and frame.Bags[bag] and frame.Bags[bag][slot]
    end
    local ndui=_G.NDui_Backpack
    if visible(ndui) and ndui.GetButton then return ndui:GetButton(bag,slot) end
    return ContainerFrameUtil_GetItemButtonAndContainer and ContainerFrameUtil_GetItemButtonAndContainer(bag,slot)
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
                if not OpenAllBags then return {ok=false,code="ACTION_UNAVAILABLE"} end
                -- Clear the filter left by the previous implementation. Never set
                -- a new global name filter: third-party search boxes cannot own it.
                if C_Container.SetItemSearch then C_Container.SetItemSearch("") end
                OpenAllBags()
                local button=findButton(bag,slot,itemID)
                if not button or not button:IsVisible() then
                    return {ok=false,message=L["已打开背包；目标格位当前不可见，请展开对应分类"]}
                end
                showHighlight(button)
                return {ok=true,close=true}
            end
        end
    end
    return {ok=false,code="ITEM_NOT_FOUND",message=L["物品已不在背包中"]}
end
local M=C:New("builtin.bags",L["背包物品"],{"BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED"},build,
    {locate={title=L["定位背包"],run=locate}})
function M:onEvent(event,itemID)
    if event=="GET_ITEM_INFO_RECEIVED" and itemID~=self.pendingItem then return end
    self:MarkDirty()
end
function M:onStop() clearHighlight();self.pendingItem=nil end
I.ProviderModules.Bags=M
