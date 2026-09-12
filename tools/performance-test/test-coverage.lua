local carrier = {}; assert(loadfile("tools/performance-test/Coverage.lua"))("fixture", carrier)
local function fixture()
    local report = {status="complete",cleanupOK=true,liveRootsUnchanged=true,userCharacterStateUnchanged=true,
        nativeCalls={status="verified",failures={}},acquisition={rounds={}},rounds={},geometryStable=true,
        ellesmerePreparation={status="complete",shown=true,closed=true,registrationRestored=true,optionsAvailable=81},
        ui={samples={},closed=true},memory={live_closed_baseline={},all_private_data_caches_released={},live_after_ui={}}}
    for n=1,3 do report.ui.samples[n]={shown=true,headerAlpha=1,contentAlpha=1,rows=8} end
    for n=1,3 do report.acquisition.rounds[n]={recordsEqualFirst=true,measuredStagesMs=1} end
    for n=1,4 do
        report.memory["active_"..n]={};report.memory["released_"..n]={}
        local round={providers={},queries={},ellesmereOptionCheck={status="verified",resolved=1},
            cancelledQueryNoLateReply=true,released=true,buildActiveMs=1,indexOnlyMs=1,warm24ActiveMs=1,
            recordsEqual=true,queryOrderEqual=true}
        for _,name in ipairs({"achievements","addon-inspector","bags","blizzard-settings","bosses","crests","ellesmere",
            "equipment-sets","exwind","game-menus","great-vault","keystones","mounts","player-spells","talent-loadouts"}) do
            round.providers["builtin."..name]={available=true,initializationOK=true,registered=true,records=1}
        end
        for _,raw in ipairs({"死亡矿井","坐骑","技能","设置","成就","eui:","eui:冷却","ex:","ex:冷却","key","not-found"}) do
            round.queries[raw]={resolved=true,count=1}
        end
        report.rounds[n]=round
    end
    return report
end
assert(carrier.CheckBaseline(fixture()).status=="passed")
for _,mutate in ipairs({
    function(r) r.rounds[2].providers["builtin.keystones"].providerError="ColorMixin" end,
    function(r) r.rounds[2].providers["builtin.keystones"].records=0 end,
    function(r) r.rounds[4]=nil end,
    function(r) r.rounds[2].queries["key"]=nil end,
    function(r) r.rounds[2].queries["key"].count=0 end,
    function(r) r.acquisition.rounds[2].recordsEqualFirst=false end,
    function(r) r.memory.released_3=nil end,
    function(r) r.rounds[1].ellesmereOptionCheck.resolved=0 end,
    function(r) r.ui.samples[2].contentAlpha=0 end,
    function(r) r.ui.skipped="busy" end,
    function(r) r.cleanupOK=false end,
    function(r) r.memory.live_after_ui=nil end,
    function(r) r.rounds[4].queryOrderEqual=false end,
    function(r) r.nativeCalls.failures[1]={api="failed"} end,
    function(r) r.status="aborted" end,
}) do
    local report=fixture();mutate(report)
    assert(carrier.CheckBaseline(report).status=="incomplete","gate missed an injected failure")
end
print("Baseline gate: complete fixture passes; provider/error/empty-key/missing-round/query/option/UI/cleanup/memory/equivalence/native/abort failures rejected PASS")
