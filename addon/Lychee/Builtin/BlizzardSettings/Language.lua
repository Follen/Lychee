local I=_G.LycheeInternal
-- Search names only. This module deliberately has no command parser.
local G={};I.Builtin.SettingsLanguage=G
function G.Build(specs,checkpoint)
 for _,s in ipairs(specs) do
  local aliases,seen={},{}
  local function add(word)
   if type(word)~="string" or word=="" or #word>256 then return end
   local key=word:lower();if seen[key] then return end;seen[key]=true
   aliases[#aliases+1]=word
  end
  add(s.name)
  if s.variable then
   add(s.variable);add((s.variable:gsub("^PROXY_",""):gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")))
   local words=I.Builtin.SettingsAliases[s.variable] or s.cvar and I.Builtin.SettingsAliases[s.cvar] or {}
   if s.raid and s.cvar then words=I.Builtin.SettingsAliases[s.cvar:gsub("^raidGraphics","graphics")] or words end
   for _,word in ipairs(words) do
    if s.raid then add((word:find("[\128-\255]") and "团队" or "raid ")..word) else add(word) end
   end
  end
  s.aliases=aliases
  if checkpoint then checkpoint() end
 end
end
