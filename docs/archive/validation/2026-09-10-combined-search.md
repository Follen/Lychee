# 普通搜索与快捷入口解耦

基线 010e433。新 searchGlobal 独立开关与 searchPrefixes/searchKeywords 组合，searchMode 保留为旧版声明。UI 去掉四选一，显示普通搜索开关、直接打开列表、在此来源内搜索及实时示例。来源总开关即时应用，其余编辑保存应用；字段清空移除入口，恢复默认删除覆盖，不能保存完全没有访问入口的配置。SDK helper、manifest、类型、README、SDK、协议、架构及 DESIGN 同步。

生命周期与预算：ProviderPolicy 低频配置／注册／注销时失效快照，查询查表；旧模式只在策略边界映射，不改变旧有效行为。独立普通搜索标志及空数组经 SavedVariables 重新验证，用户覆盖最多128项，每类词表0–8项、每词48字节。直接入口精确匹配优先，前缀选择来源，Index 仍只接收通用过滤。无新增事件、轮询、timer；UI 一个懒创建页面、两个固定输入和共享开关，关闭清焦点、停止滚动拖动与动画，20次重开不创建新Frame。沿用现有预算，不提高阈值。

完整 tests/check_contract.ps1 通过（.codex/combined-full.txt）。新增同一来源普通搜索、前缀、直接入口同时可用测试；关闭普通搜索后两入口仍可用；空表移除、false与空表reload保留、恢复默认、禁用／恢复／注销、revision门禁和拒绝混合searchMode声明。旧 prefix／keyword／searchable 回归全部通过，包括触发精确性、未触发不调用动态查询、冲突与旧目录查询。UI验证草稿启停不丢失、取消、组合保存、无入口错误、恢复默认保存前不生效、按下重绑后松开拒绝、独立来源控件隐藏、反复打开和关闭清焦点。

同一固定2689条目录：前轮7256.9 KiB，本轮7261.5 KiB（+4.6 KiB）；48次搜索分配1814.1 KiB不变、保留增长0.1 KiB，平均0.354 ms。1000来源列表仍8行，常驻458.0 KiB，20次刷新分配37.4 KiB，池增长0。数据为离线单轮，不作为游戏帧率改善结论。旧输入的查表与候选排序预算继续通过。

wowdoc：wow-ui-source / retail / latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。复用 EditBox SetTextInsets，Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:915–925，四参数left/right/top/bottom为uiUnit（.codex/combined-api.json）。无新增原生接口。retail/classic/titan/anniversary validate各71 Lua，全部valid=true无诊断；完整检查含Lua/XML/TOC，git diff检查通过。

布局检查基于现有截图、共享主题与源码几何，Impeccable layout扫描无报告；无法验证游戏实际绘制、英文长名称、缩放、焦点、战斗和帧时间。上述实机场景待 /reload 验收；此次无TOC／新模块变化。回滚使用新git revert并同步。
