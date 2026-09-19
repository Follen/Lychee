local I=_G.LycheeInternal
local G={index={},lengths={}}
I.Builtin.SettingsLanguage=G
function G.Normalize(text)
 return (text:lower():gsub("：",":"):gsub("％","%%"):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$",""))
end
local function trim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
local polite={"能不能帮我","能不能幫我","能帮我","可以帮我","请帮我","請幫我","麻烦帮我","麻煩幫我","帮我","幫我","请","請","could you please ","can you please ","please ","could you ","can you "}
local subjects={"把","将","將","the "}
-- Longest spelling first wherever one phrase prefixes another.
local verbs={
 {"turn down ","decrease"},{"turn up ","increase"},
 {"恢复默认","reset"},{"恢复出厂","reset"},{"还原默认","reset"},{"重置","reset"},{"還原","reset"},{"restore ","reset"},{"reset ","reset"},
 {"打开设置","open"},{"查看","open"},{"定位","open"},{"open ","open"},{"show ","open"},{"find ","open"},
 {"开启","on"},{"啟用","on"},{"启用","on"},{"打开","on"},{"打開","on"},{"enable ","on"},{"turn on ","on"},
 {"关闭","off"},{"關閉","off"},{"禁用","off"},{"停用","off"},{"disable ","off"},{"turn off ","off"},
 {"切换","toggle"},{"切換","toggle"},{"toggle ","toggle"},
 {"调高","increase"},{"調高","increase"},{"调大","increase"},{"增大","increase"},{"提高","increase"},{"增加","increase"},{"increase ","increase"},{"raise ","increase"},
 {"调低","decrease"},{"調低","decrease"},{"调小","decrease"},{"降低","decrease"},{"减小","decrease"},{"減小","decrease"},{"减少","decrease"},{"decrease ","decrease"},{"lower ","decrease"},{"reduce ","decrease"},
 {"设置","set"},{"設置","set"},{"设定","set"},{"設定","set"},{"调整","set"},{"調整","set"},{"改为","set"},{"改成","set"},{"设为","set"},{"設為","set"},{"调到","set"},{"調到","set"},{"set ","set"},{"change ","set"},{"adjust ","set"},{"turn ","set"},
}
local connectors={"设置为","设置到","设置成","設置為","設置到","调整为","调整到","调整至","調整到","调成","调到","调至","改为","改成","改到","设为","设到","设成","設為","設成","to ","at ","by ","为","為","到","成","至",":","="}
local units={"percent","per cent","百分比","%","帧每秒","帧","幀","fps","毫秒","ms","倍"}
local suffixes={"谢谢","謝謝","好吗","好嗎","一下","吧"," please"," to default","默认值","默认","預設值"}
local bools={on=true,enabled=true,enable=true,["true"]=true,["1"]=true,["开"]=true,["開"]=true,["开启"]=true,["打开"]=true,["启用"]=true,["是"]=true,
 off=false,disabled=false,disable=false,["false"]=false,["0"]=false,["关"]=false,["關"]=false,["关闭"]=false,["禁用"]=false,["否"]=false}
local muteCommands={["静音"]=false,["靜音"]=false,mute=false,["取消静音"]=true,["取消靜音"]=true,unmute=true}
local choiceGroups={{"低","低档","low"},{"中","中等","medium"},{"普通","一般","fair"},{"高","高档","high"},{"超高","极高","ultra"},{"关闭","无","off","none","disabled"},{"开启","on","enabled"},{"自动","自動","auto","automatic"},{"全部","所有","all"}}
local function remove(text,words)
 for _,word in ipairs(words) do if text:sub(1,#word)==word then return trim(text:sub(#word+1)) end end
 return text
end
local function verb(text)
 for _,v in ipairs(verbs) do if text:sub(1,#v[1])==v[1] then return trim(text:sub(#v[1]+1)),v[2] end end
 return text
end
local digits={["零"]=0,["〇"]=0,["一"]=1,["二"]=2,["两"]=2,["兩"]=2,["三"]=3,["四"]=4,["五"]=5,["六"]=6,["七"]=7,["八"]=8,["九"]=9}
local function chineseNumber(text)
 if #text>27 or text=="" then return end
 local total,pending,previous=0,nil,1000
 for ch in text:gmatch("[\224-\239][\128-\191][\128-\191]") do
  if digits[ch]~=nil then if pending~=nil and pending~=0 then return end;pending=digits[ch]
  elseif ch=="十" or ch=="百" then
   local unit=ch=="十" and 10 or 100;if unit>=previous then return end
   total=total+(pending or 1)*unit;pending=nil;previous=unit
  else return end
 end
 if text:gsub("[\224-\239][\128-\191][\128-\191]","")~="" then return end
 return total+(pending or 0)
end
function G.Build(specs,checkpoint)
 local index,lengths={},{}
 for _,s in ipairs(specs) do
  local aliases,seen={},{}
  local function add(word,commandOnly)
   if type(word)~="string" or word=="" or #word>256 then return end
   local key=G.Normalize(word);if seen[key] then return end;seen[key]=true
   if not commandOnly then aliases[#aliases+1]=word end
   local bucket=index[key];if not bucket then bucket={};index[key]=bucket;lengths[#key]=true end
   bucket[#bucket+1]=s
  end
  add(s.name)
  if s.variable then
   add(s.variable);add((s.variable:gsub("^PROXY_",""):gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")))
   local words=I.Builtin.SettingsAliases[s.variable] or s.cvar and I.Builtin.SettingsAliases[s.cvar] or {}
   if s.raid and s.cvar then words=I.Builtin.SettingsAliases[s.cvar:gsub("^raidGraphics","graphics")] or words end
   for _,word in ipairs(words) do
    if s.raid then add((word:find("[\128-\255]") and "团队" or "raid ")..word) else add(word) end
   end
   local audio=I.Builtin.AudioAdapter
   local channel=audio and audio.ChannelForSetting({setting=s.setting})
   s.channel=channel
   if channel then for _,word in ipairs(audio.byID[channel].words) do add(word) end end
   for _,word in ipairs(I.Builtin.SettingsCommandAliases[s.variable] or {}) do add(word,true) end
  end
  s.aliases=aliases
  if checkpoint then checkpoint() end
 end
 local ordered={};for n in pairs(lengths) do ordered[#ordered+1]=n end;table.sort(ordered,function(a,b) return a>b end)
 G.index,G.lengths=index,ordered
end
function G.Clear() G.index,G.lengths={},{} end
function G.Number(text)
 text=trim(text);local percent=false
 if text:sub(1,#"百分之")=="百分之" then percent=true;text=trim(text:sub(#"百分之"+1)) end
 for _,u in ipairs(units) do if text:sub(-#u)==u then percent=percent or u=="%" or u=="percent" or u=="per cent" or u=="百分比";text=trim(text:sub(1,#text-#u));break end end
 local n=text:match("^%d+%.?%d*$") and tonumber(text) or chineseNumber(text)
 if not n or n>1e9 then return nil end
 return n,percent
end
local function choose(bucket,mode)
 if mode~="on" and mode~="off" and mode~="toggle" then for _,s in ipairs(bucket) do if s.channel=="master" then return s end end end
 local chosen
 for _,s in ipairs(bucket) do
  local eligible=not (mode=="on" or mode=="off" or mode=="toggle") or s.kind=="boolean" or s.kind=="multi" or s.kind=="choice" and mode~="toggle"
  if eligible then
   if chosen and chosen.variable~=s.variable then
    -- Generic audio names mean the level for set/relative commands, switch for on/off.
    if chosen.kind=="boolean" and s.kind=="number" then chosen=s
    elseif not (chosen.kind=="number" and s.kind=="boolean") then return nil,"AMBIGUOUS_TARGET" end
   else chosen=s end
  end
 end
 return chosen
end
function G.Parse(raw)
 if type(raw)~="string" or #raw>1024 then return end
 local text=G.Normalize(raw)
 for _,mark in ipairs({"。","！","!","."}) do if text:sub(-#mark)==mark then text=trim(text:sub(1,#text-#mark));break end end
 for _,word in ipairs({"不要","别把","別把","别关","别开","勿","不想","don't ","do not ","not ","never "}) do if text:find(word,1,true) then return nil,"NEGATED" end end
 for _,s in ipairs(suffixes) do if text:sub(-#s)==s then text=trim(text:sub(1,#text-#s));break end end
 text=remove(remove(text,polite),subjects)
 local mute=muteCommands[text]
 if mute~=nil then
  local s=I.Builtin.SettingsAdapter.byVariable.Sound_EnableAllSound
  if s then return {spec=s,operation="boolean",args={value=mute}} end
 end
 local mode;text,mode=verb(text);text=remove(text,subjects)
 local bucket,tail
 for _,length in ipairs(G.lengths) do
  if #text>=length then
   local found=G.index[text:sub(1,length)]
   if found then
    local nextChar=text:sub(length+1,length+1)
    if nextChar=="" or not (text:sub(length,length):match("[a-z]") and nextChar:match("[a-z]")) then bucket,tail=found,trim(text:sub(length+1));break end
   end
  end
 end
 if not bucket then return end
 local after,postMode=verb(tail)
 if postMode then if mode and mode~=postMode and mode~="set" then return nil,"AMBIGUOUS_TARGET" end;tail,mode=after,postMode end
 if not mode and tail=="" then return end -- Bare lookup retains the native setting's primary action.
 if (mode=="increase" or mode=="decrease") and (tail:sub(1,#"到")=="到" or tail:sub(1,#"至")=="至" or tail:sub(1,3)=="to ") then mode="set" end
 tail=remove(tail,connectors)
 local spec,why=choose(bucket,mode);if not spec then return nil,why or "AMBIGUOUS_TARGET" end
 mode=mode or "set"
 if mode=="on" or mode=="off" then
  if spec.kind=="boolean" and tail=="" then return {spec=spec,operation="boolean",args={value=mode=="on"}} end
 elseif mode=="open" and tail=="" then return {spec=spec,operation="open",args={}}
 elseif (mode=="reset" or mode=="toggle") and tail=="" then return {spec=spec,operation=mode,args={}} end
 if spec.kind=="boolean" and mode=="set" and bools[tail]~=nil then return {spec=spec,operation="boolean",args={value=bools[tail]}} end
 if spec.kind=="color" and mode=="set" then
  local rgb=tail:match("^#(%x%x%x%x%x%x)$")
  local argb=tail:match("^argb:(%x%x%x%x%x%x%x%x)$")
  if rgb or argb then return {spec=spec,operation="color",args={color=(rgb and "ff"..rgb or argb):upper()}} end
 end
 if spec.kind=="number" and (mode=="set" or mode=="increase" or mode=="decrease") then
  local value,percent=G.Number(tail)
  if (tail=="" or tail=="一点" or tail=="一點" or tail=="a little" or tail=="a bit") and mode~="set" then return {spec=spec,operation=mode,args={}} end
  if value and (not percent or spec.factor) then return {spec=spec,operation=mode=="set" and "number" or mode,args={value=value}} end
 end
 if spec.kind=="choice" or spec.kind=="multi" then
  local opts=I.Builtin.SettingsAdapter.Options(spec)
  if spec.kind=="choice" and (mode=="on" or mode=="off") and tail=="" then
   for _,o in ipairs(opts or {}) do
    local b=bools[G.Normalize(o.label or o.text or "")]
    if b~=nil and b==(mode=="on") and not o.disabled then return {spec=spec,operation="choice",args={choice=type(o.value)..":"..tostring(o.value)}} end
   end
  end
  local match
  for _,o in ipairs(opts or {}) do
   local label=G.Normalize(o.label or o.text or "")
   local same=tail==label or tail==tostring(o.value):lower()
   if not same then for _,group in ipairs(choiceGroups) do
    local left,right=false,false;for _,word in ipairs(group) do left=left or word==tail;right=right or word==label end
    if left and right then same=true;break end
   end end
   if same and not o.disabled then if match and match.value~=o.value then return nil,"AMBIGUOUS_TARGET" end;match=o end
  end
  if match and (spec.kind=="choice" and mode=="set" or spec.kind=="multi" and (mode=="on" or mode=="off")) then
   local args={choice=type(match.value)..":"..tostring(match.value)}
   if spec.kind=="multi" then args.enabled=mode=="on" end
   return {spec=spec,operation=spec.kind,args=args}
  end
 end
 return {spec=spec,operation="invalid",args={},code="INVALID_ARGS"}
end
