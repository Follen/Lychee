# 子插件存储

本页描述 SDK 1.0.0 的独立存储模块。`Storage.lua` 可单独嵌入业务包；单模块测试不替代包级装配、SavedVariables 时序和实机验证。

## 数据放在哪里

| 数据 | 所有者 |
| --- | --- |
| 面板设置、功能开关、搜索覆盖、固定项、历史、别名与搜索记忆 | Host；仅保存有界偏好、稳定引用和必要显示回退 |
| Provider 业务设置、业务版本、可重建持久缓存 | 所属子插件的 SavedVariables |
| 当前查询候选、任务和待加载对象 | 当前查询作用域；完成、取消或关闭后释放 |
| 模型、Frame、回调、实例、查询运行状态 | 仅运行时，不写入 SavedVariables |

SDK 提供共同的数据规则，不提供一个集中存放所有业务的 Host 数据库。子插件自己在 TOC 声明 SV，并在存档恢复后交给存储工具使用。普通角色设置使用 `SavedVariablesPerCharacter`；需要账号共享的数据另行明确声明，不能将角色设置自动提升为账号设置。

## 绑定子插件的命名空间

把 `Storage.lua` 嵌入子插件并在 TOC 中列于使用者之前。它把模块放在该 AddOn 私有 namespace 的 `LycheeSDK.Storage`，不写全局 SDK 单例；多份嵌入互不覆盖。以下访问器由子插件在自己的存档恢复时初始化数据根和 ready 标记；这段代码本身不会初始化 SV。

```lua
local addonName, ns = ...
local settings = assert(ns.LycheeSDK.Storage.Open({
    id = "example.feature",
    version = 1,
    root = function() return ExampleCharacterDB.providerSettings end,
    ready = function() return ns.savedVariablesReady == true end,
}))

local enabled, err = settings:Get("showDetails", true)
if err then return end
local ok, writeError = settings:Set("showDetails", false)
```

`Open` 配置只允许 id、version、root、ready、migrations；配置和迁移表必须是可访问的普通表，拒绝 metatable、secret 字段和未知键。

`root` 是当前角色的一个专用表访问器，不是首次加载时保存的表引用。SDK 每次操作重新取得根，能正确处理角色恢复、导入或根表替换。`ready` 返回 true 之前拒绝读写；根不存在或不是普通表时返回错误，不猜测、不提前覆盖 WoW 尚未恢复的存档。不要在这些访问器中启动业务或切换角色。

SDK 仅读写 `root()[id]`，保存结构为 `{version = n, values = {...}}`。同一包中每个 Provider 使用独立 ID 和版本。缺失值返回隔离复制后的默认值，不落盘默认值；`Set(key, nil)` 删除一个键。读取和写入不向调用方泄露存档内表的可变引用；不修改传入值。`Close()` 会断开访问器引用并拒绝后续操作，不删除用户存档。

这不是查询缓存。普通设置不会自动淘汰。键数、逻辑字节、深度、节点和单值大小继续遵循 [PERFORMANCE.md](PERFORMANCE.md) 的设置门禁；超限、循环引用、不可访问值或损坏数据返回错误，原数据不被替换。逻辑字节不能当作实机 Lua 堆统计。

存储句柄属于子插件的数据层，不属于单次 query 或 view。面板关闭后仍可由必要的业务事件更新设置。Provider 注销不会替子插件关闭独立句柄；若句柄只供该实例使用，子插件应在实例释放时调用 `Close()`，重新注册时重新打开。同包共享的数据层可继续存在，但不能因此保留旧 Provider、页面或查询引用。SDK 不增加定时保存、轮询或强制 GC。

## 显式升级

`Get` 和 `Set` 不自动迁移。存档较旧返回 `STORAGE_MIGRATION_REQUIRED`；存档比代码更新返回 `STORAGE_NEWER_VERSION` 并拒绝写入，不能使用旧默认值覆盖新格式。

```lua
local settings = assert(ns.LycheeSDK.Storage.Open({
    id = "example.feature",
    version = 2,
    root = function() return ExampleCharacterDB.providerSettings end,
    ready = function() return ns.savedVariablesReady == true end,
    migrations = {
        [1] = function(values)
            values.showDetails = values.expanded
            values.expanded = nil
            return values
        end,
    },
}))
local ok, err = settings:Migrate()
```

迁移函数只处理 SDK 提供的当前命名空间副本，返回新值表，不直接修改 SV 或兄弟来源。SDK 按版本顺序执行并逐步校验，整条成功后一次替换目标命名空间。缺步骤、异常、超限、关闭句柄、替换角色根或并发替换该命名空间时拒绝提交并保留原存档。单次最多 32 步，不支持无限历史链。迁移回调是同步 Lua，SDK 不能抢占慢回调；业务须保证工作量有界并在非战斗初始化入口执行。

跨数据所有者搬迁是一次明确的数据所有权迁移，不能仅靠 schema 步骤隐式删除外部源。`Import(values)` 对普通设置执行整份有界校验与复制，一次提交到尚不存在的命名空间；已有目标返回 `STORAGE_EXISTS`，不合并、不覆盖。不能用多次 `Set` 代替原子搬迁。

迁移所有者应先确认来源身份及版本，调用 `Import`，保存来源凭据并保留旧字段；后续会话完整验证目标可用后，再请源所有者核对来源未变化并确认清理。目标已有内容但没有本次成功迁移证据时保留旧数据，由所有者明确处理冲突；不能根据“目标存在”猜测搬迁成功。任何失败都保留旧原文。SDK 不扫描 Host DB，不知道哪些旧字段属于谁，也不替调用方删除源数据。

`ready`、`root` 和迁移函数中的同句柄操作返回 `STORAGE_BUSY`，避免回调递归；回调关闭句柄后不再继续读写。目标根或命名空间被替换时返回 `STALE_STORAGE`，不能把旧角色的结果写入新根。所有错误都应由初始化或编辑入口处理，不能自行启动无界重试。

## 大缓存与加载

成就目录等大型缓存不适合通用 Settings。由所属成就模块使用专门 schema 和原容量预算，明确定义角色、语言、客户端、版本、失效、重建和增量事件。不能为容纳它扩大每个 Provider 的通用设置额度，也不能每次读取复制整个目录。

无持久化需求的包不创建空 DB。已加载 SV 仍占 Lua 内存；把字段从 Host 搬到子插件不会自动减少整体内存。需要真正延迟读取的缓存必须有明确的独立加载单位，并把其内存、首查延迟、迁移和发布成本计入全部功能包合计。

## 单插件内置模块与第三方

当前发行只包含 `addon/Lychee` 一个原生 AddOn。Host 框架偏好与内置业务数据在逻辑上分开：各 Provider 模块拥有自己的专用命名空间、schema、失效规则和迁移责任；通用搜索层不能扫描或复制所有业务 DB。不要把同包命名空间称作原生独立 SavedVariables，更不能声称关闭页面能卸载它。

第三方仍是独立 AddOn，自有 TOC、SV、代码和媒体。它可以嵌入 Storage.lua；不能读取 `LycheeInternal`、借用 Host 业务存档或引用 Host 私有媒体。成就这种大型缓存使用所属模块的专用 schema，不扩大通用设置容量。

当前单插件合同不承诺 `RegisterMigrationOwner`、`GetMigrationOwner` 或 `RequestMigrationOwner` 公开 API。十包版迁回本分支时，先备份实际存档，再根据明确的来源 ID/schema 制定一次性迁移；目标验证成功之前保留原数据。不能把“不兼容 API 2”解释成可以清空用户设置。

## 验证

`tests/sdk/sdk_storage.lua` 覆盖未恢复存档、无 Host 运行、命名空间隔离、复制隔离、根替换、容量、原子导入、显式迁移、重入和未来版本拒写。离线模块测试不证明当前玩家存档已经迁移，也不证明客户端 SV 时序正确；相关实机证据单独登记。
