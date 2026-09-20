# 原生命中优先的识别器重构

基线：1645c3520e9155a424afde909493ca13d90a1ea9。用户要求替换不断追加放行条件的算法。
未提交的 Evidence.children 补丁一并替换，不作为独立交付。

## 实施前设计与预算

比较三条路径：原生相对游标（隐藏采样器的循环/重置行为未实测，暂不采用）、
候选树事实归约（正确表达支持路径但仍需扩展和维护渲染树）、原生命中优先的有限否决（采用）。
独立 Picker module 对外仅 Step / State / Describe / Reset；Provider 管生命周期和来源分析，UI 只读结果。
WoW 为外部依赖，生产对象 adapter 与离线观察 fixture 在相同模块接口验证。

原生高亮不是像素证明，但也不需要先证明像素才能展示创建来源。
明确隐藏、零透明度、空文本、未加载纹理、确定裁剪外、工具自身/Tooltip/禁止访问仍否决。
缺方法、nil、secret、调用错误为未知；未知不得变成 false。Frame 自有 regions 空不等于子内容空。
普通 Frame 的自有内容与有界子列表都明确为空/不可见才判空；读取不全时只给来源，不画框。
受限原生高亮立即返回，不能被下层可读内容穿透替换。不按插件名称/专用方法判型。
备用结果只来自原生快照，不扩展祖先或子树为新候选；快照顺序无官方保证，因此采用有限层级比较，
不声称重现完整引擎排序。一次候选轮完成后提交，未完成只允许保留本轮仍有效的旧结果。
普通空叶框与明确隐藏池继续过滤；公开信息相同的纯色/空纹理无法绝对区分，必须保留不确定标签。

沿用一个活动 0.1 秒 timer，空闲/关闭/战斗零活动；每批128候选/0.75ms，快照最多512对象。
每个候选最多32自有 regions、32子状态、16祖先，不递归扩展。原生命中可直接结束，不读取备用列表。
Picker 所有权集中在 Provider 实例，一轮快照复用队列、集合、原因表；无对象历史缓存，Reset 释放全部引用。
沿用16Frame/48Region、首次512KiB、100次启停1MiB/保留增长64KiB、100次采样1MiB等离线门槛。
不增加Frame、Region、timer；新增Lua模块及TOC加载顺序需要客户端重启。

## 版本证据

sourceId=wow-ui-source；product=retail；requestedRef=latest；
resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34，source list/check 已执行，远端无更新。

- Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.lua:234：
  `self.highlightFrame = self:SetFrameStack(self.showHidden, self.showRegions, self.highlightIndexChanged)`。
  :74–76 设置相对 direction；仍保留现有参数 false,true,0，不引入游标切换。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua:11–17：
  GetFrameStack 返回 ScriptRegion table，没有顺序保证。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:323–334：
  GetChildren 的 SecretReturnsForAspect 为 Hierarchy，不能把不可读当空。
- 同文件 :968–978：IsVisible 的 SecretReturnsForAspect 为 Shown；:366–377：GetEffectiveAlpha
  属于 Frame，RequiresScriptObjectAlphaAccess，SecretReturnsForAspect 为 Alpha。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua:84：
  IsIgnoringParentAlpha。Region 使用 GetAlpha；明确忽略父透明度时不检查父Alpha，继承状态不可读且
  父Alpha为零时只能判未知。不能因为替身给所有对象提供Frame方法就忽略客户端类型差异。
- Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.xml:4–12：
  `useForbiddenObjectTable="true"` 及 public/forbidden mixin partitions，受限是接口契约的一部分。
- 自身 GetEffectiveScale/GetRect/GetVertexColor/IsObjectLoaded 版本证据沿用
  2026-09-11-inspector-evidence-pipeline.md 所列精确快照；不新增游戏写接口。

原始报告：324a9e22-f27c-4190-9266-16e578dfe35c/pasted-text.txt。
47候选，匿名AuraKit1321 no-visible-content，六个原生Aura子对象 visibility-unreadable。
报告并未提供每项getter返回值，离线fixture中的具体secret/nil/error形态属于覆盖场景，不伪称实测。

## 验证记录

实施：新增 Picker.lua，删除 Provider 内旧 Evidence/扩展队列/原生集合与全局 verified 优先规则。
删除未提交的 Evidence.children 特例；UI 经 SelectionState 读取结果，不直接访问或重放工作队列。
manifest 生成五份TOC：retail 主清单及fallback、classic、titan、anniversary。
来源分析、工具Tooltip隔离、浮窗布局/滚动/层级行为保留。

测试 `lua tests/addon_inspector_picker.lua`：独立观察值adapter覆盖 nil/error/secret/unsupported，
47报告对应的两种公开层级可读性场景；这些是覆盖假设，不声称原始报告提供了原生getter全值。
覆盖直接原生未知不得穿透下层、已知反证否决未知、Frame初始1×1不裁剪子对象、无子树扩展、
32子读取上限、空容器拒绝、鼠标变更和原生变更作废。独立一次性oracle与预算/非预算实现、
打乱原生列表顺序共600次比较全部通过。

专项集成 `lua tests/addon_inspector.lua` 通过：Rurutia文字独立缩放/留白、裁剪、隐藏透明、
两类资源条、冷却/光环来源、原生API不可用兼容、冻结报告、滚动、Esc、战斗取消、迟到回调。
旧测试中“从原生列表外扩展子对象”“任何已验证下层压过受限上层”的预期明确替换；
空覆盖层恢复测试现在将可见资源条作为真实原生候选输入，不再用自建子树制造命中。

只读审查发现并先以fixture复现：零面积裁剪错误变为未知（断言实际失败），
以及Region忽略父透明度的合法情况。修复后增加透明继承true/false/unknown与零面积裁剪回归，全部通过。

同入口离线Lua5.1前后：12 Frame / 37 Region保持；首次保留37.2→37.8KiB；
100次启停累计分配396.3→330.7KiB，未观察到保留增长，CPU样本5→7ms（非显著性结论）。
100次原生首选2ms/0.4KiB/0备用快照；100次备用恢复15→10ms，分配6.6→8.5KiB；
100次128项原生快照10ms、最大单样本1ms、199.1KiB、0新增框体；
10000次鼠标跟随8ms/0分配/0重复setter。全部既有离线预算通过，不声称游戏帧率提升。

完整 `powershell -NoProfile -File tests/check_contract.ps1` 已通过；
`wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`
76 Lua，diagnostics=null；`git diff --check` 通过。审查修复后已复跑完整检查，全部通过。
日志位于本机临时目录 lychee-native-picker-contract.log，不进入运行包。

本地无法执行客户端验证：登录/站立/实际受限Aura/快速悬停/聊天按钮/资源条及战斗的真实渲染和耗时均待验证。
新增TOC条目需要完全退出并重启客户端，不能把提交同步或离线fixture当成实机通过。
若客户端返回相同的“不可读”观测，无法保证区分私有绘制与空布局；保留来源受限标签且不画框。
回滚使用新git revert提交并重新同步，不改写历史。
