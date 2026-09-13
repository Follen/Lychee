# Lychee 当前架构

SDK 1.0.0，Provider API 1.0.0，UI Runtime 1。协议以 [SDK](../lychee-sdk/docs/PROTOCOLS.md) 为准，性能只引用 [PERFORMANCE.md](../PERFORMANCE.md)。

## 五个运行时包

| 包 | 职责 | 持久数据 |
|---|---|---|
| Lychee | 注册/权限、查询调度与合并、稳定引用、通用 UI、动作执行 | Host 设置，角色的固定/历史/别名/搜索入口与启用选择。 |
| Lychee_Player | 技能、坐骑、物品、装备/天赋方案、成就、游戏菜单、暴雪设置、纹章、宝库、钥匙 | LycheePlayerCharacterDB：角色业务设置、成就权威目录。 |
| Lychee_Encounters | 团本首领及普通/英雄/史诗技能，荔枝大米助手 | 目前无 SV；打包事实关系和有界运行时查询/详情。仅正式服加载业务。 |
| Lychee_Integrations | Ellesmere / Exwind 适配 | 不接管上游数据库，目前无自身 SV。 |
| Lychee_Inspector | 插件识别、选择与检查页面 | 目前无 SV。 |

每个子插件通过 WoW 的私有命名空间加载，依赖 Lychee 并只调用公开 SDK。源码没有 Builtin 目录，Host 没有子插件 Modules。Manifest/Bootstrap/Activate 是项目包内装配，不是第三方必须实现的 SDK 形状。

## 查询与数据流

输入 → SearchSession 管理代次 → ProviderPolicy 解释入口与用户选择 → 各 Provider.query → 有界候选 → Host 校验/排序/渲染 → 当前身份下执行动作。

Host 在每次查询入口冻结角色固定项、最近使用顺序和同词选择记忆，只把本来源的 ranking/preferredEntryID 发给 Provider。SDK Catalog 和动态来源的 CreateRanker 在候选截断前应用偏好，Host 最终用自己的快照重算排名；原始匹配证据不变。UserPreferences 负责固定和最近使用记录，首页消费这些有界引用；不保存次数/时间戳。规则与成本见[个性化排序设计](architecture/2026-09-13-personalized-ranking.md)。

ProviderRuntime 将候选与仍在等待的状态一起交付 Query；Query 的同步返回与异步通知保持相同进度语义，合并中的外部别名解析若重入发布，以更新的发布为准。SearchSession 通过 Palette:ApplySearchState 一次交付会话、查询代次、等待标志及结果，不再旁路读取 Provider 作业或直接修改界面字段。取消回调重入后，旧操作停止后续提交；筛选与来源刷新沿用同一发布路径。这是内部协作，不改变公开 SDK，也不把查询进度写入每条 ResultSnapshot。

目录型 Provider 可以创建自己的 SDK Catalog，Update 原子提交具名普通记录；动态来源可独立查询。Host 不再接受全量 entries 注册或 handle:Update，不保存第二份完整业务目录。Catalog:Search 返回副本，Catalog:Query 可直接向当前回复交付已校验候选；后者仍对实际注册能力进行比较，未知能力回到完整公开校验。

记录是具名字段，业务语义与动作不变。内部结果投影可共享同一代不可变来源元数据，旧代投影保持旧身份；不向 SDK 暴露位置数组、凭证或 metatable。数据变化必须 Invalidate，使旧动作、历史恢复和页面状态重新验证。

## SDK 与包内协作

[公共能力清单](../lychee-sdk/docs/CATALOG.md)解释每项能力的用途、输入输出和所有权。公开 SDK 不负责加载项目 Modules、枚举内部 Definitions、安装 Provider 业务事件，也不规定第三方目录结构。

CatalogLedger/CatalogProvider 仅是 Player/Encounters 自己的目录协作。相同源码由构建检查保持一致；界面动作因语言归属不同单独维护。少量私有重复比强制所有接入采用项目装配更合适。

## 数据库边界

业务 DB 由拥有它的子插件在自身 TOC 声明。SDK Storage 只提供副本隔离、容量限制、显式版本迁移和 Close；root/ready 由调用方提供。Host 不建立 providerSettings 通用仓库。

Player 等自身 ADDON_LOADED 后初始化角色 DB，并仅搬迁自己认识的旧设置和成就数据；成功后才移除对应旧键，未知命名空间、损坏或未来版本原样保留并报告错误。一次性迁移不是 API 2 兼容。其他包无持久需求时不创建空 DB。

## 管理页与页面

HomeView 拥有首页固定项/最近使用的恢复、dirty、容量计划、一次过期重建、交互绑定与关闭释放；继续复用 UserPreferences 和 ResultActionExecutor 的存储/动作规则。Palette 只协调首页显示、整体尺寸及导航，不遍历其 tiles/sections。首页进入搜索时仅隐藏，完整窗口关闭才释放活动引用；布局缓存与原生池保留，恢复过程不增加轮询。

管理页来自已注册 Provider，按来源包分组。用户关闭后保留条目以便重新打开；源注销即消失。用户开关与上游缺失/客户端不支持的运行时不可用分开。默认启用所有成功注册的来源，包括 EUI/EX，是否全局搜索由各自入口声明决定。

长来源标签保持单行、有上限的宽度和截断，不挤压主标题。设置、搜索结果与提示使用同一 Provider 展示元数据。页面复用和动效遵守 [DESIGN.md](../DESIGN.md)；ViewHost 不存具体怪物/技能/钥匙逻辑。

## 验证与交付

使用真实五包 TOC 和私有命名空间验证加载、语言、SDK 输入、异步取消、存储迁移、旧点击及性能。原有分配和常驻预算不因拆包而提高；加载统计是五包合计。工具生成和压缩关系数据以独立事实快照逐条校验。

目录、构建和安装见 [项目结构](guides/PROJECT_STRUCTURE.md)、[交付步骤](guides/DELIVERY.md)。历史设计和证据保留当时事实，当前文档优先。
