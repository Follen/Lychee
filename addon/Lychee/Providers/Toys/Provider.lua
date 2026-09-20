local I = _G.LycheeInternal
local L = I.ProviderLocales:Module("builtin.toys")
local C = I.ProviderModules.CatalogProvider
local ids = I.ProviderModules.ToyIDs
local function validID(id) return type(id)=="number" and id>0 and id==math.floor(id) end
local function listed(id)
    local low,high=1,#ids
    while low<=high do
        local middle=math.floor((low+high)/2)
        if ids[middle]==id then return true end
        if ids[middle]<id then low=middle+1 else high=middle-1 end
    end
end
local function build(self,put,checkpoint)
    if #ids+#self.extra>4096 then error("TOY_CATALOG_LIMIT") end
    local function add(itemID)
        if PlayerHasToy(itemID) then
            local name=C_Item.GetItemNameByID(itemID)
            local icon=C_Item.GetItemIconByID(itemID)
            if type(name)~="string" or name=="" then
                name=L:Format("玩具 #%d",itemID)
                if not self.pending[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
                    self.pending[itemID]=true
                    C_Item.RequestLoadItemDataByID(itemID)
                end
            else self.pending[itemID]=nil end
            put({id="toy:"..itemID,title=name,icon=icon,kind="toy",kindTitle=L["玩具"],
                subtitle=L["左键使用 · 放置类玩具需再点击地面"],keywords="玩具 toy toys "..itemID,
                payload={itemID=itemID},actions={{id="use",title=L["使用玩具"],kind="secure-item",itemID=itemID}}},
                name.."\0"..tostring(icon))
        else self.pending[itemID]=nil end
        checkpoint()
    end
    for _,itemID in ipairs(ids) do add(itemID) end
    for _,itemID in ipairs(self.extra) do add(itemID) end
end
local M=C:New("builtin.toys",L["玩具"],{"TOYS_UPDATED","NEW_TOY_ADDED","ITEM_DATA_LOAD_RESULT"},build)
M.icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\toys.tga"
M.description=L["搜索并使用已收藏玩具"]
M.searchPrefixes={"toys","玩具"}
M.extra,M.pending={},{}
function M:onEvent(event,itemID,success)
    if event=="ITEM_DATA_LOAD_RESULT" then
        if not self.pending[itemID] or not success then return end
    elseif event=="NEW_TOY_ADDED" and validID(itemID) and not listed(itemID) then
        local found=false
        for _,id in ipairs(self.extra) do if id==itemID then found=true;break end end
        if not found then
            if #ids+#self.extra>=4096 then self.lastError="TOY_CATALOG_LIMIT";return end
            self.extra[#self.extra+1]=itemID
        end
    end
    self:MarkDirty()
end
function M:onStop() self.pending={} end
I.ProviderModules.Toys=M
