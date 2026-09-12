# Lychee SDK：Provider API 2.6

性能、容量与生命周期预算统一见[性能硬门禁](PERFORMANCE.md)；本页说明接口使用方式。

当前 SDK 为 API 2 / revision 7，UI Runtime 仍为 1。新增公共资源生命周期、角色设置和有界缓存，见 [托管资源协议](MANAGED_RESOURCES.md)；旧 revision 1–6 的 Provider 保持兼容。

## 普通搜索与快捷入口（revision 6，推荐）

普通搜索与两种快捷入口可以组合。声明 `minApiRevision=6` 并检查 `Supports(2,6)`：

```lua
-- 放入完整 Provider 声明；scope.products 和 Provider i18n 要求不变。
searchGlobal = true,
searchPrefixes = {"首领", "boss"},
searchKeywords = {"首领列表", "bosslist"},
```

输入首领名参与普通搜索；`首领：名字` 仅搜索此来源；完整输入 `首领列表` 展示此来源列表。三者同时可用。`searchGlobal=false` 只关闭普通搜索（静态、别名和动态 query），不影响两个快捷入口。精确触发快捷入口优先选择来源，不将普通搜索结果拼入该列表。用户别名仍属于单条结果，不能绕过来源的普通搜索开关。

此声明不能同时提供 searchMode 或 searchable=false。两种词表各0–8个，空表显式移除该入口；未提供 searchPrefixes 时沿用已存在的内置前缀，未提供 searchKeywords 时没有直接入口。searchGlobal=false 且两种有效入口均空时注册失败（INVALID_SCHEMA / searchGlobal.routes），管理页也阻止相同配置。格式、48字节上限、冲突、回调形状与下文一致。空表可持久化，false 不会被当成省略值。新 Host 的配置优先级为用户组合配置 > 旧用户模式覆盖 > Provider 声明。

旧 revision 1–5 原行为保留：global 对应普通搜索和前缀；prefix 对应仅前缀；keyword 对应仅直接入口。旧模式中未启用的词表不会在升级后突然启用。用户从新管理页保存后可明确组合所有能力；清空字段只移除该类入口，恢复默认并保存会删除用户覆盖。旧 searchable=false 自定义查询继续独立，不能由用户设置绕过。队伍钥匙默认使用 searchGlobal=false、searchPrefixes={} 和 searchKeywords={"key","钥匙","分数"}，允许用户额外打开普通搜索或添加前缀。

以下 revision 4/5 模式为兼容说明，新接入推荐使用上述组合声明。

## 关键词触发（revision 5）

当用户完整输入约定词时展示该来源内容，可声明 `searchMode="keyword"` 和 `searchKeywords`，无需自写触发判断：

```lua
if Lychee and Lychee:Supports(2, 5) then
    Lychee:RegisterProvider({
        id="example.quick", apiVersion=2, minApiRevision=5, version="1.0.0",
        title={key="TITLE"}, scope={products={"retail"}},
        i18n={enUS={TITLE="Quick tools"},zhCN={TITLE="快捷工具"}},
        searchMode="keyword", searchKeywords={"quick","快捷"},
        entries={{id="hello",title="Hello",actions={"open"}}},
        actions={open={title="Open",run=function() print("Hello") return {ok=true} end}},
    })
end
```

输入 `quick`、` QUICK ` 或 `快捷` 展示此来源的条目；`qui`、`quick extra`、`quick:` 不触发。只忽略英文大小写及首尾空白，不走模糊匹配或标点归一化。触发词是字面字符串，不是 LocaleRef；可以同时声明中英文词。1–8 个唯一词，每词最多48字节，不允许内部空白、冒号、逗号、控制符和富文本标记。

Host 将触发转换为 `raw=""`、`normalized=""`、`tokens={}`、`filter.sourceID="example.quick:records"` 的来源内查询：静态条目直接由索引提供，动态 `query` 只需响应该查询，不要再次判断原触发词。非触发输入不调用关键词来源的 `query`，也不匹配其静态条目和用户别名。结果仍受 Host 的数量限制、排序、生命周期及启停检查约束。显式上下文 `searchFilter.sourceID` 是既有来源浏览入口，仍允许访问；冒号前缀不会绕过 keyword 模式。

触发词在来源间唯一，冲突返回 `INVALID_SCHEMA / searchKeywords.conflict`，不抢占其他来源；同名冒号前缀属于不同命名空间，可共存。禁用来源仍保留名称归属，注销后释放声明归属。用户保存覆盖后按覆盖词占用，原词释放。历史配置发生冲突时同词不路由，避免随机选择来源。

管理页可覆盖模式、前缀及触发词，两种词表分别保存；切换模式不混用词表，恢复默认并保存会清除覆盖。声明优先级为用户覆盖 > Provider 默认 > global。API 2 revision 1–4 兼容，旧 `searchable=false` 的自定义 query 行为不变；它不能同时声明 searchMode/searchPrefixes/searchKeywords。简单触发可迁移到 keyword；复杂独立查询继续使用原协议。队伍钥匙已迁移为 `searchKeywords={"key","钥匙","分数"}`，条目 ID、固定和最近使用引用保持不变。

## 前缀搜索与用户管理（revision 4）

新字段示例：`minApiRevision=4, searchMode="prefix", searchPrefixes={"成就库","myachievements"}`。仍须声明 scope.products 和 i18n；前缀是可同时使用的字面字符串，不是 LocaleRef。注册前检查 `Supports(2,4)`。

省略 searchMode 默认 global。prefix 模式下，全局文本、用户别名和动态 query 均不召回该来源；输入 `成就库：关键词` 或 `myachievements:keyword` 后，Host 统一解析前缀、传入 sourceID 范围，动态回调中的 raw/normalized 是去除前缀后的文字。显式前缀后留空可列举其静态目录；未知前缀保留原搜索含义。原匹配和排序算法不变。

用户点击功能来源进入二级页，可选择跟随默认、全局或仅前缀，并修改前缀。用户覆盖优先于声明，恢复默认会清除覆盖；配置不写回 Provider definition。前缀需唯一，冲突保存失败；内置旧前缀保持兼容，用户指定自定义前缀后替换该来源的旧前缀。SavedVariables 保留最多128个来源覆盖，每来源最多8个48字节前缀。

`searchable=false` 继续表示独立查询，不接受 searchMode/searchPrefixes 或用户搜索方式覆盖；它的动态回调不受前缀模式限制。启用开关仍独立控制来源生命周期，搜索方式不改变动作权限、固定和最近使用规则。

## 是否参与通用搜索（revision 3）

声明 `minApiRevision=3, searchable=false`，并用 `Lychee:Supports(2,3)` 检测 Host。省略 `searchable` 或设为 `true` 时沿用原行为；只接受布尔值，声明后不能通过 Update 修改。使用该字段必须至少 revision 3，scope.products 与 i18n 仍按 revision 2 的约定提供。

`false` 排除静态 entries 的标题、描述、关键词、Provider aliases 和用户别名匹配，也排除来源／类别过滤直接列举；不等于禁用。entries 仍按原协议保存、更新、解析和执行，最近使用／固定引用不受影响。`query` 回调仍会收到查询，可自行精确匹配入口词并 `reply(entries)`；不匹配时 `reply({})`。延迟查询与动作权限沿用原契约，不增加专用 Host 特例。

内置队伍钥匙已从此独立查询模式迁移到 revision 5 的关键词触发声明；默认触发词仍为 `key`、`分数`、`钥匙`。需要自定义解析逻辑的第三方来源可以继续使用 `searchable=false`。

在完整 Provider 声明中加入以下字段，`currentEntries` 由 Provider 维护：

```lua
minApiRevision = 3,
searchable = false,
query = function(request, reply)
    local q = request.normalized
    if q == "key" or q == "分数" or q == "钥匙" then
        reply(currentEntries)
    else
        reply({})
    end
end,
```

SDK 的主要入口是 `Lychee:RegisterProvider`。内置玩家技能、坐骑、纹章、游戏菜单、首领、宏伟宝库和第三方示例使用同一接口。字段与限制见 [协议参考](PROTOCOLS.md)，编辑器类型见 [ApiStubs.lua](../ApiStubs.lua)。

## Host 如何匹配与排序

名称、Provider 别名、关键词、说明和分类由 Host 按字段权重匹配。静态条目和动态回复中的这些文字字段使用同一套非模糊评分；名称和别名比说明更适合声明用户会输入的名称。多词查询要求各词都命中，说明中的零散命中不会统一获得高分。

1–2 个英文字母只匹配完整词或词首，不作模糊纠错，例如 `rl` 不命中 `heirlooms`，`hei` 和 `rlo` 可以命中。中文和数字保留原有规则。此规则适用于通用文本匹配与用户别名，不改变快捷词的精确触发或前缀路由。

`query` 仍可返回按业务逻辑生成的合法候选，即使其文字与输入不同；Host 保留既有业务排序回退，不要求第三方重新实现文本算法。同一 Provider、同一 ID 的静态条目仍优先。上次选择只提升当前匹配且有效的引用，不能绕过来源开关或范围限制。结果仍最多 20 条，模糊召回仍受预算限制。以上不增加 SDK 字段，搜索字段自 revision 6 引入，当前 Host 为 revision 7。

## 最小接入

Host 自动为可持久引用的条目提供用户别名和查询选择记忆，无需额外 SDK 注册。业务 ID 保持稳定；动态条目通过 `resolve` 恢复。用户别名独立保存，不会写入 Provider 声明的 `aliases`，也不能绕过来源启用状态或动作权限。

第三方 TOC 声明 `## OptionalDeps: Lychee`。SDK 缺失时插件自身仍能运行。

```lua
local SDK = _G.Lychee
if not SDK or not SDK:Supports(2, 2) then return end

local provider, err = SDK:RegisterProvider({
    id = "my-addon.search",
    apiVersion = 2,
    minApiRevision = 2,
    scope = { products = { "retail", "classic", "titan", "anniversary" } },
    i18n = {
        enUS = { NAME="My AddOn", SETTINGS="My AddOn settings", OPEN="Open settings", STATUS="Status", READY="Connected" },
        zhCN = { NAME="我的插件", SETTINGS="我的插件设置", OPEN="打开设置", STATUS="当前状态", READY="已连接" },
    },
    version = "1.0.0",
    title = { key = "NAME" },
    entries = {
        { id = "settings", title = { key = "SETTINGS" }, keywords = { "选项", "options" },
          actions = { "open" } },
    },
    actions = {
        open = { title = { key = "OPEN" }, run = function(entry, context)
            MyAddon.OpenSettings() -- 由你的插件实现
            return { ok = true, close = true }
        end },
    },
})
if not provider then MyAddon.ReportIntegrationError(err.code) end
```

不需要另外注册 Command、SearchSource、IntentHandler 或 CapabilityProvider。条目不声明 actions 时就是可搜索信息，不会被 Host 自动当成可施放或可拖动对象。

## 产品范围与独立 i18n

API 2.2 使用 `apiVersion=2,minApiRevision=2`。`scope.products` 和 `i18n` 均必填；前者包含 1–4 个不重复产品：`retail`（正式服）、`classic`（经典怀旧服产品分支）、`titan`（经典 Titan 产品分支）、`anniversary`（周年服产品分支）。这些是稳定协议标识，不是界面显示名。最小示例假定设置入口已验证全部四种产品；实际接入仅声明验证通过的产品。现有 `minInterface/maxInterface/minBuild/maxBuild` 继续约束版本范围。

API 2.1 注册仍可接入；未声明 `scope.products` 或旧 `scope.product` 时默认仅正式服，不会因接口相似静默扩大到经典服。产品和语言相互独立：中文正式服、英文经典服都由各自的产品和 locale 决定。

`i18n` 资源属于单个 Provider，结构为 `enUS={KEY="English"},zhCN={KEY="中文"}`，可增加 `enGB`、`zhTW`。enUS 必须包含完整键集，其他语言缺键按“精确 locale → 同族 zhCN／enUS → enUS”回退；不能声明 enUS 中不存在的键。zhTW 未翻译时使用简中回退。

资源只接受普通表和字符串，最多四个 locale、每个 locale 256 键；键最长 96 字节、值最长 1024 字节，全部资源累计不超过 128 KiB。格式参数的数量、顺序和类型必须一致，`%%` 表示字面百分号。Host 在注册时校验并复制选定语言，调用方随后改原表不会改变已注册文案；两个 Provider 的同名键不会冲突。

Provider 标题、条目文本、分类标题和动作标题可引用 `{key="KEY"}`；引用对象只能有 key，不可附带 locale／scope 等字段。aliases／keywords 可使用 `{{key="KEY"},"固定别名"}`。字符串始终是字面值，不被隐式当作资源键；游戏返回的物品名、玩家命名方案等动态数据应直接作为字符串传入。拖动条目的 `drag.title` 同样支持字符串或 `{key="KEY"}`；也可通过句柄取得翻译。

```lua
local message, err = provider:Text("STATUS")
-- 格式化资源示例：enUS={COUNT="%d items"}, zhCN={COUNT="%d 个物品"}
-- local countText, err = provider:Text("COUNT", 3)
```

`handle:Text` 最多接受 16 个格式参数，单个字符串参数不超过 1024 字节，输出不超过 32768 字节。未知键返回 `INVALID_LOCALE_KEY`，格式错误返回 `INVALID_LOCALE_FORMAT`，资源容量超限返回 `LOCALE_LIMIT`，结构错误返回 `INVALID_LOCALES`。调用方应处理 `nil,err`，不要把错误提示当成功译文。

中文品牌 `|cffd53c49荔枝|r启动器`，英文 `|cffd53c49Lychee|r Launcher`，只给品牌词着荔枝红；描述为“魔兽世界万用启动器”／“Universal launcher for World of Warcraft”。

## 事件驱动更新

```lua
provider:Update({ upsert = {
    { id = "status", title = {key="STATUS"}, subtitle = {key="READY"} },
}, remove = { "obsolete-entry" } })

provider:Update({ replace = currentEntries })
```

replace 与 upsert/remove 互斥。一批数据有任何错误，整批均不发布。调用方可以在调用后修改自己的原表，Host 不受影响。Update 需要 Provider 已启用；在尚未就绪时注册会得到 pending 句柄，应在 onEnable 内建立事件和后续更新。

```lua
onEnable = function(handle)
    -- 在这里建立集成方自己的事件监听。
    local subscription = MyAddon.Watch(function(entries)
        handle:Update({ replace = entries })
    end)
    return function(reason) subscription:Cancel() end
end
```

onEnable 的清理函数在禁用或注销时调用一次。旧句柄不能更新同 ID 的新实例。一般业务直接使用 Unregister 结束集成；需要暂时停用时使用 SetEnabled(false)，再用 SetEnabled(true) 恢复。

## 同步或延迟搜索

```lua
query = function(request, reply, context)
    local task = MyAddon.FindAsync(request.raw, function(entries)
        local accepted, err = reply(entries)
        -- 取消后的回调会得到 STALE_REQUEST，不会重新显示结果。
    end)
    return function(reason) task:Cancel() end
end
```

同步搜索也调用 reply(entries)，不用返回另一种结果结构。最多一次完成；不提供分页或流式 Publish。返回值只能是 nil 或取消函数。Host 最多等待五秒，取消函数在完成时也会调用，用于统一释放资源。

每次动态候选最多 256 条；Provider 应参考 request.limit 尽早减少计算，Host 决定最终排名。回调不能 yield、阻塞或声称能通过 Host 超时机制中断自己的同步 Lua。可直接运行的定时回复示例见 [DeferredProvider.lua](../examples/DeferredProvider.lua)。

## 当前条目恢复与最近使用

静态 entries 自动支持恢复。只有 query 的 Provider 如需进入最近使用，应提供：

```lua
resolve = function(entryID, context)
    return MyAddon.GetCurrentSearchEntry(entryID) -- 不存在时返回 nil
end
```

Host 只保存 providerID/entryID，不保存旧 payload 或动作。恢复使用相同 Entry 协议，随后按当前声明执行。API 2 不迁移旧历史、不接受旧 SDK。

最近使用统一显示 Provider 提供的图标与名称，名称最多两行；没有图标时用中性标识。悬停显示 kindTitle、说明与当前动作，右键访问全部声明动作。类型不决定外形或默认交互，任务、小怪、装备等可以混排在同一行：

搜索结果右侧也显示 `kindTitle`，所有 Provider 采用相同的灰色小字样式。缺少类型名时，依次使用分类显示名、Provider 显示名和“内容”；不需要为了显示标签额外声明 category。

| 接入内容示例 | 最近使用的外观 | 可由 Provider 实现的默认动作 |
|---|---|---|
| 任务 | 任务图标 + 任务名 | 打开任务详情 |
| 小怪 | 代表该单位的纹理图标 + 名称 | 打开资料视图 |
| 装备 | 装备图标 + 装备名 | 打开装备详情 |

以上是接入方式示例，不表示 Host 已内置这些数据源。提供图标时使用 Entry.icon 支持的纹理 fileID 或路径，不传入 Model/Frame。只有成功打开或执行的入口才进入最近使用，纯信息条目与仅搜索命中不会自动记录。希望可回访的信息条目应声明“查看详情”等普通动作；可见的数据过期后由 Provider 更新目录或 resolve 返回当前状态，不靠历史保存旧业务快照。

## 动作、拖动、视图

一个条目最多 16 个动作；actions 内可以引用 Provider 的命名动作，或填写 Host 支持的声明。`primaryActionID` 指定默认动作，缺省为第一个。右键菜单可访问所有动作。

```lua
{
    id = "example-spell", title = "示例技能",
    actions = { { id = "cast", title = "施放", kind = "secure-spell", spellID = 123 } },
    drag = { type = "spell", spellID = 123, title = "放到动作条" },
}
```

技能动作受已知技能、安全策略、战斗和真实硬件点击约束。普通 run 回调不会获得保护权限。普通拖动可以使用 `drag={type="provider",handler="move",title="移动"}`，配合 `drags.move={title="移动",begin=function(entry,context) return {ok=true} end}`。它只用于插件自身允许的非保护操作；不意味着任意对象都能拖到游戏动作条。

run 返回 `{ok=true,view="detail",state={...}}` 可以打开 `views.detail`。视图须声明 stateSchema 和 create，返回具有 Mount(context,initialState)、Update(state,context)、Unmount(reason)、Dispose(reason) 的实例。Mount 内要实际使用初始状态；Update 接收状态本身，不是 `{state=...}` 外壳。内容容器为 context.contentFrame。

完整可安装示例见 [ThirdPartyFixture](../examples/ThirdPartyFixture/ThirdPartyFixture.lua)：包含普通动作、只读条目、独立拖动、视图状态和卸载清理。

宿主每次打开均调用create，复用由Provider显式缓存保证；每次关闭/替换都会依次调用Unmount和Dispose。
Dispose不表示引擎Frame销毁，两次清理须幂等；保留固定控件树时清除当前业务/context引用。
Mount/Update返回false不表示失败，抛错才触发清理。生命周期回调内同步重入挂载/更新返回PANEL_BUSY；
请求关闭会在当前回调返回后完成清理，被取消的挂载/更新返回PANEL_CANCELLED。
正常API2回调顺序与注册字段不变。详见[可复用视图与生命周期](VIEW_LIFECYCLE.md)。

## 验证接入

用户可以通过荔枝标志或搜索“荔枝设置”，分别开关内置与第三方 Provider。用户开关持久保存，与扩展自身的 `handle:SetEnabled()` 独立；两者同时启用时来源才有效。`handle:GetState()` 的 `enabled` 为实际状态，`ownerEnabled` 和 `userEnabled` 分别反映两个开关。停用会停止查询并调用原有清理生命周期，扩展自行启用不能覆盖用户的停用选择。

稳定条目可从右键菜单固定到首页；动态条目需要提供 `resolve` 才可固定。固定记录保存来源和条目 ID，以及用于暂不可用占位的标题与图标，不保存可执行回调。来源关闭后固定记录保留，重新启用时按当前条目解析。设置中的“已固定”支持拖动、上下移动、取消固定及撤销，最多保存 64 项。

检查注册/更新返回值；业务失败返回 `{ok=false,code="MY_ERROR",message="给用户的简短原因"}`。不要把异常堆栈、secret 值或 frame 放进数据协议。Host 诊断有界，第三方仍应自行记录必要的集成错误。

运行 `pwsh -File tests/check_contract.ps1` 可复现本仓库契约测试。游戏内验证搜索/最近使用交互一致、关闭后事件与 timer 停止、旧查询不回流，以及真实施法、拖动、战斗和 taint 行为。

## 同一 Provider 在不同版本的业务逻辑

`scope` 只过滤支持范围，不替 Provider 选择代码。Provider 可以为不同 product 或同一 product 的不同数值版本区间使用不同数据源、事件、动作和视图。保持同一业务 Provider ID，在注册前选择唯一实现，提交当前实现的范围和独立 i18n；未选中实现不得启动业务工作。推荐 TOC 分别加载适配模块，共享注册入口。完整示例和边界规则见 [客户端与 build 差异约定](CLIENT_VARIANTS.md)。这使用现有 API 2.2，不新增 variants 注册字段或 GetClient 公共接口。

## 版本与交付门禁

当前 SDK 为 API 2 / revision 7。helper 的 API_REVISION 表示当前能力，MIN_API_REVISION=6 保留默认兼容下限；使用托管资源仍须显式要求 revision 7。版本、错误码和完整文件清单由 tools/sdk_contract.json 统一约束；参见 [交付合同](DELIVERY.md)。

运行 python tools/build_sdk.py --check 与 python tests/sdk_delivery.py；它们已接入完整契约检查。ResultSnapshot、CatalogLedger、InteractionBinding 和 ProviderManagement 是 Host 私有职责，不新增第三方管理员权限或第二套 SDK。

自定义页创建/挂载失败会保留当前首页或搜索内容和焦点。回调中关闭/换查询/进设置优先取消旧导航；替换已释放的自定义页失败时回到当前首页/搜索。固定项原始存档异常时保留原文并提示，暂停固定项写入，避免覆盖；有效存档的角色隔离、顺序、占位与撤销不变。

独立 Lychee Performance Test 插件及工具已按用户要求退役。原历史报告保留用于解释测量，不再作为当前版本的验收证据；本体离线测试和性能预算继续执行。
