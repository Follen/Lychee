local I=_G.LycheeInternal
local L=I.ProviderLocales:Builtin("builtin.blizzard-settings")
local A=I.Builtin.AudioAdapter
local V={}
I.Builtin.AudioView=V
local cached
local function cancel(token,reason)
    if type(token)=="function" then token(reason) elseif token and token.Cancel then token:Cancel(reason) end
end
function V.Create()
    if cached then return cached end
    local panel={rows={}}
    function panel:Refresh(row)
        local value=A.Read(row.channel)
        row.updating=true
        if value~=nil then
            if not row.dragging and row.slider:GetValue()~=value then row.slider:SetValue(value) end
            local text=tostring(value).."%"
            if row.valueText~=text then row.value:SetText(text);row.valueText=text end
        else row.value:SetText(L["音量暂不可用"]);row.valueText=nil end
        row.slider:EnableMouse(value~=nil)
        row.updating=false
    end
    function panel:Begin(row)
        if not self.active or A.Read(row.channel)==nil then return false end
        cancel(row.edit,"replaced")
        row.edit=self.context:BeginEdit("set-volume",{version=1,key={channel=row.channel}},
            {mode="latest",interval=0.08,onState=function(state)
                if not self.active then return end
                if state.status=="failed" or state.status=="indeterminate" then self.message:SetText(L["音量修改未确认，请重试"]) end
                if not state.pending and state.status~="editing" then row.edit=nil end
                self:Refresh(row)
            end})
        return row.edit~=nil
    end
    function panel:Mount(context,state)
        self.context,self.active=context,true
        local Theme=_G.Lychee.UI.Theme
        if not self.frame then
            self.frame=CreateFrame("Frame",nil,context.contentFrame);self.frame:SetAllPoints(context.contentFrame)
            local heading=self.frame:CreateFontString(nil,"ARTWORK");heading:SetPoint("TOPLEFT",20,-14)
            Theme:SetFont(heading,"title");Theme:SetTextColor(heading,"text");heading:SetText(L["音量"])
            self.message=self.frame:CreateFontString(nil,"ARTWORK");self.message:SetPoint("TOPLEFT",20,-46);self.message:SetPoint("TOPRIGHT",-20,-46)
            self.message:SetJustifyH("LEFT");Theme:SetFont(self.message,"meta");Theme:SetTextColor(self.message,"textMuted")
            for index,channel in ipairs(A.channels) do
                local row={channel=channel.id}
                local name=self.frame:CreateFontString(nil,"ARTWORK");name:SetPoint("TOPLEFT",20,-84-(index-1)*48)
                Theme:SetFont(name,"body");Theme:SetTextColor(name,"text");name:SetText(L[channel.title]);row.name=name
                row.value=self.frame:CreateFontString(nil,"ARTWORK");row.value:SetPoint("TOPRIGHT",-20,-84-(index-1)*48)
                Theme:SetFont(row.value,"body");Theme:SetTextColor(row.value,"text")
                row.slider=CreateFrame("Slider",nil,self.frame);row.slider:SetOrientation("HORIZONTAL")
                row.slider:SetPoint("TOPLEFT",170,-79-(index-1)*48);row.slider:SetPoint("TOPRIGHT",-82,-79-(index-1)*48)
                row.slider:SetHeight(24);row.slider:SetMinMaxValues(0,100);row.slider:SetValueStep(1)
                local track=row.slider:CreateTexture(nil,"BACKGROUND");track:SetPoint("LEFT",0,0);track:SetPoint("RIGHT",0,0);track:SetHeight(2);track:SetColorTexture(0.40,0.40,0.42,1)
                local thumb=row.slider:CreateTexture(nil,"ARTWORK");thumb:SetSize(10,18);thumb:SetColorTexture(0.835,0.235,0.285,1);row.slider:SetThumbTexture(thumb)
                -- Native sliders do not position a new thumb when the initial value stays at zero.
                thumb:SetPoint("LEFT",row.slider,"LEFT",0,0)
                row.slider:SetScript("OnMouseDown",function() row.dragging=self:Begin(row) end)
                row.slider:SetScript("OnValueChanged",function(_,value)
                    if row.updating or not row.dragging or not row.edit then return end
                    row.draft=math.floor(value+0.5);row.edit:Push({percent=row.draft})
                end)
                row.slider:SetScript("OnMouseUp",function()
                    row.dragging=false
                    if row.edit then row.edit:Finish() end
                    self:Refresh(row)
                end)
                row.slider:SetScript("OnHide",function() row.dragging=false;cancel(row.edit,"hidden");row.edit=nil end)
                self.rows[index]=row
            end
        else self.frame:SetParent(context.contentFrame);self.frame:SetAllPoints(context.contentFrame) end
        self.message:SetText(L["拖动滑块调整，关闭停止未提交的修改"])
        self.channel=state and state.channel or "master"
        for _,row in ipairs(self.rows) do
            Theme:SetTextColor(row.name,row.channel==self.channel and "accent" or "text")
            self:Refresh(row)
            row.observer=context:Observe({version=1,key={channel=row.channel}},function(state)
                if not self.active then return end
                local draft=row.edit and row.edit:GetState().draft
                local own=state.correlation=="builtin.blizzard-settings:volume" and draft and state.values and draft.percent==state.values.percent
                if row.edit and not own then
                    cancel(row.edit,"external-change");row.edit=nil;row.dragging=false
                    self.message:SetText(L["音量已由其他操作修改"])
                end
                self:Refresh(row)
            end)
        end
        if context.Resize then context:Resize(340) end
        self.frame:Show()
    end
    function panel:Unmount()
        self.active=false
        for _,row in ipairs(self.rows) do
            row.dragging=false;cancel(row.edit,"hidden");cancel(row.observer,"hidden")
            row.edit,row.observer=nil,nil
        end
        self.context,self.channel=nil,nil
        if self.frame then self.frame:Hide() end
    end
    function panel:Dispose() self:Unmount() end
    cached=panel;return panel
end
