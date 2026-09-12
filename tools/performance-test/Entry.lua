local _, carrier = ...
local API = {}
API.Revision = "0.3.1-compact-search"
assert(_G.LycheePerformanceTest == nil, "Lychee Performance Test global already exists")
_G.LycheePerformanceTest = API
local initialized = false

-- A single inert overlay, created only by an explicit start. No polling/timers.
local function showStatus(status, report)
    local frame = carrier.statusFrame
    if not frame then
        frame = CreateFrame("Frame", "LycheePerformanceTestStatus", UIParent)
        frame:SetSize(900, 140)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("TOOLTIP")
        frame:EnableMouse(false)
        frame.title = frame:CreateFontString(nil, "OVERLAY")
        frame.title:SetFont(STANDARD_TEXT_FONT, 42, "OUTLINE")
        frame.title:SetTextColor(1, 0.08, 0.08, 1)
        frame.title:SetPoint("CENTER", frame, "CENTER", 0, 18)
        frame.detail = frame:CreateFontString(nil, "OVERLAY")
        frame.detail:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
        frame.detail:SetTextColor(1, 0.18, 0.18, 1)
        frame.detail:SetPoint("TOP", frame.title, "BOTTOM", 0, -14)
        carrier.statusFrame = frame
    end
    local title, detail
    if status == "running" then
        title, detail = "正在执行中…", "请暂勿 /reload · 最长 10 分钟 · /lypt cancel 可取消"
    elseif status == "complete" then
        title, detail = "执行完毕，可落盘", "输入 /reload 保存报告"
        if report and report.baseline then
            detail = report.baseline.status == "passed" and "本轮基准全部通过 · 输入 /reload 保存报告"
                or "基准有未通过项 · 输入 /reload 保存报告"
        end
        for _, round in ipairs(report and report.rounds or {}) do
            for _, provider in pairs(round.providers or {}) do
                if provider.providerError or provider.error then detail = "部分项目有异常 · 输入 /reload 保存报告" end
            end
        end
    elseif status == "cancelled" then
        title, detail = "执行已取消，可落盘", "输入 /reload 保存已有结果"
    elseif status == "aborted" then
        title = report and report.error == "600 second wall limit" and "执行超时，可落盘" or "执行中止，可落盘"
        detail = "测试未全部完成 · 输入 /reload 保存已有结果"
    else
        title, detail = "未能开始执行", "请确认已脱离战斗、Lychee 已加载；聊天框有具体原因"
    end
    frame.title:SetText(title)
    frame.detail:SetText(detail)
    frame:Show()
end

function carrier.UpdateStatus(status, report)
    local ok, why = pcall(showStatus, status, report)
    if not ok then print("Lychee Performance Test status display: "..tostring(why)) end
end

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
    if LycheePerformanceTestControl then
        carrier.UpdateStatus("running")
        return {status="blocked",reason="A study is already running"}
    end
    local db, why = storage()
    if not db then carrier.UpdateStatus("blocked");print("Lychee Performance Test: "..why);return {status="blocked",reason=why} end
    carrier.UpdateStatus("running")
    local ok, result = pcall(carrier.Run, nativeLoadMs)
    if not ok then
        if LycheePerformanceTestControl then LycheePerformanceTestControl:Cancel() end
        carrier.UpdateStatus("blocked")
        print("Lychee Performance Test: "..tostring(result))
        return {status="blocked",reason=tostring(result)}
    end
    if result.studyID or result.id then db.lastID = result.studyID or result.id end
    carrier.UpdateStatus(result.status, result)
    print("Lychee Performance Test "..API.Revision..": "..tostring(result.status).." "..tostring(result.studyID or result.reason or ""))
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
