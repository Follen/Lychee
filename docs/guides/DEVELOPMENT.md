# 开发与验证

当前版本为 Lychee 0.2.0，SDK / Provider API 1.0.0。运行时唯一来源是 `addon/Lychee`；第三方接入见 [SDK](../../lychee-sdk/docs/GETTING_STARTED.md)，精确字段见 [协议](../../lychee-sdk/docs/PROTOCOLS.md)。

本分支执行[单插件功能迁移](../architecture/2026-09-14-single-addon-feature-port.md)。[架构](../ARCHITECTURE.md)定义现行职责；[旧生命周期设计](../architecture/2026-09-12-runtime-lifecycle.md)和[测试框架记录](../../tests/LIFECYCLE_ACCEPTANCE.md)保留历史背景，不覆盖 SDK 1.0.0 的现行合同。运行时仍为单目录，不增加伴随运行时目录或扩大自动同步范围。

## 环境与目录

- 多客户端原生 AddOn：Mainline `120100`、Mists `50504`、Wrath（泰坦重铸）`38002`、TBC（周年纪念版）`20506`；升级时按对应客户端资料重新核对。
- 本地契约检查使用 PowerShell 7（`pwsh`）、ripgrep（`rg`）和 Lua 5.1（`lua`）；语法检查另需 `luac`。
- `addon/Lychee`：安装到对应客户端的运行时、Bindings 和媒体；本仓库自动同步目标仍仅为下文指定的正式服目录。
- `lychee-sdk`：编辑器类型、可选 helper、集成示例，不作为独立插件安装。
- `tests`：离线契约、交互模拟和性能验证。
- `tools`：TOC／目录／图标生成工具与客户端加载清单，详见 [工具说明](../../tools/README.md)。
- `docs/architecture`、`docs/validation`：设计决策、版本化 API 来源和验证记录。

## 本地检查

在仓库根目录执行：

```powershell
pwsh -NoProfile -File tests/check_contract.ps1
```

该入口检查 TOC 文件存在性、架构边界和关键运行时约束，并运行当前完整的 Lua 契约、交互和性能测试。内置 Provider 测试使用真实 SDK、索引和 ViewHost，替换 WoW 外部 API，覆盖纹章事件生命周期、菜单分页与失败、首领精确跳转。它不执行完整 Lua 解析、XML 解析、wowdoc 验证或真实客户端测试。运行时代码修改还需执行：

```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem addon/Lychee, lychee-sdk, tests -Filter *.lua -File -Recurse | ForEach-Object {
    & luac -p $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $($_.FullName)" }
}
[xml](Get-Content -LiteralPath addon/Lychee/Bindings.xml -Raw) | Out-Null
wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref latest
if ($LASTEXITCODE -ne 0) { throw 'wowdoc validation failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Diff check failed' }
```

修改 Lua/XML/TOC 或 WoW API 前，须按 [AGENTS.md](../../AGENTS.md) 先用 wowdoc 确认来源版本并查询精确符号，保存 sourceId、product、requestedRef、resolvedCommit、path、line 和 excerpt。修改后的 validate 不能替代修改前查档。

索引基准可用 `lua tests/performance/index_benchmark.lua` 或 `lua tests/performance/index_benchmark.lua addon/Lychee/Search/StaticIndex.lua delta` 运行。它只测离线核心索引，不包含完整 SDK 校验、游戏 CPU 或帧时间；比较方法与已测结果见 [框架验证记录](../validation/2026-09-10-provider-framework.md)。

当前菜单图标通过 `node tools/build_flat_menu_icons.cjs` 从扁平图集生成，需要 sharp。原有 `tools/build_menu_icons.py` 是旧版轮廓图标的重建工具；其他 Provider 图标和目录工具见 [工具说明](../../tools/README.md)。生成工具会写入对应运行时资源，按需要单独执行。构建脚本、预览和验证清单不进入游戏副本。

## 安装与第三方示例

正式服安装结构为 `Interface/AddOns/Lychee/Lychee.toc`。只安装 `addon/Lychee` 的运行时文件，不复制 SDK、测试、文档或工具状态。仓库开发流程要求检查通过并创建 Git 提交后，才覆盖复制到 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，随后核对文件清单和 SHA-256；不自动删除目标旧文件。

新增模块或 TOC 变化后重启客户端；仅已加载文件内容变化时可用 `/reload`。系统保存的游戏按键绑定独立于插件存档；默认 Alt+Space 不覆盖已有绑定。

多包开发版到本分支不能只靠覆盖目录完成。先备份并核对原有账号/角色 SV、Provider ID 与具体引用，按[转换交付步骤](DELIVERY.md#从多包开发版转换)隔离旧自带包。Bootstrap 不再因账号 schema 不同而重置整表；各数据所有者仍需校验自己的字段。这不是跨版本迁移保证，来源 ID、业务设置及具体动作引用必须先完成转换核对。API 2 不兼容不等于允许丢弃用户偏好。

演示 AddOn 可将 `lychee-sdk/examples/ThirdPartyFixture` 复制到 `Interface/AddOns/ThirdPartyFixture`，与 Lychee 同时启用并重启客户端。搜索“示例”或英文 `fixture`，可检查普通动作、只读条目、右键次要动作和详情视图。示例拖动仅记录一次普通回调，不会创建游戏物品光标。该示例用于开发验收，不随 Host 正式服同步自动安装。

`DeferredProvider.lua` 是返回注册函数的模块示例，不是独立 AddOn。集成方需在自己的模块加载流程中取得返回函数，再传入 SDK、唯一 Provider ID、条目数组与普通动作回调。示例模拟 0.1 秒延迟、取消和当前条目恢复；不要仅把该文件列入 TOC 就认为已完成注册。

## 客户端验收

离线测试通过后，仍需在真实客户端记录以下结果：

1. 登录后能用绑定呼出，搜索结果与最近使用的点击、右键、拖动及提示一致；只读条目不会误执行。
2. 长名称、不同 UI 缩放、滚动和键盘选择显示正确；详情视图首次状态与后续更新正确。
3. 快速换词、关闭、Provider 所有者停用/注销后，旧查询不回流，相关资源按生命周期停止。另测用户搜索开关：来源不再参与搜索，但后台功能不被误停，明确固定/最近引用按可用性恢复。
4. 技能必须真实鼠标点击，成功后才进入历史；次要技能菜单选择先准备按钮。进入战斗关闭，脱战不自动重开；检查错误日志与 taint。
5. 按 AGENTS.md 在登录、空闲、单目标战斗、多目标/团本、姓名板峰值和配置页面打开/关闭场景记录 CPU、Lua 内存、对象数量和帧时间；无配置页面时注明不适用，并记录搜索窗口打开/关闭样本。

在验证记录中区分自动化已通过项、实机测量值和未测项。历史报告不代表本次迁移通过；未取得本次安装提交对应的真实客户端证据前，战斗、taint、安全点击和性能采样均保持待验收。

## 版本差异实现的验收

Provider 声明多个客户端或版本区间时，按 [客户端与 build 差异约定](../../lychee-sdk/docs/CLIENT_VARIANTS.md) 为每个实际分支验证选择边界、缺失能力、唯一注册、业务行为、独立 i18n、历史／缓存隔离和启停清理。一个客户端的 API 存在性或测试通过不能代替其他分支。分支的 WoW API 证据必须对应正确的 wowdoc product/ref；离线结果与实机结果分开记录。

测试新增/迁移请使用 [测试装配约定](../../tests/README.md)，保留独立的外部替身、业务参照和断言。SDK 资源契约修改必须同步 MANAGED_RESOURCES、ApiStubs 与可执行示例。

发布产物与游戏同步见[交付指南](DELIVERY.md)。文档改动仅运行链接、版本、SDK生成一致性与差异检查；跨源码目录迁移另执行完整契约及运行字节对比。

## 大改动的功能覆盖

修改搜索、Provider/API、Invocation、生命周期、存档、页面交互或跨模块调用，必须用 lychee-dev 做真实客户端功能覆盖。先列用户流程、环境和预期，再覆盖正常、失败、取消、重试、关闭重开，以及改动涉及的角色、语言和客户端分支。搜索改动还须覆盖慢来源与快速来源同时查询、首批可交互结果、6→5→4→3→2→1 条候选回缩、输入法组合、首页引用冷恢复及搜索开关；设置改动覆盖普通条目、默认/右键动作、自然语言参数和实际写入结果；SDK 改动覆盖独立第三方冷加载、注册失败、取消与重新注册。

记录安装提交、运行文件哈希、Ticket、断言和未覆盖项；不能用离线替身、单纯内存采样或截图代替功能结论。

lychee-dev 在本节负责功能覆盖；运行时内存、CPU、延迟分析与 Agent 性能优化另按 [PERFORMANCE.md](../../PERFORMANCE.md) 执行并单独出结论。常规探针走 lychee-dev，不用 computer use 代替；只有无法判断当前游戏状态时才用界面确认。没有可用客户端时保留待验收状态。
