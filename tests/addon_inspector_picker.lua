-- Pure observed-value adapter: no fake Frame methods or addon-name rules.
local namespace={Modules={}}
TestPackages={Modules=namespace.Modules}
function issecretvalue(v) return type(v)=="table" and v.secret==true end
assert(loadfile("addon/Lychee_Inspector/Picker.lua"))("Lychee_Inspector",namespace)
local Picker=TestPackages.Modules.AddonInspectorPicker
local reads={}
local function known(...) return {"known",...} end
local function observed(object,key)
    if not object then return "unsupported" end
    reads[object]=(reads[object] or 0)+1
    local entry=object[key]
    if not entry then return "unsupported" end
    return unpack(entry)
end
local function allowed(object) return object.allowed~=false end
local function observation(kind,parent)
    return {
        GetObjectType=known(kind),GetParent=known(parent),IsVisible=known(true),
        GetAlpha=known(1),GetEffectiveAlpha=known(1),GetEffectiveScale=known(1),
        IsIgnoringParentAlpha=known(false),
        DoesClipChildren=known(false),GetRect=known(0,0,100,100),
        GetFrameStrata=known("MEDIUM"),GetFrameLevel=known(2),GetDrawLayer=known("ARTWORK"),
        GetRegions=known(),GetChildren=known(),GetTexture=known("icon"),
        GetVertexColor=known(1,1,1,1),GetTextColor=known(1,1,1,1),GetText=known("RS"),
        GetDebugName=known("unnamed"),GetSourceLocation=known("Interface/AddOns/Example/Main.lua:1"),
    }
end
local parent=observation("Frame")
local paint=observation("Texture",parent)
-- Region documentation exposes GetAlpha, not Frame:GetEffectiveAlpha.
paint.GetEffectiveAlpha=nil;paint.DoesClipChildren=nil
local p=Picker.New(allowed,observed,function() return 0 end)
assert(p:Step(paint,nil,50,50).evidence==2,"real Region method surface supports verified paint")
local wrapper=observation("Frame");wrapper.GetRect=known(0,0,1920,1080)
local player=observation("Frame",wrapper);player.GetRect=known(800,100,200,35)
wrapper.GetChildren=known(player)
local chat=observation("FontString",parent);chat.GetText=known("RS")
assert(not p:Step(wrapper,{wrapper},50,50).object,"fullscreen layout wrapper is not content at an empty pointer")
assert(p:Step(wrapper,{wrapper,chat},50,50).object==chat,"fullscreen player wrapper must not steal Rurutia chat hit")
player.GetRect={"secret"}
assert(not p:Step(wrapper,{wrapper},50,50).object,"unreadable unrelated child geometry does not establish wrapper content")

-- Report 324a9e22: empty public shell; six native aura children unreadable.
-- Actual report does not contain raw getters. Each unavailable form below is a
-- separate coverage hypothesis, never represented as a captured engine return.
local unavailable={{"known"},{"error"},{"secret"},{"unsupported"},known({secret=true})}
for _,entry in ipairs(unavailable) do
    local shell=observation("Frame")
    shell.GetRect=known(1115,750,1,1)
    shell.GetSourceLocation=known("Interface/AddOns/EllesmereUI/EllesmereUI_AuraKit.lua:1321")
    local aura=observation("Texture",shell);aura.IsVisible=entry
    aura.GetEffectiveAlpha=nil;aura.DoesClipChildren=nil
    aura.GetSourceLocation=known("Interface/AddOns/EllesmereUI/EllesmereUI_AuraKit.lua:1006")
    shell.GetChildren=known(aura)
    local r=p:Step(shell,{shell,aura},50,50)
    assert(r.object==aura and r.evidence==1 and not r.outline,"actual native aura child supplies source instead of its empty shell")
    -- If the engine's public hierarchy omits that child, the raw native child
    -- itself must survive the unknown-visibility gate in the fallback snapshot.
    shell.GetChildren=known()
    r=p:Step(shell,{shell,aura},50,50)
    assert(r.object==aura and r.evidence==1 and not r.outline,"opaque native aura leaf must not be discarded")
    aura.IsVisible=known(false);r=p:Step(shell,{shell,aura},50,50)
    assert(not r.object,"known hidden aura and empty public shell stay filtered")
end

-- Every unknown dimension permits source evidence, never a red outline. Known
-- negative evidence still wins even if a different dimension is unavailable.
for _,key in ipairs({"IsVisible","GetAlpha","GetRect","GetEffectiveScale","GetTexture","GetVertexColor","GetParent"}) do
    for _,entry in ipairs(unavailable) do
        local item=observation("Texture",parent);item[key]=entry
        if key=="GetTexture" then item.GetAtlas=known();item.IsObjectLoaded=known(true) end
        local r=p:Step(item,nil,50,50)
        if key=="GetParent" and entry[1]=="known" and entry[2]==nil then
            assert(r.object==item and r.evidence==2,"known nil parent means no ancestor, not unreadable hierarchy")
        else
            assert(r.object==item and r.evidence==1 and not r.outline,"unknown "..key.." cannot become empty or verified")
        end
        item.GetVertexColor=known(1,1,1,0)
        if key=="GetVertexColor" then item.IsVisible=known(false) end
        r=p:Step(item,{item},50,50)
        assert(not r.object,"known negative must veto unknown "..key)
    end
end
local top=observation("FontString",parent);top.GetText={"secret"}
local underlay=observation("Texture",parent)
local r=p:Step(top,function() error("readable underlay must not replace native unknown") end,50,50)
assert(r.object==top and not r.outline)
top.GetText=known("100");r=p:Step(top,nil,50,50)
assert(r.object==top and r.evidence==2 and r.outline==top)
top.IsVisible=known(false);r=p:Step(top,{top,underlay},50,50)
assert(r.object==underlay,"known hidden native target immediately falls back")

-- Parent size is not clipping. A clip is a separate, explicit negative fact.
local small=observation("Frame");small.GetRect=known(0,0,1,1)
local outsideChild=observation("Texture",small)
r=p:Step(outsideChild,nil,50,50);assert(r.object==outsideChild and r.evidence==2)
small.DoesClipChildren=known(true)
r=p:Step(outsideChild,{outsideChild},50,50);assert(not r.object)
small.GetRect={"secret"}
r=p:Step(outsideChild,nil,50,50);assert(r.object==outsideChild and not r.outline)
small.GetRect=known(0,0,0,100)
r=p:Step(outsideChild,{outsideChild},50,50);assert(not r.object,"zero-area clipping is known exclusion")
small.DoesClipChildren=known(false);small.GetEffectiveAlpha=known(0)
outsideChild.IsIgnoringParentAlpha=known(true)
r=p:Step(outsideChild,nil,50,50)
assert(r.object==outsideChild and r.evidence==2,"region can remain visible while ignoring parent alpha")
outsideChild.IsIgnoringParentAlpha={"secret"}
r=p:Step(outsideChild,nil,50,50)
assert(r.object==outsideChild and r.evidence==1,"unknown alpha inheritance cannot prove parent alpha applies")
outsideChild.IsIgnoringParentAlpha=known(false)
r=p:Step(outsideChild,{outsideChild},50,50);assert(not r.object,"known alpha inheritance still filters zero parent alpha")

-- Native snapshots, not children, define candidate membership and work size.
local empty=observation("Frame")
local unrelated=observation("Texture",empty)
empty.GetChildren=known(unrelated)
r=p:Step(nil,{empty},50,50)
assert(not r.object,"native container cannot borrow descendant content")
assert(r.object~=unrelated and r.checked==1 and r.queued==1,"child is never enqueued as a candidate")
local many={"known"}
for i=1,64 do
    local child=observation("Frame",empty);child.IsVisible=known(false);many[#many+1]=child
end
empty.GetChildren=many;r=p:Step(empty,nil,50,50)
assert(not r.object and not reads[many[2]] and not reads[many[34]],"child hierarchy is never read to manufacture a candidate")
empty.GetChildren=known();r=p:Step(empty,{empty},50,50);assert(not r.object,"confirmed empty leaf still rejected")

-- Independent oracle for flat native observations. It has no batching, calls no
-- production probes, and deliberately knows only this generated input domain.
local function reference(list)
    local best
    for _,o in ipairs(list) do
        if not o.reject and (not best or o.z>best.z or (o.z==best.z and o.certainty>best.certainty)) then best=o end
    end
    return best
end
local seed=7193
local function random(n) seed=(seed*16807)%2147483647;return seed%n end
local comparisons=0
for case=1,100 do
    local list={}
    for i=1,24 do
        local o=observation("FontString",parent)
        o.z=i;o.GetFrameLevel=known(i) -- Region rank comes from its own frame.
        local frame=observation("Frame");frame.GetFrameLevel=known(i);o.GetParent=known(frame)
        local mode=random(5);o.reject=mode<3;o.certainty=mode==3 and 1 or 2
        if mode==0 then o.IsVisible=known(false)
        elseif mode==1 then o.GetAlpha=known(0)
        elseif mode==2 then o.GetText=known(" ")
        elseif mode==3 then o.GetText={"secret"} end
        list[#list+1]=o
    end
    local expected=reference(list)
    for shuffle=1,3 do
        for i=#list,2,-1 do local j=random(i)+1;list[i],list[j]=list[j],list[i] end
        for _,budgeted in ipairs({false,true}) do
            local clock=0
            local tested=Picker.New(allowed,observed,function() if budgeted then clock=clock+0.8 end;return clock end)
            local result=tested:Step(nil,list,50,50)
            local steps=1
            while result.pending do
                assert(not result.object,"initial partial fallback must not publish a temporary winner")
                result=tested:Step(nil,list,50,50);steps=steps+1;assert(steps<=25)
            end
            assert(result.object==expected,"batched picker must equal independent complete oracle")
            tested:Reset();assert(not tested:State().object and not tested:State().pending)
            comparisons=comparisons+1
        end
    end
end

-- A stationary pending snapshot survives alternating excluded native members;
-- an unrelated native highlight or moved pointer invalidates it.
local t=0
local slow=Picker.New(allowed,observed,function() t=t+0.8;return t end)
local a,b=observation("Frame"),observation("Frame")
local list={a,b,underlay}
r=slow:Step(a,list,50,50);assert(r.pending and not r.object)
r=slow:Step(b,list,50,50);assert(r.pending and not r.object)
r=slow:Step(a,list,50,50);assert(not r.pending and r.object==underlay)
local other=observation("Frame")
r=slow:Step(other,{other},50,50);assert(not r.object and not r.pending)
r=slow:Step(nil,{underlay},500,500);assert(not r.object)
slow:Reset()
print("Addon inspector picker PASS observed unknown/negative/native authority/no expansion + "..comparisons.." reference comparisons")
