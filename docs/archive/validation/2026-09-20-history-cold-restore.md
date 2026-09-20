# EUI 历史冷恢复 0.3.12

## 症状、复现与原因

用户选择“悬停施法”后重载，最近使用显示“目标暂不可用”。角色存档保存的稳定引用是 `builtin.ellesmere` / `page/EllesmereUIRaidFrames/HoverCast`，未损坏。

`lua tests/providers/ellesmere_provider.lua` 新增 Host Preparation → Providers:Resolve 冷恢复用例，修复前稳定失败于 `reload history must restore HoverCast before the first EUI search`。依次核查目录未加载、ID失效、首页刷新三个假设：EUI 搜索会调用 EnsureLoaded，原 Resolve 只读取尚未准备的 `_modules`。加载上游后同 ID 可恢复，证明是未就绪被当成不存在。

## 修复与生命周期成本

- 仅恢复明确的 EUI 页面 ID 且上游 `_deferredLoaded` 未就绪时调用已有 Ready；加载失败保留重试，战斗不加载。普通搜索、解锁及非法格式引用不触发设置加载。页面删除仍不可恢复，不根据历史标题猜目标。
- 不修改 Palette、Host、SV schema 或用户存档。不新增缓存、Frame、timer、事件、预建页面或全量索引。加载上游设置声明是恢复可见页面的必要一次性成本，原生同步加载不可抢占；加载过的上游代码不会在关闭后卸载，不宣称零内存代价。
- 检查发现 EUI 捕获细项依赖会话内哈希和 selector 回调，不能跨重载保证恢复。标记 rememberable=false，仍可搜索与点击，但不再新增固定/历史。旧引用保留；当前会话重新捕获后仍可解析，不迁移到可能错误的页面或设置。

## 同类核查与离线验证

| 来源 | 恢复依据与结果 |
| --- | --- |
| EUI 页面 | 新增首次搜索前冷恢复、加载失败重试、战斗阻止加载、多页面恢复、温恢复不重复加载；保留页面删除/换上游/停用测试 |
| EUI 细项 | 会话限定，Host CanRemember 拒绝；精确导航和 selector 动作保持原有测试 |
| Exwind | 当前路由/模块声明，无上次查询缓存依赖；新增 app/tool/edit/unlock 冷恢复测试，恢复不导航或修改编辑模式 |
| LDT、团本技能 | 固定关系 ID 回查原始目录；代码核对，不依赖上次搜索候选 |
| 斜杠命令 | 从稳定命令 ID 解码并核对当前注册；已注销命令应不可用 |
| 成就、玩具 | 真实 ID/API 或收藏读取；玩具名字尚未缓存有占位回退 |
| 其他目录来源 | Host 当前已提交目录恢复，目录提交触发首页刷新；不把已移除物品等真实失效算成恢复缺陷 |

44组 EUI 业务等价测试保留旧摘要 `827088762:192411782`；只单列断言并剔除预期新增的 `option/* rememberable=false` 字段，其余完整记录、顺序、恢复和动作参数继续精确对照。第一次完整检查因此失败，调整比较口径后重跑，不更新摘要掩盖差异。

## 上游证据

wowdoc source list/check 后同步并索引精确版本。sourceId=ellesmereui，product=main，requestedRef=9.1.8，matchedTag=v9.1.8，resolvedCommit=271ffc30d3265d9f77746b0e15224d918f0fafcb。

- `EllesmereUI.lua:5565`，EnsureLoaded：`if self._deferredLoaded then return end`；EnsureOptionsLoaded 失败保留 false，成功后运行 `_deferredInits`。现有 Ready 包装保留战斗门禁。
- `EllesmereUI_GlobalSearch.lua:22`，_RegisterSearchEntry：按 module/page/label 去重，记录 selectorSetter/selectorKey；注释说明特定 selector 下才存在的设置必须恢复对应选择，不能用页面跳转冒充。

## 实机基线

Retail 12.1.0.69875 / zhCN / 晴昼秋岚—白银之手 / EUI 9.1.8。运行版本0.3.11，Ticket `LYCHEE-20260920-201424-0067`，request `history0312-before-20260920` / revision 1，complete/succeeded，完整1994字节已读取，ACK received。

冷目录标志true；打开首页后目标存在但 restored=false/enabled=false。显式加载声明后相同 ID 恢复，60个 EUI 页面全部恢复，关闭重开目标可用；现存8条历史都可恢复。结束窗口隐藏、无待办查询、Preparation请求0。基线普通首页同步打开1.61ms，温恢复100次9.98ms，单样本不推导帧率。内存为自然刷新后的插件归因读数，不是GC后保留或累计分配；探针 options 名称未命中，不能用其0KiB宣称上游选项包零成本。

完整报告：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-201424-0067/content.json`。

## 最终验收范围

用户追加：首页“最近使用”标题右侧增加“清空”次级按钮。HomeView复用一个48×20导航按钮与meta字体，无媒体/事件/timer新增；冻结/关闭隐藏，战斗拒绝执行。UserPreferences在验证后的当前角色列表上有界原地清空，异常存档不覆盖；固定项和搜索记忆不改。相关代码不进入Palette。中英文真实按钮事件回归、清空后关闭重开、新历史恢复按钮、冻结保护、角色隔离与模块重载持久化离线通过。

原生锚点证据：wowdoc source check / query，sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135` SetPoint，参数point/relativeTo/relativePoint/offsetX/offsetY；复用现有非安全导航按钮，战斗不变更锚点。

计划：真实冷重载后首页恢复、全部 EUI 页面解析、现存其他来源历史、关闭重开、温恢复重复成本及无残留；离线注入加载失败/战斗/禁用/上游替换，不改真实设置制造失败。真实战斗taint、安全技能/物品使用及其他客户端语言不属于本次已实测项。最终安装提交、SHA-256、Ticket 和结果在同步后追加。
