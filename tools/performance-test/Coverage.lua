local _, carrier = ...

-- Completion is orchestration state; this gate is the bounded baseline contract.
function carrier.CheckBaseline(report)
    local failures = {}
    local function requireCheck(ok, name)
        if not ok then failures[#failures + 1] = name end
    end
    requireCheck(report.status == "complete", "run_not_complete")
    requireCheck(report.cleanupOK == true, "private_cleanup")
    requireCheck(report.liveRootsUnchanged == true, "live_root_identity")
    requireCheck(report.userCharacterStateUnchanged == true, "character_state")
    requireCheck(report.nativeCalls and report.nativeCalls.status == "verified" and #report.nativeCalls.failures == 0, "native_color_preflight")
    local acquisition = report.acquisition and report.acquisition.rounds
    requireCheck(acquisition and #acquisition == 3, "three_acquisition_rounds")
    for _, sample in ipairs(acquisition or {}) do
        requireCheck(sample.recordsEqualFirst == true and type(sample.measuredStagesMs) == "number", "acquisition_result_and_timing")
    end
    requireCheck(#(report.rounds or {}) == 4, "four_rounds")
    local expected = {"achievements", "addon-inspector", "bags", "blizzard-settings", "bosses", "crests",
        "ellesmere", "equipment-sets", "exwind", "game-menus", "great-vault", "keystones", "mounts",
        "player-spells", "talent-loadouts"}
    local queries = {"死亡矿井", "坐骑", "技能", "设置", "成就", "eui:", "eui:冷却", "ex:", "ex:冷却", "key", "not-found"}
    for n = 1, 4 do
        local round = report.rounds and report.rounds[n]
        if round then
            for _, name in ipairs(expected) do
                local p = round.providers and round.providers["builtin." .. name]
                requireCheck(p and p.available and p.initializationOK and p.registered and not p.error and not p.providerError,
                    "round_" .. n .. "/provider/" .. name)
            end
            for _, query in ipairs(queries) do
                requireCheck(round.queries and round.queries[query] ~= nil, "round_" .. n .. "/query/" .. query)
            end
            local eui = round.ellesmereOptionCheck
            requireCheck(eui and eui.status == "verified" and (eui.resolved or 0) > 0, "round_" .. n .. "/ellesmere_option")
            local ex = round.queries and round.queries["ex:"]
            requireCheck(ex and ex.resolved == true and ex.count > 0, "round_" .. n .. "/exwind_resolve")
            local keys = round.providers and round.providers["builtin.keystones"]
            requireCheck(keys and (keys.records or 0) > 0, "round_" .. n .. "/keystone_records")
            local keyQuery = round.queries and round.queries.key
            requireCheck(keyQuery and keyQuery.count > 0, "round_" .. n .. "/keystone_search")
            requireCheck(round.cancelledQueryNoLateReply == true, "round_" .. n .. "/query_cancel")
            requireCheck(round.released == true, "round_" .. n .. "/release")
            requireCheck(type(round.buildActiveMs) == "number" and type(round.indexOnlyMs) == "number"
                and type(round.warm24ActiveMs) == "number", "round_" .. n .. "/timing")
            if n > 1 then
                requireCheck(round.recordsEqual == true and round.queryOrderEqual == true, "round_" .. n .. "/equivalence")
            end
        end
    end
    local prep = report.ellesmerePreparation
    requireCheck(prep and prep.status == "complete" and prep.shown and prep.closed and prep.registrationRestored
        and (prep.optionsAvailable or 0) > 0 and not prep.captureOverflow, "ellesmere_preparation")
    local ui = report.ui
    requireCheck(ui and not ui.skipped and #(ui.samples or {}) == 3 and ui.closed and report.geometryStable, "ui_three_cycles")
    for _, sample in ipairs(ui and ui.samples or {}) do
        requireCheck(sample.shown and sample.headerAlpha == 1 and sample.contentAlpha == 1 and sample.rows ~= nil, "ui_visible_content")
    end
    local memory = report.memory or {}
    requireCheck(memory.live_closed_baseline and memory.all_private_data_caches_released and memory.live_after_ui, "memory_endpoints")
    for n = 1, 4 do requireCheck(memory["active_"..n] and memory["released_"..n], "round_"..n.."/memory") end
    return {status = #failures == 0 and "passed" or "incomplete", failures = failures,
        scope = "Four isolated current-cache Provider/SDK/index rounds, real EUI page preparation/option Resolve and three real Lychee UI cycles; exclusions remain in uncovered/coverage"}
end
