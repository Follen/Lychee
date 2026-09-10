# Provider 管理与前缀策略

基线 021ffb5。增加独立 ProviderPolicy：声明默认与用户覆盖、前缀归属、碰撞验证、查询路由；Index 仅接收通用 excludedSources 条件，不认识 Provider ID 或设置页。旧声明默认 global；searchable=false 保留既有独立查询语义，不可用设置绕过。

预算与生命周期：用户配置最多128项、每来源8个前缀、每个48字节；历史读取检查前128项，拒绝非法前缀。有效路由快照仅在注册/注销/配置变化后重建，不在每次输入扫描目录。查询过滤键包含策略版本，配置更新取消迟到查询并释放旧搜索缓存。复用一个二级页和固定控件，无新常驻帧回调/事件/timer。沿用原整体搜索与UI预算；关闭清理编辑焦点和来源绑定，点击校验当前注册身份。

`tests/check_contract.ps1` 全部通过。新增 Prefix policy 与 Provider management UI 回归：静态和动态的全局排除、前缀及空前缀查询、英文大小写、用户覆盖/重命名/碰撞/恢复默认、停用恢复、旧回调过滤形状不变、独立模式禁用控件、按下后重绑拒绝、20次二级页重开无新增Frame、隐藏清理焦点。底层全扫描排序参照与原UI性能检查继续通过。

离线固定2689条目录：基线7239.9 KiB，本轮7253.4 KiB；48次查询分配保持1814.1 KiB，平均0.375 ms，保留增长0.1 KiB。1000来源UI仍复用8行，20次刷新分配37.4 KiB，池无增长。预算未放宽；新常驻成本来自策略模块和有限配置/路由快照，默认不新增事件和逐帧工作。数据来自 `.codex/provider-management-final.txt`，单轮测量不作帧率收益结论。

wowdoc四产品 validate 均通过，71个Lua，无诊断。retail latest证据：sourceId=wow-ui-source，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；SimpleFrameAPIDocumentation.lua:247–255，EnableKeyboard 的 bool 参数及受保护标记；编辑设置仅在非战斗时执行。输入框沿用前轮 SimpleEditBoxAPIDocumentation.lua:759 的 SetMaxBytes。Lua/XML/TOC与diff静态检查通过。

新增 ProviderPolicy.lua 与 ProviderSettings.lua，由唯一客户端清单生成四份TOC和默认TOC。按项目约定需重启客户端验收新增模块。真实游戏中的布局、缩放、输入焦点、页面动画、战斗和安全动作尚未实机验证。
