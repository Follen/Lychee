# Lychee SDK：Provider API 2

SDK 的主要入口是 `Lychee:RegisterProvider`。内置玩家技能、坐骑、纹章、游戏菜单、首领、宏伟宝库和第三方示例使用同一接口。字段与限制见 [协议参考](PROTOCOLS.md)，编辑器类型见 [ApiStubs.lua](../lychee-sdk/ApiStubs.lua)。

## 最小接入

第三方 TOC 声明 `## OptionalDeps: Lychee`。SDK 缺失时插件自身仍能运行。

```lua
local SDK = _G.Lychee
if not SDK or not SDK:Supports(2, 1) then return end

local provider, err = SDK:RegisterProvider({
    id = "my-addon.search",
    apiVersion = 2,
    version = "1.0.0",
    title = "My AddOn",
    entries = {
        { id = "settings", title = "My AddOn 设置", keywords = { "选项", "options" },
          actions = { "open" } },
    },
    actions = {
        open = { title = "打开设置", run = function(entry, context)
            MyAddon.OpenSettings() -- 由你的插件实现
            return { ok = true, close = true }
        end },
    },
})
if not provider then MyAddon.ReportIntegrationError(err.code) end
```

不需要另外注册 Command、SearchSource、IntentHandler 或 CapabilityProvider。条目不声明 actions 时就是可搜索信息，不会被 Host 自动当成可施放或可拖动对象。

## 事件驱动更新

```lua
provider:Update({ upsert = {
    { id = "status", title = "当前状态", subtitle = "已连接" },
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

每次动态候选最多 256 条；Provider 应参考 request.limit 尽早减少计算，Host 决定最终排名。回调不能 yield、阻塞或声称能通过 Host 超时机制中断自己的同步 Lua。可直接运行的定时回复示例见 [DeferredProvider.lua](../lychee-sdk/examples/DeferredProvider.lua)。

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

完整可安装示例见 [ThirdPartyFixture](../lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua)：包含普通动作、只读条目、独立拖动、视图状态和卸载清理。

## 验证接入

检查注册/更新返回值；业务失败返回 `{ok=false,code="MY_ERROR",message="给用户的简短原因"}`。不要把异常堆栈、secret 值或 frame 放进数据协议。Host 诊断有界，第三方仍应自行记录必要的集成错误。

运行 `pwsh -File tests/check_contract.ps1` 可复现本仓库契约测试。游戏内验证搜索/最近使用交互一致、关闭后事件与 timer 停止、旧查询不回流，以及真实施法、拖动、战斗和 taint 行为。
