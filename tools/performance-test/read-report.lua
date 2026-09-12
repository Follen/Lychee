-- Read only. Restrict SavedVariables execution to an empty environment and instruction budget.
local path=assert(arg[1],"Usage: lua read-report.lua <SavedVariables path> [report ID]")
local input=assert(io.open(path,"rb"));local size=input:seek("end");assert(size<=8*1024*1024,"SavedVariables size limit")
input:seek("set");local source=input:read("*a");input:close()
local chunk=assert(loadstring(source,"@diagnostic-savedvariables"));local env={};setfenv(chunk,env)
local instructions=0
debug.sethook(function() instructions=instructions+1000;if instructions>2000000 then error("SavedVariables instruction limit") end end,"",1000)
local ok,why=pcall(chunk);debug.sethook();assert(ok,why)
local db=assert(env.LycheePerformanceTestDB,"Missing independent report database")
assert(db.schemaVersion==1 and type(db.reports)=="table","Unsupported report database")
local id=arg[2] or db.lastID;local report=assert(db.reports[id],"Requested report missing")
assert(report.schema=="lychee.lifecycle-study.v1" and report.id==id,"Report identity/schema mismatch")
local nodes,seen=0,{}
local function quote(value)
    return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',c:byte())
    end)..'"'
end
local function json(value,depth)
    nodes=nodes+1;assert(nodes<=250000 and depth<=32,"Report traversal limit")
    local kind=type(value)
    if kind=="string" then return quote(value) end
    if kind=="boolean" then return tostring(value) end
    if kind=="number" then assert(value==value and value~=math.huge and value~=-math.huge,"Nonfinite number");return tostring(value) end
    assert(kind=="table" and not seen[value],"Unsupported report type/cycle");seen[value]=true
    local keys,array={},true
    for key in pairs(value) do keys[#keys+1]=key;if type(key)~="number" or key%1~=0 or key<1 then array=false end end
    array=array and #keys>0 and #keys==#value
    local out={}
    if array then
        for i=1,#value do out[#out+1]=json(value[i],depth+1) end
    else
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        for _,key in ipairs(keys) do out[#out+1]=quote(tostring(key))..":"..json(value[key],depth+1) end
    end
    seen[value]=nil
    return (array and "[" or "{")..table.concat(out,",")..(array and "]" or "}")
end
io.write(json(report,0),"\n")
