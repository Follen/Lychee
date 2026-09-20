local I = _G.LycheeInternal
I.ProviderLocaleData = I.ProviderLocaleData or {}
do
    local enUS = {
        ["创建位置来自暴雪代码"] = "Created by Blizzard code",
        ["创建位置："] = "Created at: ",
        ["创建来源"] = "Created by",
        ["关联插件 · 内部控件来源"] = "Related addons · internal components",
        ["内部控件来源（不代表整个框体归属）："] = "Internal component sources (not whole-frame ownership):",
        ["关联信息已截断"] = "Related source information truncated",
        ["可能来自 · 根据框体名称"] = "Likely owner · frame name",
        ["可能来自 · 根据父级来源"] = "Likely owner · parent source",
        ["尚未选择框体"] = "No frame selected",
        ["尺寸："] = "Size: ",
        ["层级："] = "Layer: ",
        ["工具"] = "Tools",
        ["开始识别"] = "Start inspecting",
        ["归属未确定"] = "Owner undetermined",
        ["指向界面，查看来自哪个插件"] = "Point at a frame to identify its addon",
        ["原生命中 · 内容无法验证"] = "Native hit · content unverified",
        ["插件识别"] = "Addon inspector",
        ["暂未识别"] = "Not identified",
        ["暴雪创建代码"] = "Blizzard creation code",
        ["未命名框体"] = "Unnamed frame",
        ["未命名父级"] = "Unnamed parent",
        ["未提供创建位置"] = "Source location unavailable",
        ["来源未确定"] = "Source undetermined",
        ["框体："] = "Frame: ",
        ["父级信息已截断"] = "Parent information truncated",
        ["父级关联（不代表修改来源）："] = "Parent chain (does not identify modifications):",
        ["类型："] = "Type: ",
        ["请先启用插件识别来源"] = "Enable the addon inspector provider first",
        ["请在脱离战斗后识别插件"] = "Leave combat before inspecting addons",
    }
    local zhCN = {}
    for key in pairs(enUS) do zhCN[key] = key end
    I.ProviderLocaleData["builtin.addon-inspector"] = {enUS=enUS,zhCN=zhCN}
end
