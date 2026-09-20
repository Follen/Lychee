# 插件识别证据流程重构

基线 dee4443459ccf8e53b0d00b3b8e2c319e00cd3bb。
用户的47候选Buff报告证实solidTextureProbe无效：empty=true、filled=true、transparent=false。
Buff原生命中来自AuraKit.lua:1321，其创建的是CustomAuraContainerTemplate的AuraContainer；
它自己没有普通Region，池化子按钮的内容读受限。主资源条原生FontString GetText不可读；
次级资源条背景为SetColorTexture，文件/图集均为空。这些不能等同于确定没有可见内容。

实施前成本与生命周期：保留0.1秒活动周期、每批128对象/0.75ms、每轮512对象上限。
几何统一为屏幕矩形、区域有效缩放、祖先裁剪交集；每个候选最多32区域/16祖先。
三态证据：verified / rejected / unverified。明确隐藏、透明、空文本、未加载纹理、
鼠标外、裁剪外、禁止访问、自有UI与Tooltip继续拒绝。未知内容不能升级成verified。
原生候选集独立于祖先/派生队列；只有原生命中或C_System快照中的对象能以unverified显示来源。
普通空Frame无绘制内容，不因创建来源或名字可读而入选；AuraContainer用官方公共协议识别引擎管理内容，
只检查方法存在，不调用其写接口，不读取或推导secret aura值。
先找verified；扫描完成仍无verified才发布unverified。后者显示来源及“内容无法验证”，不画红框。
证据等级变化也更新UI，不以对象身份相同跳过。创建来源准确性独立于绘制内容证据。
删除不成立的纯色探针及两个样本Region。不新增模块/TOC/Frame/timer；每轮新增原生候选集合最多512键，
与队列同生命周期重用/清空，不积累历史。保留一个受限候选，跨批次须重新验证。
离线预算沿用16Frame/48Region、首次512KiB、100次启停1MiB/增长64KiB，不抬高门槛。

wowdoc source wow-ui-source / retail / latest；resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34。
沿用本日Bounds/GetRect/GetEffectiveScale/GetVertexColor/IsObjectLoaded证据；
Blizzard_AuraContainer/Blizzard_AuraContainer.xml:5 intrinsic AuraContainer，:11-12 secure inbound mixins；
Blizzard_CustomAuraContainer.lua:494 CustomAuraContainerSharedMixin:SetAuraProcessingPolicy，
方法仅用于辨认受引擎管理的内容协议，不执行，不绕过访问限制。
先在真实Poll入口复现：AuraContainer壳和受限子控件、原生受限FontString、普通空锚点。
旧代码在AuraContainer来源提示断言失败。游戏绘制与新报告仍需/reload验证。

## 完成验证

实施保留Provider文件内私有Evidence模块，不新增TOC加载条目。矩形计算复用于Frame命中与Region绘制范围，
区域使用自身有效缩放；透明/空白/几何与裁剪分别给出原因，未知内容由原生集合限定。
继承父级来源时保持受限状态，避免“上一级”把未验证内容升级成红框。

新增回归：光环引擎壳及受限子控件、原生受限文字/几何、同对象内容变可读后的红框更新、
普通空锚点拒绝、非文件纹理仅显示来源、确认可见候选优先、未知候选等待后续批次、隐藏候选移除。
之前的聊天文字缩放/留白、透明和裁剪过滤、队列上限与恢复、冻结复制、Tooltip隔离、层级、
Esc/战斗/停用/迟到回调等仍通过。旧数据相关的“未知即无目标”断言改为“可显示原生来源，但无红框”，
这是明确产品语义调整，不声称与旧筛选结果逐项相同。确认隐藏/透明/空内容的原断言保留。

完整check_contract.ps1通过；wowdoc validate 75 Lua、diagnostics=null；git diff --check通过。
离线Lua5.1：12Frame/37Region（移除2探针）、首次保留37.2KiB，100次启停5ms/396.3KiB，
未观察到保留增长；10000次跟随8ms/0分配/0重复setter；100次原生可见命中3ms/0分配/0fallback读取，
100次局部恢复15ms/6.6KiB。相对上一轮次数相同的启停分配393.2KiB增加3.1KiB，
来源于每轮有界原生来源集合；不宣称单样本毫秒差异是帧率提升。原门槛全部通过。
游戏内/reload后的Buff/资源条显示、实际secret行为与绘制仍待验收；不读取secret值、
不保证无法验证的纯色像素可见，只提供原生对象创建来源，明确保留该限制。

后续：本轮实现被 [原生命中优先重构](2026-09-11-inspector-native-picker.md) 替换。这里保留当时验证记录，不代表当前算法或实机验收已通过。
