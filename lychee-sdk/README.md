# Lychee SDK 开发包

这是 Lychee 的第三方开发包，包含 API 桩、契约说明入口和一个可复制的 AddOn fixture。它不是运行时插件，也不需要把本目录安装到 WoW 的 `AddOns` 目录。

## 接入方式

第三方 AddOn 在自己的 TOC 中声明：

```toc
## OptionalDeps: Lychee
```

代码只读取 Lychee 本体暴露的 `_G.Lychee` facade：

```lua
local SDK = _G.Lychee
if not SDK then
    -- Lychee 未安装或尚未加载；第三方功能继续运行
    return
end
```

没有名为 `LycheeSDK` 的 sibling AddOn。`lychee-sdk/` 只是开发期的文档、桩和示例。

## 公共 API

`LycheeAPI.lua` 提供 API 版本、稳定错误码、facade 检测和 `RegisterExtension` 转发 helper。正式 AddOn 不应复制 Host 内部 registry，也不应保存 `_G.LycheeInternal`。

每个 Extension 通过一次草稿提交发布能力：

1. `RegisterExtension(descriptor)`
2. `RegisterSearchSource`（实体搜索）
3. `RegisterCommand`（固定命令或 ambient 动态入口）
4. `RegisterCapabilityProvider`
5. `RegisterIntentHandler`
6. `RegisterPanelFactory`
7. `Commit()`

任一声明失败时调用 `Abort()`，不会留下部分搜索结果。`Commit()` 返回 `UNSUPPORTED_API` 时表示 SDK major/revision 不支持；返回 committed handle 但状态为 `pending/incompatible` 时表示当前 Host revision 不足（`INCOMPATIBLE_HOST`）。提交成功后用 `committed:GetSearchSource(id)` 取得窄 source handle；它提供 `GetState`、`BeginSnapshot`、`Upsert`、`Remove`、`CommitSnapshot` 和 `Invalidate`，所有 Record/Action 都会再次经过 Host Boundary 校验。

## 搜索与交互

Command 与 SearchRecord 的 `title`、`aliases`、`keywords`、`description` 支持 locale 别名，例如“复仇之怒”的中文俗称“翅膀”。SearchRecord action 只能是 plain-data：普通 `intent`、同 Extension 的 `open-panel`、Host 解释的 `secure-spell` 和受校验的 `drag-spell`。第三方不接触 SearchIndex、Palette、SecureButton 或全局快捷键。自定义 category 使用 `<extension-id>:<category>` 前缀；共享类别使用 Host 保留 ID。

## Fixture

将 `examples/ThirdPartyFixture/` 复制为自己的 AddOn 目录即可测试完整注册链路。它演示：

- `OptionalDeps: Lychee` 和 `_G.Lychee` 竞态处理；
- SearchSource、Provider、IntentHandler、PanelFactory；
- Locale aliases（`复仇之怒` / `翅膀` / `wings`）；
- 点击打开详情；
- `onHostAttached`、`onHostDetached`、`onEnabled`、`onDisabled` 生命周期。

Fixture 使用静态有界数据，不创建常驻 `OnUpdate`，符合 EllesmereUI 的零空闲成本和事件驱动原则。
