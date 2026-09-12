local I = _G.LycheeInternal
local H = {}
_G.Lychee.UI.TextHighlight = H
-- Only visible rows call this. No persistent text cache or font regions.
-- Existing rich text is retained unchanged rather than damaging color/link tags.
function H:Format(value,query)
    if type(value)~="string" or type(query)~="string" or query=="" or #query>128 or #value>2048 or value:find("|",1,true) then return value end
    local lowered=value:lower();local ranges={}
    local terms=0
    for term in query:lower():gmatch("%S+") do
        terms=terms+1;if terms>8 then break end
        local start=1
        while #ranges<32 do
            local first,last=I.Search.Normalizer:FindLiteral(term,lowered,start)
            if not first then break end
            ranges[#ranges+1]={first,last};start=last+1
        end
    end
    if #ranges==0 then return value end
    table.sort(ranges,function(a,b) return a[1]<b[1] end)
    local out,cursor,last={},1,0
    local color=_G.Lychee.UI.Theme.MatchColorCode
    for index,range in ipairs(ranges) do
        if range[1]>last then
            if last>0 then out[#out+1]=value:sub(cursor,last).."|r";cursor=last+1 end
            out[#out+1]=value:sub(cursor,range[1]-1)..color;cursor=range[1]
        end
        last=math.max(last,range[2])
    end
    out[#out+1]=value:sub(cursor,last).."|r"..value:sub(last+1)
    return table.concat(out)
end
