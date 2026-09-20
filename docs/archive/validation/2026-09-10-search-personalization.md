# 搜索习惯、别名与文字命中

基线：`9a50655`。用户明确要求启用查询选择记忆、自定义别名和中英文文字高亮，不加入拼音。

## 成本与生命周期约束

- Host 拥有 `palette.searchPersonalization`；别名最多 128 条，每条 96 字节，标题最多 256 字节，稳定引用各字段最多 192 字节。保存时验证；首次读取历史数据仅检查前 128 项并去重，避免手工 SavedVariables 绕过边界。
- 查询选择记忆最多 128 条，规范化查询最多 128 字节，超长输入正常搜索但不记忆。相同查询覆盖上次选择，超过上限淘汰最久未选择的查询。按客户端与语言隔离；别名按客户端隔离，双语共享用户自己的命名。
- 别名是稳定引用覆盖层，不复制 Provider 目录，不注册新事件、timer、ticker 或空闲逐帧任务。每次输入最多检查 128 个别名，最多解析 20 个匹配引用，最终仍保留 20 个结果。第三方同步 resolve 无法被 Host 抢占，次数上限不代表任意第三方执行时间有保证。
- 记忆只提升当次有效结果，不解析旧记忆、不召回无关或已禁用条目；动态合并后重新应用。空白输入仍显示首页。
- 设置编辑器首次进入创建，之后复用；列表最多 9 行。关闭清理记录、焦点、编辑状态和拖动。鼠标按下后重绑必须拒绝旧点击，战斗中不编辑。
- 高亮仅处理可见行，最多 8 个词、32 个命中区间；文本最长 2048 字节，查询最长 128 字节。超界只跳过装饰，不改变搜索。已有富文本保持原样，保护职业色、品质色、链接和纹理；原始标题、tooltip 与动作不变。每行只保留最近一次格式化结果，释放行时清理。
- 验收预算：零新空闲订阅/驱动，20 次重复别名页打开不增加 Frame；原有整体内存、搜索、UI 回归预算继续生效。额外有界别名扫描需测冷启动/重复查询成本，离线数值不作为实机 FPS 结论。

## 验证

- `powershell -NoProfile -File tests/check_contract.ps1` 全部通过，包括四客户端 × 两种语言的 TOC 加载、SDK 生命周期、搜索参照、安全动作和动画回归。
- 新增 `tests/search_personalization.lua`：真实 Host 注册／查询／分类过滤／停用恢复／保存重读／容量／文字命中；`interaction_smoke.lua` 覆盖右键入口、保存搜索、综合设置入口、取消、按下后换记录、重复打开和隐藏后的失效保存。
- Lua 5.1，128 个有效别名共同命中，预热 10 次、200 次查询：关闭覆盖层平均 0.010 ms、最大 1.000 ms、累计分配 647.1 KiB；启用平均 0.125 ms、最大 2.000 ms、累计分配 7623.1 KiB，GC 后保留差 0.14 KiB。该负载有意触发每次 20 个条目解析，预算为平均 <2 ms、峰值 <10 ms、保留差 <16 KiB；不代表游戏帧率。
- 整体 2689 条目录基线 7235.7 KiB／48 次查询分配 1812.2 KiB；当前 7239.2 KiB／1814.1 KiB，平均查询 0.354 ms。别名页反复打开 20 次无新 Frame；首页生命周期 100 次无新 Frame，未观察到保留增长。
- wowdoc：`sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:759`：`Name = "SetMaxBytes"`，765 行参数 `maxBytes` 为 number；`Interface/AddOns/Blizzard_SharedXMLBase/Color.lua:65`：`return "|c"..self:GenerateHexColor()`，68–69 行 `WrapTextInColorCode` 使用引擎颜色包装。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product <retail|classic|titan|anniversary> --ref latest`：四次均 `valid=true`、69 个 Lua 文件、无诊断。

原始输出：本地 `.codex/personalization-check.txt`、`.codex/alias-edit-api.json`、`.codex/personalization-wowdoc-*.json`。游戏中的英文排版、输入焦点、右键菜单、安全动作以及首次新增 TOC 模块加载需重启客户端验证。未运行游戏内站立／团本／战斗／姓名板峰值场景；本次没有新增这些场景的事件或常驻驱动。
