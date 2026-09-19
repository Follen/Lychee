local I=_G.LycheeInternal
local API={}
function API:Ensure(providerIDs,context,deadline,callback) return I.Preparation:Ensure(providerIDs,context,deadline,callback) end
_G.Lychee.SDK.Preparation=API
