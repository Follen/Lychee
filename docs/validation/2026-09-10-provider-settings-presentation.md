# 新增来源列表展示修复

根因：SettingsView 的 builtinOrder 与 providerIcons 未包含新增五项，导致被归为第三方、显示内部英文 ID 并回退为齿轮。补齐固定映射，新增五条中文用途说明。只改变展示，保留启用状态及第三方身份展示。

复现与回归：`lua tests/performance_ui.lua --check`，在真实 SettingsView 的列表刷新路径注入五项来源。修复前报 `new providers belong to built-in group: builtin.bags`；修复后通过，覆盖分组、顺序、隐藏内部 ID、图标路径及关闭状态保留。

成本：仅模块加载时增加有限常量，不新增 Frame、事件、timer、缓存或驱动。复用现有 64×64 图标：收纳箱、天赋、护甲、设置、钥石；已对照现有图集和 28/34/48 像素钥石预览。游戏内最终布局仍待 `/reload` 验证。

离线 UI 预算保持原值：1000 来源、400 高视口最多 10 行，常驻 <1 MiB，20 次刷新分配 <512 KiB。前后均 9 行、180 个替身对象、446.6 KiB 常驻、42.4 KiB/20 次刷新，池增长 0。单次冷启动 1/2 ms 与 20 次刷新 20/18 ms 为粗粒度单样本，不据此声称性能提升。

兼容性：不改变 Blizzard API、Frame 创建或 setter 调用，只更改传入既有渲染路径的字符串与纹理路径。wowdoc source list/source check 确认 sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34，无更新。inspect FontString.SetText 仅返回前缀匹配 SetTextColor，未作为精确 API 证据；本次没有新增 API 依赖。wowdoc validate 检查 44 个 Lua 文件，无诊断。Lua 语法及 git diff --check 通过。

完整验证：powershell -NoProfile -File tests/check_contract.ps1 通过，含来源生命周期、搜索、交互与性能回归。
