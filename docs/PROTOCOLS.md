# Provider API 2 协议参考

Host 版本：API_VERSION=2，API_REVISION=5。SDK helper 和 LuaLS 类型均使用本协议。兼容 API 2 revision 1/2/3/4；SavedVariables schema 本次不变。

## 公共 facade

| 调用 | 返回 / 行为 |
|---|---|
| `Supports(apiVersion, minRevision?)` | boolean；revision 缺省为 1。输入错误或不支持时返回 false。 |
| `IsReady()` | boolean。 |
| `RegisterReady(callback)` | 可 Cancel 的订阅；就绪后调用 callback({apiVersion,apiRevision})，最多一次。已就绪时同步调用。 |
| `RegisterProvider(definition)` | ProviderHandle 或 nil, Error。注册整体成功才发布。 |

## ProviderDefinition

| 字段 | 类型与约定 |
|---|---|
| id | 必填 string，1–64 字节，`^[a-z0-9][a-z0-9%.%-]*$`；全局唯一。 |
| apiVersion | 必填 2。 |
| minApiRevision | 可选正整数，缺省 1。 |
| version | 必填非空 string，集成自身版本。 |
| title | 必填非空 string、带非空 default 的本地化映射，或已注册 i18n 中的 `{key="NAME"}`。 |
| entries | 可选 Entry[]，最多 4096 条；entries 与 query 至少声明一个，空目录有效。 |
| searchable | revision 3 可选 boolean，默认 true；使用时 minApiRevision >=3。false 排除静态目录全部文本及用户别名的通用匹配，也不允许通过 source/category filter 直接列举；query、Update、Resolve、动作、固定与最近使用不受影响。注册后不可通过 Update 修改。 |
| searchMode | revision 4 可选 `global`／`prefix`；revision 5 增加 `keyword`。默认 global，用户可覆盖。prefix 要求来源范围；keyword 将精确触发词映射到空文本来源查询。非触发全局搜索排除该来源静态、别名及 query。不能与 searchable=false 同时声明。 |
| searchPrefixes | revision 4 可选 string[]；prefix 模式必填，1–8 个唯一前缀，每个最多48字节。忽略大小写及两端空格，禁止内部空格、冒号、逗号、控制符和富文本标记。与现有前缀冲突返回 INVALID_SCHEMA / searchPrefixes.conflict。 |
| searchKeywords | revision 5 可选 string[]；keyword 模式必填，1–8 个唯一字面触发词，每个最多48字节。英文大小写不敏感、裁去首尾空白；保留标点差异，禁止内部空白、冒号、逗号、控制符和富文本标记。不是 LocaleRef，可同时声明中英文词。冲突返回 INVALID_SCHEMA / searchKeywords.conflict。前缀和触发词分开占用与保存。 |
| query | 可选 function(request, reply, context)，返回 nil 或 cancel(reason)。 |
| resolve | 可选 function(entryID, context)，同步返回当前 Entry 或 nil。 |
| actions | 可选 map<actionID, {title:string|LocaleRef, run:function(entry,context):ActionResult}>。 |
| drags | 可选 map<handlerID, {title:string|LocaleRef, begin:function(entry,context):ActionResult}>。 |
| views | 可选 map<viewID, {stateSchema:Schema, create:function(context,initialState):View}>。 |
| scope | API 2.2 必须声明 `products`；旧版未声明产品范围默认正式服。 |
| i18n | API 2.2 必填 Provider 独立语言资源；enUS 必需，可选 zhCN/zhTW/enGB。 |
| onEnable | 可选 function(handle)，返回 nil 或 cleanup(reason)。pending 注册在 Host 就绪后调用。 |
| onDisable | 可选 function(reason)。清理函数执行后调用。 |

actionID、handlerID、viewID 使用与 Provider ID 相同的命名规则。回调仅允许出现在指定位置。条目、payload、schema、动作结果中不允许 function、metatable、循环引用、frame/userdata、NaN/无穷值或不可访问/secret 值。

## ProviderHandle

| 方法 | 约定 |
|---|---|
| Update({replace=Entry[]}) | 整体替换当前静态目录。 |
| Update({upsert=Entry[]?,remove=string[]?}) | 原子增量更新；同批 upsert 与 remove 不能含相同 ID。总目录不超过 4096。 |
| SetEnabled(boolean) | 禁用时取消查询并清理活动；恢复时重新调用 onEnable。 |
| GetState() | `{enabled:boolean,lifecycle:string,revision:integer,lastError?:Error}`。lastError 为最近一次隔离到的回调/查询诊断副本。 |
| Unregister() | 注销整个实例；重复调用成功，不触达同 ID 的新实例。 |

replace 与增量字段互斥；数组必须稠密且无重复条目 ID。Update 只对当前已启用实例有效，宿主分配 revision。GetState、Update、SetEnabled 对退休句柄返回 STALE_HANDLE。调用成功后原输入表仍归调用方所有。完全相同的更新不改变版本；更新通知中重入 Update/SetEnabled/Unregister 会返回可重试的 UPDATE_IN_PROGRESS，应在当前调用结束后重试。

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

Text 可以是字符串、本地化映射、语言引用 `{key="KEY"}`，或由字符串、语言引用和 `{text,locale?,scope?}` 组成的数组。Host 按当前 locale 和 scope 取值。普通回调收到公共形状的 Entry 副本，命名动作仍是字符串 ID，可修改副本并通过 Update 提交。

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

## 查询与恢复

Request 包含 raw、normalized、tokens、limit、generation，以及可选 contextToken、session、visible、filter。这些值是本次请求的只读快照；不要保存 generation 作为身份。Context 是 Host 当前业务快照，查询时还含 session/generation/visible。

`reply(Entry[])` 最多成功一次，单次最多 256 候选，Host 最终展示最多 20 条。静态和动态候选按 Provider+Entry 去重；同一 Provider 同 ID 的静态条目优先。不同 Provider 可有相同局部 ID。Host 决定排序，不接受任意绝对分数。

取消函数最多调用一次，原因包括 complete、query-replaced、input-changed、hidden、timeout、invalid、error 和启停原因。等待上限五秒；同步 Lua 不能被抢占。超时、完成、取消或旧实例的 reply 返回 nil, STALE_REQUEST。关闭后无查询 deadline 活动，输入变化取消旧请求。

最近使用只保存 `{providerID,entryID}`。静态条目直接恢复；动态条目需要 resolve，返回 nil 代表当前不存在。resolve 不进行模糊搜索，也不返回异步任务。条目动作按恢复后的当前数据执行。临时 query 条目没有 resolve 时不记入历史。

Scope：可含 product、locale、minInterface、maxInterface、minBuild、maxBuild；产品/locale 为字符串，版本边界为整数。字段缺省不加该项约束。category/source 筛选同时约束动态候选。

## 托管视图

View.create(context,initialState) 返回实例，Host 随后调用 instance:Mount(context,initialState)。context 包含 contentFrame、width、height、extensionID、panelID、session、generation。Mount 应使用 initialState 首次绘制。

后续调用 instance:Update(state,context)。替换、关闭或注销时调用 Unmount(reason)、Dispose(reason)。实例应复用自己的 frame，并在卸载时停止事件、timer 和其他活动。不要将 contentFrame 保存到全局搜索结果或 SavedVariables。

Schema 支持基础类型字符串（string/number/boolean/table/integer/any）、可选后缀 `?`、严格字段对象，以及 `{kind="array",items=Schema,maxItems?}`。运行时值仍必须满足 plain-data 边界。

## 稳定错误

公共注册/更新返回 nil, Error，Error 至少包含 code，可含 field、providerID、retryable。回调失败亦可含用户可读 message。

常见 code：UNSUPPORTED_API、INVALID_SCHEMA、DUPLICATE_ID、RESULT_LIMIT、UNKNOWN_ACTION、UNKNOWN_VIEW、UNKNOWN_DRAG、STALE_HANDLE、PROVIDER_DISABLED、STALE_REQUEST、STALE_RESULT、UPDATE_IN_PROGRESS、CALLBACK_ERROR、INVALID_CALLBACK、INVALID_RESULT、QUERY_TIMEOUT、ACTION_FAILED、ACTION_UNAVAILABLE、COMBAT_LOCKED、ACTION_REQUIRES_HARDWARE_CLICK、MENU_UNAVAILABLE、NO_ACTION。可选 SDK helper 在 Host 缺失时另返回 SDK_UNAVAILABLE。

PRIVATE Registry/Index 的具体方法、source token、内部字段、生命周期实现细节和 `_G.LycheeInternal` 不属于 SDK 合同。

## API 2.2：客户端声明与独立语言资源

`scope.products` 是 1–4 项无重复数组，值为 `retail`、`classic`、`titan`、`anniversary`，与旧 `product` 字段互斥。`minInterface/maxInterface/minBuild/maxBuild` 是正整数范围。显式 `scope.locale` 是严格限制，不参与翻译回退。不支持的客户端不启动 Provider，也不执行其停用回调。

每个 Provider 在注册时提交 `i18n={enUS={NAME="Name"},zhCN={NAME="名称"}}`。资源最多四种语言，每种最多 256 键，键不超过 96 字节、单条文字不超过 1024 字节，全部键与值不超过 128 KiB。enUS 是完整基线；其他语言不能新增未定义键，可缺译并回退。Host 按精确语言、语言家族、enUS 编译所选字典；资源之间隔离，注册后外部修改不影响结果。

`LocaleRef` 只能是 `{key="NAME"}`，不接受附加字段。适用于 Provider title、条目文字字段、category.title、动作 title、drag.title；aliases/keywords 数组可包含引用。解析后的文本仍经过原条目校验，增量更新与动态查询共用此边界。

`handle:Text(key,...)` 返回文案或 `nil, Error`；注销后为 `STALE_HANDLE`。支持至多 16 个格式参数／占位符，参数仅数字或不超过 1024 字节字符串，输出最多 32768 字节，超限在格式化前按保守上界拒绝。译文格式参数顺序和转换类型须与英文一致。无参数调用返回模板本身。

语言相关错误：`INVALID_LOCALES`、`INVALID_LOCALE_KEY`、`INVALID_LOCALE_FORMAT`、`LOCALE_LIMIT`；非法引用为 `INVALID_SCHEMA`。API 2.1 仍受支持，未指定产品的旧 Provider 仅在正式服启用。

## 多版本业务实现边界

一个 Provider 可在不同客户端／build 采用不同业务逻辑。产品／版本匹配和实现选择由 Provider 的兼容层在注册前完成；Host 只接收选中的普通 descriptor。一个 ID 在同一 Host 中只注册一次，scope 声明当前实现真正支持的范围。零匹配不启用；重叠匹配拒绝选择，不能按顺序取第一个。各实现仍遵循相同 Entry/Action/View、独立 i18n 与生命周期协议。没有 variants／implementations 注册字段。具体身份、缓存、能力判断和分支验收约束见 [版本差异约定](../lychee-sdk/CLIENT_VARIANTS.md)。
