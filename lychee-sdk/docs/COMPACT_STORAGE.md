# 调用方自有的可选紧凑存储

SDK/API 1.0.0。普通目录不必使用本模块；按需条目模式、可选存储与自有检索是可独立选择的能力。搜索入口先读 [CATALOG](CATALOG.md)，普通设置持久化读 [STORAGE](STORAGE.md)。

## 两种接入方式

使用Host提供的Catalog时，将 `compact={maxEntries,maxBytes,maxRecordBytes,identity}` 放在 `mode="documents"` 配置中。先检查 `SDK.SupportsFeature("search-documents",1)` 和 `"compact-storage"`；目录和存储实例仍由调用插件持有，Host没有全库总表。

已有自己的查询引擎，只需要存储时，把SDK发行中的 `CompactStore.lua` 放入自己插件，例如vendor目录，并在自己的TOC中先加载它、再加载业务文件。该文件通过同一插件namespace提供工厂，不依赖Host已加载：

```text
vendor/CompactStore.lua
MyProvider.lua
```

```lua
local addonName, ns = ...
local Store = ns.LycheeSDK.CompactStore
local store, err = Store.Create({
    maxEntries = 1000,
    maxBytes = 512 * 1024,
    maxRecordBytes = 4096,
    identity = { schema=1, product="retail", locale="enUS", revision="my-data-1" },
})
if not store then return end -- 实际插件应把err显示或记录到自己的诊断
assert(store:Update({replace={{id="example",title="Example",aliases={"demo"}}}}))
local record = store:Read("example")
```

这里的数字仅为示例声明，不能直接作为任意目录的预算。业务作者必须测量自己的规模、首次构建、读取、更新及关闭成本。编码是SDK内部细节；对外仍为具名记录，业务引用永远保存稳定ID，不保存偏移或内部编号。

## 容量和输入

maxEntries、maxBytes、maxRecordBytes均必填，为正的有限安全整数。maxBytes和maxRecordBytes是包含键的逻辑字节，字符串按实际字节，其余节点按16计；不等于Lua堆、压缩后字符串长度或插件面板内存。schema/产品/语言/上游版本等identity是调用方明确提供的有界普通表，最多4096逻辑字节；SDK只保留和返回隔离副本，不替业务判断其是否仍有效。

记录必须为普通具名表并有合法id：1–128字节，首字符ASCII字母或数字，后续ASCII字母数字或 `._:/-`。拒绝secret/不可访问值、metatable、循环、函数、非有限数字、超深/超大结构。单表最多128字段，嵌套深度受8层边界约束。容量失败显式返回Error，保留旧代，不截断文本、丢记录或自动淘汰业务数据。

## 方法和代次

| 方法 | 结果与语义 |
| --- | --- |
| `Update({replace=records})` | 原子替换；不能与upsert/remove混用。空数组清空，false为非法输入。 |
| `Update({upsert=records,remove=ids})` | 原子更新；同批重复ID或写删冲突拒绝。无变化保留代次。 |
| `Read(id,out?,revision?)` | 返回隔离具名记录；不存在返回nil。提供out时成功读取后替换其内容，输入错误不修改out。 |
| `Iterate(revision?)` | 返回迭代函数，仅产出稳定ID，不保证顺序；发生实际变化的Update、Clear或Close后，尚未结束的旧迭代器失效，不转读新代；无变化Update不换代。 |
| `GetState()` | 隔离摘要：revision、entries、bytes、三项容量和identity，不导出数据全集。 |
| `Clear()` | 清记录并使旧读者失效，可再次更新；不删除调用方自己的业务事实或SV。 |
| `Close()` | 永久结束，断开记录和identity引用；重复Close安全。 |

成功Update返回true，第三返回值表示是否变化；失败返回nil,Error。已耗尽或已报告一次失效的迭代器后续只返回nil。Close后Read/Update/Iterate/GetState返回RESOURCE_CLOSED，Clear/Close仍幂等返回true。过期读者返回STALE_RESULT，退休存储返回RESOURCE_CLOSED，结构/容量等错误沿用SDK错误边界。迭代过程中如需区别“结束”与“失效”，手动检查第二返回值；不要依赖普通for循环吞掉错误：

```lua
local state = assert(store:GetState())
local nextID, err = store:Iterate(state.revision)
if not nextID then return end
while true do
    local id, why = nextID()
    if why then break end -- 记录诊断或按新代重试
    if not id then break end
    local value, readError = store:Read(id, nil, state.revision)
    if readError then break end
    -- 处理value；不把它反写内部数据，更新使用Update。
end
```

## 数据与生命周期边界

本模块不扫描业务API、不注册事件、没有timer和全局实例注册表，不写SV，也不自动预热。谁创建存储实例，谁决定何时Update/Clear/Close；Catalog的Invalidate另见目录契约。临时查询资源不能被持久缓存捕获；取消后不能保留查询请求、reply、Frame或动作凭据。

持久化由所属插件的TOC/SV和独立有界schema承担。SV本身加载后占内存，不能说只有diff常驻。发布生成事实不应无理由再复制一份SV；可再生缓存与用户设置分开，身份变化时不清用户引用。实例的identity不可原地修改；作者新建匹配身份的实例，再交接并关闭旧实例。底稿/差量、合并阈值和编码布局均不是公共字段协议；未来实现改变内部表示时，读写合同和容量仍需保持。

CompactStore只存数据，不等于搜索索引。Catalog负责搜索字段、匹配、排名和Entry生成；它必须把共同保留成本一并测量，不能只报压缩字符串大小。具体表示选择及结果见项目的搜索重构验收记录；尚未取得实机结果的部分不能宣称已达性能目标。
