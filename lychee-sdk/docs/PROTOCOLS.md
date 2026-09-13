# Provider API 1.0.0 协议参考

公开 API 版本：API_VERSION="1.0.0"。SDK 发行版本同为 1.0.0，UI Runtime 版本 1。API 使用完整版本字符串；旧数字版本与修订号字段不兼容，未知字段和废弃接口不做转换。接入步骤见[教程](GETTING_STARTED.md)。

## 公共入口

`Lychee:Supports("1.0.0")`、`IsReady()`、`RegisterReady(callback)`、`RegisterProvider(definition)`。Ready 登记返回可 Cancel 的订阅；就绪与 SavedVariables 就绪是两个条件。`OpenSettings()` 打开 Host 设置；`ObservePalette(callback)` 订阅打开/关闭并返回 Cancel 句柄，最多 64 个，调用者结束时取消。

## Provider 声明

| 字段 | 合同 |
|---|---|
| id | 必填，全局唯一，最多 64 字节；小写 ASCII 字母/数字起始，仅含字母、数字、点、短横线。 |
| apiVersion | 必填字符串 `"1.0.0"`，与 SDK 发行版本一致。无独立修订号。 |
| version / title | 必填，集成版本和用户显示名。标题可使用所属词典的 `{key=...}`。 |
| scope | 必填 `products`，1–4 个不同的 retail/classic/titan/anniversary；可限制 interface/build/locale。 |
| i18n | 必填，完整 enUS，可选 enGB/zhCN/zhTW；最多 256 键，键 96 字节、值 1024 字节、总量 128 KiB。 |
| source / description / icon / order | 可选管理页来源 `{id,title}`、说明、纹理和顺序；不决定注册权限或业务所有权。 |
| query | 必填 `function(request,reply,context)`，返回 nil 或取消函数。 |
| resolve | 可选同步 `function(entryID,context)`，返回当前 Entry 或 nil。 |
| searchGlobal | 可选 boolean，默认 true；与快捷入口独立。 |
| searchPrefixes / searchKeywords | 各 0–8 个唯一字面词，每个最多 48 字节；忽略英文大小写、裁去两端空格；禁止内部空白、逗号、冒号和富文本标记。跨 Provider 同类冲突拒绝。 |
| actions / drags / views | 本 Provider 的命名动作、拖动和页面声明；结果只能引用已声明能力。 |
| onEnable / onDisable | 可选启用回调和停用回调。onEnable(handle) 可返回清理函数；未启动实例不执行停用。 |

省略普通搜索且没有任何快捷入口会拒绝。`entries`、`searchable`、`searchMode` 不是新协议字段。注册不会将 Provider 业务全量目录搬入 Host。

## 句柄与失效

| 方法 | 行为 |
|---|---|
| Invalidate() | 数据变化后使旧查询/结果失效，并通知当前界面刷新；不上传目录。 |
| SetAvailability(boolean,reason?) | 修改运行时可用性，不覆盖用户选择。 |
| GetState() | 当前启用状态、生命周期、版本及最近错误的快照。 |
| Resources() / GetDiagnostics() | 当前启用资源作用域及按需计数。 |
| Text(key,...) | 所属词典格式化；最多 16 参数、字符串参数 1024 字节、输出 32768 字节。 |
| Unregister() | 停止查询、卸载页面、释放作用域、撤销注册；旧句柄退休。 |

句柄不含 `Update`、`Settings` 或 `SetEnabled`。用户开关由 Host 管理；业务目录由 Provider 的 Catalog 或自有实现管理；DB 由子插件自己的 Storage 管理。

## 查询回复

request 是普通数据快照：raw、normalized、tokens、limit、generation，以及可选 filter/session/visible/contextToken/preferredEntryID/ranking。generation 仅标识当前查询，不持久化。filter 来源和类别限制仍由 Host 执行。

ranking 是本 Provider 的 entryID → 0–38 整数权重，最多 72 项，不含其他 Provider 的偏好；来自已有固定项和最近使用顺序，不保存次数或时间戳。动态来源通过 `SDK.CreateRanker(request)` 在候选截断前排序，Catalog 自动接入。排名函数返回值与原 confidence/evidence 分开；同词记忆优先，普通固定/近期加权最多 0.038。精确规则及复制隔离见[目录与排名](CATALOG.md)。这是 API 1.0.0 的可选能力扩展。

`reply(hits)` 接收至多 256 个 `{entry=Entry,confidence=number,evidence?=table}`；confidence 在 0–1 内。evidence 使用 matchedField、matchedText、matchType、confidence、distance，结构由 Host 校验。可用 `SDK.Score(request,entries,scope?)` 计算证据；它不会替业务筛选条目，未命中的业务候选以 0.75 回退分值保留。最终展示上限仍为 20。

查询最多完成一次，最长五秒；换词、关闭、禁用、注销和超时取消旧请求。迟到回复返回 STALE_REQUEST。普通 reply 均校验原始调用方输入。Catalog:Query 只接受当前真实回复函数，不能绕过已注册能力；见[目录接口](CATALOG.md)。

## Entry

| 字段 | 类型与约定 |
|---|---|
| id | 必填 string，1–128 字节，ASCII 字母/数字起始，随后可含 `._:/-`。Provider 内稳定唯一。 |
| title | 必填 Text。 |
| kind | 可选非空 string，缺省 entry；仅作为语义/展示元数据，不决定交互。 |
| kindTitle | 可选 Text，用户可读类型名。用于搜索结果右侧标签与提示框；缺省时依次回退分类显示名、Provider 显示名和“内容”。标签颜色统一由 Host 主题决定。 |
| subtitle / subtext | 可选 Text，短说明；subtitle 优先。 |
| description | 可选 Text，搜索说明与 tooltip 正文。 |
| aliases / keywords | 可选 Text，可用字符串数组。 |
| icon | 可选 WoW 纹理 fileID 或路径；缺失时 Host 使用中性标识。 |
| category | 可选显示字符串，或 `{id?,title?,order?,color?}`；id 为本 Provider 的局部分类 ID，Host 自动命名空间化。color 为 3–4 个 0–1 数值。 |
| payload | 可选 plain-data table，供本 Provider 回调使用。 |
| scope | 可选 Scope；控制本条目的有效客户端/locale。 |
| availability | 可选 `{contextKey:string,equals:plainValue}`；执行前与 Host context 对比。 |
| actions | 可选 EntryAction[]，最多 16；缺省为空。 |
| primaryActionID | 可选已声明 action ID；缺省第一项。 |
| drag | 可选 Drag；缺省完全禁用拖动。 |

Text 可以是字符串、本地化映射、语言引用 `{key="KEY"}`，或由字符串、语言引用和 `{text,locale?,scope?}` 组成的数组。Host 按当前 locale 和 scope 取值。普通回调收到公共形状的 Entry 副本，命名动作仍是字符串 ID，副本修改不影响已发布记录；目录更新通过调用方自己的 Catalog:Update 提交。

## 动作与拖动

EntryAction 可以是命名动作 ID 字符串，或以下 Host 描述符。未知类型/多余字段拒绝，不能请求任意安全脚本或注册自定义保护执行器。

| 声明 | 含义 |
|---|---|
| `"open"` | 调用本 Provider 的 actions.open.run。 |
| `{id,title?,kind="open-panel",panel,state?}` | 打开本 Provider 的已声明 view，state 按该 view 的 schema 校验。 |
| `{id,title?,kind="secure-spell",spellID}` | Host 安全技能动作，正整数 spellID；主动作需要真实物理点击；菜单选择次要技能动作只准备按钮，施法成功后才记入历史。 |
| `{id,title?,kind="drag-spell",spellID}` | 点击后通过 Host 技能 cursor 适配器拾取技能。 |
| `drag={type="spell",spellID,title?}` | 真实拖动手势拾取技能。 |
| `drag={type="provider",handler,title?}` | 真实拖动手势调用本 Provider 的 drags[handler].begin；仅普通非保护行为。 |

普通 ActionResult：`{ok=true,close?:boolean,view?:viewID,state?:table}` 或 `{ok=false,code?:string,message?:string}`。缺省保持搜索打开；指定 view 时打开视图，优先于 close。失败不会记录最近使用。message 是给用户的业务原因；异常统一转换为 CALLBACK_ERROR，不显示原始异常栈。拖动的返回值只确认成功/失败，不处理打开视图或关闭搜索。

Host 在执行前检查会话、行绑定、Provider 实例、条目版本、availability 和战斗状态。当前产品在战斗中关闭搜索并拒绝所有动作；普通回调不会改变 WoW 的保护限制。

## 恢复与取消

最近使用只保存 `{providerID,entryID}`。需要恢复的 Provider 提供同步 resolve，返回当前普通 Entry 或 nil；不进行模糊搜索、不返回异步任务。临时条目没有 resolve 或声明 rememberable=false 时不记入历史。

取消函数最多调用一次，包含正常完成、换词、关闭、超时、错误和启停原因；完成后仍要清理自己的临时任务。同步 Lua 不能被抢占。查询协议和评分见上文及 [Catalog](CATALOG.md)。

## 补充结果字段

`rememberable?:boolean`，false 表示不进入固定/最近使用；可恢复条目仍必须提供 resolve。`tooltipRows?:string[][]` 最多 16 行，每行最多 3 列，每列最多 512 字节；只作为通用提示展示，不包含钥匙等具体业务字段。

## 页面与资源

view 声明 `{create,stateSchema}`。create(context,initialState) 返回实例，随后 Mount(context,initialState)，更新用 Update(state,context)，结束执行 Unmount(reason)、Dispose(reason)。每次打开均调用 create，实例缓存由 Provider 决定。context 提供 contentFrame、width、height、extensionID、panelID、session、generation、resources，以及 Resize/SetFooter/ClearFocus/Close 方法；只在当前挂载期间使用。

返回 false 不是异常信号；抛错会清理。同步重入挂载/更新返回 PANEL_BUSY，取消中的挂载返回 PANEL_CANCELLED。原生 Frame 不能当作可回收 Lua 对象；复用控件必须解绑旧记录。细则见[页面生命周期](VIEW_LIFECYCLE.md)、[托管资源](MANAGED_RESOURCES.md)。

## 强制边界

拒绝 secret、不可访问值、循环、metatable、函数型普通数据、NaN/无穷和未知字段。Host 负责隔离、身份、范围、用户选择、结果数量、查询代次、视图 state 和硬件点击限制。普通动作回调收到公开 Entry 副本；受保护动作由 Host 在真实硬件点击下执行，战斗限制保持。

失败返回 nil, Error，至少 code，可含 field/providerID/retryable。稳定错误码全集见 helper 的 ERROR_CODES；不能以错误码分支获得 Host 内部对象。LycheeInternal、Index、记录校验凭证、项目 Modules/Manifest、构建模板均为私有实现。
