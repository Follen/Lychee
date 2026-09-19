local I=_G.LycheeInternal
local resources={enUS={
    ["当前 %d%% → 设置为 %d%%"]="Current %d%% → Set to %d%%",
    ["当前 %d%%"]="Current %d%%",
    ["音量"]="Volume",
    ["主音量"]="Master volume",
    ["音乐"]="Music",
    ["音效"]="Sound effects",
    ["环境音"]="Ambience",
    ["对话"]="Dialog",
    ["调整音量"]="Adjust volume",
    ["直接调整"]="Adjust directly",
    ["设置音量"]="Set volume",
    ["%s设为 %d%%"]="Set %s to %d%%",
    ["请输入 0–100 的整数百分比"]="Enter a whole percentage from 0 to 100",
    ["请选择一个音量通道"]="Choose one volume channel",
    ["音量暂不可用"]="Volume is currently unavailable",
    ["拖动滑块调整，关闭停止未提交的修改"]="Drag to adjust; closing stops pending changes",
    ["音量已由其他操作修改"]="Volume changed elsewhere",
    ["音量修改未确认，请重试"]="Volume change was not confirmed; try again",
},zhCN={
    ["当前 %d%% → 设置为 %d%%"]="当前 %d%% → 设置为 %d%%",
    ["当前 %d%%"]="当前 %d%%",
    ["音量"]="音量",
    ["主音量"]="主音量",
    ["音乐"]="音乐",
    ["音效"]="音效",
    ["环境音"]="环境音",
    ["对话"]="对话",
    ["调整音量"]="调整音量",
    ["直接调整"]="直接调整",
    ["设置音量"]="设置音量",
    ["%s设为 %d%%"]="%s设为 %d%%",
    ["请输入 0–100 的整数百分比"]="请输入 0–100 的整数百分比",
    ["请选择一个音量通道"]="请选择一个音量通道",
    ["音量暂不可用"]="音量暂不可用",
    ["拖动滑块调整，关闭停止未提交的修改"]="拖动滑块调整，关闭停止未提交的修改",
    ["音量已由其他操作修改"]="音量已由其他操作修改",
    ["音量修改未确认，请重试"]="音量修改未确认，请重试",
}}

for locale,strings in pairs(resources) do
    -- Settings may already have compiled its translator earlier in the TOC.
    -- Publish a new language table so later consumers see the audio formats.
    local target={}
    for key,value in pairs(I.BuiltinLocaleData["builtin.blizzard-settings"][locale]) do target[key]=value end
    for key,value in pairs(strings) do target[key]=value end
    I.BuiltinLocaleData["builtin.blizzard-settings"][locale]=target
end
