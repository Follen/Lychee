local input = assert(io.open(assert(arg[1], "SavedVariables path required"), "rb"))
assert(input:seek("end") <= 8 * 1024 * 1024, "SavedVariables size limit")
input:seek("set"); local text = input:read("*a"); input:close()
local chunk = assert(loadstring(text)); local env = {}; setfenv(chunk, env)
local instructions = 0
debug.sethook(function() instructions = instructions + 1000; assert(instructions <= 2000000, "instruction limit") end, "", 1000)
local ok, why = pcall(chunk); debug.sethook(); assert(ok, why)
local db = assert(env.LycheePerformanceTestDB)
assert(db.schemaVersion == 1)
local id = arg[2] or db.lastID; local report = assert(db.reports[id])
assert(report.schema == "lychee.lifecycle-study.v1" and report.id == id)
local carrier = {}; assert(loadfile("tools/performance-test/Coverage.lua"))("test", carrier)
local result = carrier.CheckBaseline(report)
print(id, result.status)
for _, failure in ipairs(result.failures) do print(failure) end
if result.status ~= "passed" then os.exit(1) end
