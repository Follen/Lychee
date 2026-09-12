local _, carrier = ...
local API = {}
assert(_G.LycheePerformanceTest == nil, "Lychee Performance Test global already exists")
_G.LycheePerformanceTest = API
local initialized = false

local function storage()
    if LycheePerformanceTestDB == nil then LycheePerformanceTestDB = {schemaVersion=1,reports={}} end
    local db = LycheePerformanceTestDB
    if type(db) ~= "table" or db.schemaVersion ~= 1 or type(db.reports) ~= "table" then
        return nil, "Unknown report storage; existing data preserved"
    end
    if not initialized then
        for _, report in pairs(db.reports) do
            if type(report) == "table" and report.status == "running" then
                report.status = "interrupted"
                report.error = "Previous client session ended before completion; cleanup not verified"
            end
        end
        initialized = true
    end
    return db
end

function API.Start(nativeLoadMs)
    local db, why = storage()
    if not db then print("Lychee Performance Test: "..why);return {status="blocked",reason=why} end
    local ok, result = pcall(carrier.Run, nativeLoadMs)
    if not ok then
        if LycheePerformanceTestControl then LycheePerformanceTestControl:Cancel() end
        print("Lychee Performance Test: "..tostring(result))
        return {status="blocked",reason=tostring(result)}
    end
    if result.studyID or result.id then db.lastID = result.studyID or result.id end
    print("Lychee Performance Test: "..tostring(result.status).." "..tostring(result.studyID or result.reason or ""))
    return result
end

function API.Cancel()
    if LycheePerformanceTestControl then LycheePerformanceTestControl:Cancel() end
end

function API.Status()
    local db, why = storage()
    if not db then print(why);return end
    local report = LycheePerformanceTestControl and LycheePerformanceTestControl.report or db.reports[db.lastID]
    print("Lychee Performance Test: "..(report and (report.id.." "..report.status.." "..(report.lastPhase or "")) or "not started"))
    return report
end

SLASH_LYCHEEPERFORMANCETEST1 = "/lypt"
SlashCmdList.LYCHEEPERFORMANCETEST = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    if command == "start" then API.Start()
    elseif command == "cancel" then API.Cancel()
    else API.Status() end
end
