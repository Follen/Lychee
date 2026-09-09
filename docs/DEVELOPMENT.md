# 开发与验证

当前版本为 Lychee 0.2.0，Provider API 2 / revision 1。运行时唯一来源是 `package/Lychee`；第三方接入见 [SDK](SDK.md)，精确字段见 [协议](PROTOCOLS.md)。

## 环境与目录

- 正式服原生 AddOn，当前 TOC 的 Interface 为 `120100`；支持目标需按对应客户端资料核对。
- 本地契约检查使用 PowerShell 7（`pwsh`）、ripgrep（`rg`）和 Lua 5.1（`lua`）；语法检查另需 `luac`。
- `package/Lychee`：安装到正式服的运行时、Bindings 和媒体。
- `lychee-sdk`：编辑器类型、可选 helper、集成示例，不作为独立插件安装。
- `tests`：离线契约、交互模拟和索引性能脚本。
- `docs/architecture`、`docs/validation`：设计决策、版本化 API 来源和验证记录。

## 本地检查

在仓库根目录执行：

```powershell
pwsh -NoProfile -File tests/check_contract.ps1
```

该入口检查 TOC 文件存在性、架构边界和关键运行时约束，并运行 10 个 Lua 契约/交互测试。它不执行完整 Lua 解析、XML 解析、wowdoc 验证或真实客户端测试。运行时代码修改还需执行：

```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem package/Lychee, lychee-sdk, tests -Filter *.lua -File -Recurse | ForEach-Object {
    & luac -p $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $($_.FullName)" }
}
[xml](Get-Content -LiteralPath package/Lychee/Bindings.xml -Raw) | Out-Null
wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest
if ($LASTEXITCODE -ne 0) { throw 'wowdoc validation failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Diff check failed' }
```

修改 Lua/XML/TOC 或 WoW API 前，须按 [AGENTS.md](../AGENTS.md) 先用 wowdoc 确认来源版本并查询精确符号，保存 sourceId、product、requestedRef、resolvedCommit、path、line 和 excerpt。修改后的 validate 不能替代修改前查档。

索引基准可用 `lua tests/index_benchmark.lua` 或 `lua tests/index_benchmark.lua package/Lychee/Search/StaticIndex.lua delta` 运行。它只测离线核心索引，不包含完整 SDK 校验、游戏 CPU 或帧时间；比较方法与已测结果见 [框架验证记录](validation/2026-09-10-provider-framework.md)。

## 安装与第三方示例

正式服安装结构为 `Interface/AddOns/Lychee/Lychee.toc`。只安装 `package/Lychee` 的运行时文件，不复制 SDK、测试、文档或工具状态。仓库开发流程要求检查通过并创建 Git 提交后，才覆盖复制到 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，随后核对文件清单和 SHA-256；不自动删除目标旧文件。

新增模块或 TOC 变化后重启客户端；仅已加载文件内容变化时可用 `/reload`。0.2.0 升级不迁移旧 schema，旧 `LycheeDB` 整表重置。系统保存的游戏按键绑定独立于该表；默认 Alt+Space 不覆盖已有绑定。

演示 AddOn 可将 `lychee-sdk/examples/ThirdPartyFixture` 复制到 `Interface/AddOns/ThirdPartyFixture`，与 Lychee 同时启用并重启客户端。搜索“示例”或英文 `fixture`，可检查普通动作、只读条目、右键次要动作和详情视图。示例拖动仅记录一次普通回调，不会创建游戏物品光标。该示例用于开发验收，不随 Host 正式服同步自动安装。

`DeferredProvider.lua` 是返回注册函数的模块示例，不是独立 AddOn。集成方需在自己的模块加载流程中取得返回函数，再传入 SDK、唯一 Provider ID、条目数组与普通动作回调。示例模拟 0.1 秒延迟、取消和当前条目恢复；不要仅把该文件列入 TOC 就认为已完成注册。

## 客户端验收

离线测试通过后，仍需在真实客户端记录以下结果：

1. 登录后能用绑定呼出，搜索结果与最近使用的点击、右键、拖动及提示一致；只读条目不会误执行。
2. 长名称、不同 UI 缩放、滚动和键盘选择显示正确；详情视图首次状态与后续更新正确。
3. 快速换词、关闭、Provider 禁用/注销后，旧查询不回流；自身事件和计时器按生命周期停止。
4. 技能必须真实鼠标点击，成功后才进入历史；次要技能菜单选择先准备按钮。进入战斗关闭，脱战不自动重开；检查错误日志与 taint。
5. 按 AGENTS.md 在登录、空闲、单目标战斗、多目标/团本、姓名板峰值和配置页面打开/关闭场景记录 CPU、Lua 内存、对象数量和帧时间；无配置页面时注明不适用，并记录搜索窗口打开/关闭样本。

在验证记录中区分自动化已通过项、实机测量值和未测项。当前框架交付未取得真实客户端战斗、taint、安全点击和性能采样证据。
