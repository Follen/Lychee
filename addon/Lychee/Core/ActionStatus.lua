local I=_G.LycheeInternal
local S={}
I.ActionStatus=S
local function readable(value)
    return not (type(issecretvalue)=="function" and issecretvalue(value))
end
local function number(value)
    return readable(value) and type(value)=="number" and value==value and math.abs(value)~=math.huge
end
function S:Reference(action)
    if type(action)~="table" then return end
    local kind,id
    if action.kind=="secure-spell" then kind,id="spell",action.spellID
    elseif action.kind=="secure-item" then kind,id="item",action.itemID end
    if not kind or not number(id) or id<=0 or id%1~=0 then return end
    if kind=="spell" and not (C_Spell and C_Spell.GetSpellCooldownDuration) then return end
    if kind=="item" and not (C_Container and C_Container.GetItemCooldown) then return end
    return kind,id
end
function S:Primary(item)
    local interaction=item and item.interaction
    local actions=interaction and interaction.actions
    if type(actions)~="table" then return end
    if interaction.primaryActionID then
        for _,action in ipairs(actions) do if action.id==interaction.primaryActionID then return action end end
    end
    return actions[1]
end
-- Native durations remain internal: never copy, format, persist or perform
-- arithmetic on their restricted contents. This state is display-only.
function S:Read(kind,id,out)
    out.mode,out.durationObject,out.start,out.duration,out.rate=nil,nil,nil,nil,nil
    out.state="unknown"
    if kind=="spell" then
        local charges=C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(id)
        local recharging=charges and readable(charges.isActive) and charges.isActive==true
        if charges and readable(charges.isActive) and charges.isActive==nil and number(charges.currentCharges) and number(charges.maxCharges) then
            recharging=charges.currentCharges<charges.maxCharges
        end
        if recharging and C_Spell.GetSpellChargeDuration then
            out.durationObject=C_Spell.GetSpellChargeDuration(id)
            out.state="recharging"
        else
            out.durationObject=C_Spell.GetSpellCooldownDuration(id,true)
        end
        if out.durationObject then out.mode="duration" end
    elseif kind=="item" then
        local start,duration,enabled=C_Container.GetItemCooldown(id)
        if not number(start) or not number(duration) or not readable(enabled) then return out end
        if enabled~=1 and enabled~=true then return out end
        out.mode,out.start,out.duration,out.rate="numeric",start,duration,1
        out.state=duration>0 and "cooling" or "ready"
    end
    return out
end
