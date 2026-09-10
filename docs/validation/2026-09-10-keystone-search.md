# 钥匙评分详情误参与副本搜索

基线 `549c9bd`。`lua tests/provider_expansion.lua` 已复现：拥有其他地城钥匙的成员，因季节成绩表包含“毒牙祭坛”，搜索“毒牙”也返回他们。失败记录 `.codex/key-search-red.txt`。

根因：Keystones 把完整成绩表同时放在 description 和 payload.scoreRows；StaticIndex 会索引 description。界面已经使用 payload.scoreRows 绘制表格，因此将成绩明细限制在 payload，description 只保留简短状态，不改变通用引擎描述搜索规则。角色名、真实钥匙副本、原有入口词及用户别名仍可搜索；整季评分、限时/超时和对应传送动作保留。

成本与生命周期：没有新增事件、驱动、控件、缓存或队列；现有最多 5 人、32 个地图/成绩边界不变。更新指纹继续含全部成绩，确保单本分数变化仍推送；索引不再重复保存每人成绩明细，沿用原搜索/Provider 性能预算，预期输入成本不增加。只调整召回语义，不宣称结果集合等价。

wowdoc：sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；`Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua:165`，`GetPlayerMythicPlusRatingSummary` 返回成员赛季分数及已完成的 runs（169、178 行）。未修改 API 调用。

验证：`lua tests/provider_expansion.lua` 从失败转为通过，覆盖无关成绩不召回、真实钥匙副本仍命中、key/分数入口、队友换钥匙与仅分数变化刷新。`powershell -NoProfile -File tests/check_contract.ps1` 全部通过；Lua/XML 静态解析、TOC 生成检查、`git diff --check` 与 retail wowdoc validate（69 Lua、valid=true）通过。

离线 Lua 5.1：本次固定扩展场景常驻增量 2320.7 KiB、100 次搜索累计分配 3952.3 KiB、总查询 23 ms，回收后差 -0.1 KiB（未观察到保留增长）；原有全套预算通过，不作帧率收益比较。没有新增空闲活动工作。无新增 TOC；实机搜索、悬浮表格和传送操作待 `/reload` 后验证。
