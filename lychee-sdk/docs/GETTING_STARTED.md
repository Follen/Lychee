# 接入 Lychee SDK 1.0.0

使用 Provider API 3 / revision 1。不兼容 API 2；运行时入口是 `_G.Lychee`，开发包不是另一个 AddOn。先阅读[协议](PROTOCOLS.md)、[性能硬门禁](PERFORMANCE.md)和[能力边界](CATALOG.md)。

## 最小可用接入

在自己的 TOC 声明 `## OptionalDeps: Lychee`。以下代码只使用公开 SDK，不需要荔枝的目录、Manifest、Modules 或启动模板：

```lua
local api=_G.Lychee
if not api or not api:Supports(3,1) then return end
local function register()
    local entry={id="settings",title="Example settings",actions={"open"}}
    local handle,err=api:RegisterProvider({
        id="example.settings",apiVersion=3,minApiRevision=1,version="1.0.0",
        title="Example",scope={products={"retail"}},i18n={enUS={}},
        searchGlobal=true,searchPrefixes={"example"},searchKeywords={},
        query=function(request,reply)
            if request.normalized=="" or request.normalized:find("example",1,true) then
                local hits,why=api.SDK.Score(request,{entry})
                if not hits then error(why.code) end
                reply(hits)
            else reply({}) end
        end,
        resolve=function(id) if id==entry.id then return entry end end,
        actions={open={title="Open",run=function()
            -- Replace with your already verified ordinary UI action.
            print("Example opened")
            return {ok=true,close=true}
        end}},
    })
    if not handle then error(err.code) end
end
api:RegisterReady(register)
```

`query` 返回 `nil` 或取消函数，不能 `return reply(...)`：回复返回布尔状态，不是取消函数。同步和异步查询都最多回复一次；失败须处理，不能把无结果当成成功。

## 谁保存数据

Host 收到查询候选，不收到完整业务目录。小型固定列表可以像上面一样由 Provider 自己保存；需要统一文本匹配和增量目录时选择 [CreateCatalog](CATALOG.md)。动态数据也可自行筛选、评分，只要满足相同结果合同。

每个结果最多包含当前展示和动作所需数据。稳定内容提供 `resolve(entryID,context)`；Host 的固定、历史和别名只保存引用，再从当前 Provider 恢复。一次性动作可设 `rememberable=false`。

## 搜索入口

`searchGlobal` 默认 true；`searchPrefixes` 和 `searchKeywords` 各最多 8 项，支持空数组。前缀 `example:内容` 限定来源，触发词 `example` 将请求转换为该来源的空查询。普通搜索关闭时必须保留至少一种快捷入口。用户在管理页覆盖这些入口，不修改 Provider 原始声明。

## 生命周期和数据库

必要的数据更新事件放在启用期间，查询任务放在 `context.resources`，页面任务放在当前 view 的资源作用域。采用 SDK 资源工具不免除业务分批和容量责任；见[生命周期](RUNTIME_LIFECYCLE.md)。

数据库由自己的 TOC 声明并由自己的 AddOn 所有。等待自身 SavedVariables 就绪后，将根函数交给 [Storage](STORAGE.md)。角色设置用 `SavedVariablesPerCharacter`；关闭面板不删除设置。Host 不提供 `handle:Settings()`。

完整可运行例子见 [ThirdPartyFixture](../examples/ThirdPartyFixture/ThirdPartyFixture.lua)；托管任务见 [ManagedProvider](../examples/ManagedProvider.lua)，页面见 [ComponentPanel](../examples/ComponentPanel/ComponentPanel.lua)。

## 接入测试至少覆盖什么

直接向公开接口传原始定义，验证缺失必填字段和旧 API 被拒绝；不要让测试包装器补齐字段后宣称校验有效。覆盖连续输入取消、迟到回复、禁用/重新启用、动作身份失效、外部修改隔离、失败后重试，以及关闭后的资源回收。Catalog 与自己管理的动态 query 应接受同样的结果契约。

有数据库时测试自身存档恢复前后、根替换、角色隔离、迁移失败和未来 schema 保留；有页面时测试 Mount 失败、按下后重绑、关闭/重开和对象复用。原生 API 替身只提供外部输入，不实现 SDK 内部算法。离线通过后仍需目标客户端验证战斗、安全点击和显示效果；固定场景预算见[性能约束](PERFORMANCE.md)。
