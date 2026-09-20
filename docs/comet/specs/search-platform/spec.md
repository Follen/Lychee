# Lychee Unified Search Platform

> 历史规格：保留已归档 change 的设计快照，包含当前已移除或调整的接口，不作为 SDK 1.0.0 或当前运行代码的实现要求。现行入口见 [架构](../../../ARCHITECTURE.md)、[设计规范](../../../../DESIGN.md) 和 [SDK](../../../../lychee-sdk/README.md)。

## 1. 目标

Lychee 提供一个由 Host 统一管理的搜索平台。内置功能和第三方插件都提交相同的 SearchSource/SearchRecord 数据；Host 负责建立活动索引、匹配、置信度、去重、排序和结果渲染。Provider 不绘制根 UI，也不在每次按键时自己扫描数据。

## 2. 分层

```text
SearchSource
  -> SearchRecord snapshot / upsert / remove
  -> Host SearchIndex
  -> SearchResult {record, confidence, evidence}
  -> Action / Intent / Panel / Secure / Drag
```

- `SearchSource` 是数据来源和生命周期边界，可以属于 Buildin 或第三方 Extension。
- `SearchRecord` 是可搜索实体，不区分技能、成就、任务、副本还是第三方内容。
- `SearchIndex` 是 Host 所有的预索引，Provider 不直接操作桶、评分或 UI。
- `Action` 是结构化动作描述；普通 Intent、Panel、secure spell 和 drag 都由 Host 验证后执行。
- `SearchSession` 唯一拥有 Palette session、query generation、防抖、取消和结果接纳；`ResultActionExecutor` 统一验证并委托四类动作。

## 3. SearchSource

```lua
Lychee:RegisterSearchSource({
    id = "mrt",
    version = 1,
    priority = 80,
    scope = {
        product = "retail",
        minInterface = 120000,
        maxInterface = 120999,
    },
    revision = 7,
    snapshot = function(context)
        return records
    end,
})
```

Source 必须声明稳定 ID、协议版本、优先级、scope、revision 和 snapshot/update 能力。提交后由 Host 分配 source generation。Source 更新通过 `BeginSnapshot`/`Upsert`/`Remove`/`CommitSnapshot` 或显式 `Invalidate(key)` 完成；Host 合并同帧更新，迟到 generation 直接丢弃。

Source 不得注册 Lychee 级快捷键、取得 Palette 根 frame、创建 Host 结果行、返回函数/Frame/宏文本或在 resolver 中执行动作。第三方发现仍以 `_G.Lychee` facade 和明确 `Commit()` 为准，不以 AddOn 目录扫描或已加载状态为准。

## 4. SearchRecord

```lua
{
    id = "spell:393256",
    kind = "spell",
    category = {
        id = "spells",
        title = { default = "Spell", zhCN = "技能" },
        icon = 135875,
        order = 10,
    },
    title = "利爪防御者之路",
    aliases = {
        { text = "红玉", locale = "zhCN" },
        { text = "ruby life pools", locale = "enUS" },
    },
    keywords = { { text = "传送", locale = "zhCN" } },
    description = { { text = "传送至红玉新生法池入口。", locale = "zhCN" } },
    icon = 4578416,
    scope = { product = "retail", minInterface = 120000, maxInterface = 120999 },
    actions = {
        { id = "cast", kind = "secure-spell", spellID = 393256 },
    },
    drag = { type = "spell", spellID = 393256 },
}
```

`id` 是全局稳定实体 ID；同一技能的 canonical title、别名、关键词和描述都必须指向同一个 ID。`kind` 用于稳定语义，`kindTitle` 由 Source/Provider 提供类型显示名，`category` 用于用户可见前置标签和类别筛选。类别文案、kindTitle、title、aliases、keywords、description 可以是 string 或带 locale/scope 的文本条目；Host 不维护 kind 到文案的字典。

## 5. Locale/Build scope

Host 在登录或版本变化时读取 `GetLocale()` 和 `GetBuildInfo()` 的 locale、product、version、build、interface 字段，形成：

```text
indexSignature = schema + product + interface + build + locale + sourceRevision
```

文本条目和记录 scope 允许 `locale`、`product`、`minInterface`、`maxInterface`、`minBuild`、`maxBuild`。建索引时只接受当前 locale、`default` 和当前 product/interface/build 范围；其他文本保留在 source 数据中但不进入活动桶。查询热路径不再次判断 scope。

locale、Build、schema 或 source revision 改变时，Host 使活动索引失效并重建；SavedVariables 只能恢复 signature 完全一致的 plain-data 索引，并可做有限 live spot-check。

## 6. 索引和候选召回

Host 为每条记录建立字段引用和倒排桶：canonical title、alias、keyword、description、category title。规范化使用当前 locale 的大小写、标点、空白和 Unicode 规则；中文保留连续文本，英文和数字生成 token；拼音、缩写和同义词作为可选派生字段。

候选召回顺序：

1. exact/prefix token map；
2. 2/3-gram 倒排桶；
3. 上一代候选集的增量缩小；
4. 仅在查询长度和预算允许时运行拼写/编辑距离候选。

索引构建可以分帧执行，结果保存 canonical record 引用而不是复制 payload。查询热路径不得枚举 AddOn、扫描全量 Provider、创建 Frame、启动无界 timer 或调用网络/生成式模型。隐藏 Palette 时取消待执行搜索。

## 7. 匹配、置信度和证据

每个候选产生 `confidence`（0.0 到 1.0）和一条 evidence：

```lua
{
    confidence = 0.98,
    matchedField = "alias",
    matchedText = "红玉",
    matchType = "exact",
}
```

建议匹配层级：exact canonical 1.00、exact alias 0.98、canonical prefix 0.90、alias prefix 0.86、全部 token 命中 0.82、substring 0.74、keyword 0.62、description 0.48、有限 fuzzy 0.30-0.55。实际实现可按字段长度和语言校准，但必须保持 exact > prefix > token > keyword/description > fuzzy 的单调关系。

最终排序依次比较 confidence、source priority、category order、record stable ID；用户置顶/最近使用只能作为同一匹配层级内的有限 boost，不能越过精确命中。一个 record 被多个字段命中时只保留最高 evidence。

## 8. SearchResult 和动作

```lua
{
    record = canonicalRecord,
    confidence = 0.98,
    evidence = evidence,
    enabled = true,
    actions = validatedActions,
}
```

SearchSession 只发布当前 session/query generation 的结果；ResultActionExecutor 再按 source state、Extension 生命周期、availability 和 combat 状态校验每次交互。`open-panel` 通过同 Extension 的 PanelFactory；普通动作通过 IntentRouter；`secure-spell` 只能绑定 Host 自己的 SecureActionButton 并要求真实硬件点击；`drag-spell` 只能在脱战、当前玩家已知且可用时调用 `C_Spell.PickupSpell`。Provider 和 Palette 不直接执行这些动作。

## 9. 启动面板和搜索态

Alt+Space 打开 Host-owned Palette。空输入显示 ZTools 风格 HomeView：最近使用、已固定、按 category 分组的入口和第三方 source 入口。最近/固定只保存稳定 ID，不保存完整 payload。

非空输入切换 SearchView：结果使用池化的 Host-owned tile/row renderer，至少显示 icon、category badge、localized title、description/subtext、confidence evidence 对应的轻量命中提示和有限 action slots。布局可以由 Host 在密集列表和两列网格间选择，但不回退为没有类别和动作区的旧式下拉列表。

类别至少包括 `spells`、`achievements`、`quests`、`dungeons`、`extensions`，第三方自定义类别必须以其 Extension ID 为前缀。类别本身可作为 query filter，例如 `技能 翅膀`，但类别标签不替代稳定 record ID。

## 10. 生命周期和性能

- Source 注册、snapshot、upsert、remove、disable 和 unregister 都产生可追踪 revision；只失效所属记录。
- Palette 隐藏时无常驻 per-frame Lua 回调；事件驱动刷新，必要的 debounce/ticker 可取消且有 generation guard。
- 快速连续输入、IME 修订、关闭、进战和 source/Extension 失效使旧 token 失效；不可取消的迟到回调不能发布结果。
- 索引、结果卡片、图标和动作槽池化复用；setter 有 change guard；Provider 数据更新不重建无关类别。
- 每轮查询有候选上限、结果上限和 fuzzy 时间预算；超预算只保留已完成的高置信度候选并记录稳定诊断码。
- 所有 Source/Record/Action 边界先执行 secret/inaccessible/plain-data/schema 校验，失败值不进索引、排序、缓存或日志。

## 11. 兼容和验收场景

- 当前角色实时已知技能及其描述可搜索；“翅膀”和“红玉”分别命中对应技能 ID。
- 不同 locale 的别名互相隔离；不同 interface/build scope 的记录不在当前客户端出现。
- 内置与第三方记录可以同时返回，类别标签和 stable ID 保持正确，重复别名不产生重复行。
- Boss/M1、任务、成就和 MRT fixture 共享相同的索引和动作协议。
- 空输入 HomeView、输入 SearchView、点击普通动作、打开 Panel、secure 点击、spell 拖拽和战斗关闭均可由离线 interaction contract 覆盖；Retail API 兼容性通过 wowdoc validate 检查。
