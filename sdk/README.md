# Lychee SDK

Lychee SDK 是 Lychee 本体暴露给第三方 WoW AddOn 的公共 API，不是独立运行的 sibling AddOn。

## 项目定位

Lychee 是 WoW 内的单入口命令平台：用户通过 Lychee 输入内容，Lychee 搜索已注册的 Command，调用对应 Provider，绘制结果，并路由点击、拖拽、Panel 或受保护动作。

第三方插件在自己的 AddOn 中集成 SDK：

```toc
## OptionalDeps: Lychee
```

然后通过 Lychee 本体暴露的 `_G.Lychee` facade 注册 Extension、Command、CapabilityProvider、IntentHandler 和 PanelFactory。Lychee 不扫描插件目录猜测接入；只有成功 `Commit()` 的 Extension 才进入搜索和执行链路。

## 文档入口

- [架构设计](../docs/ARCHITECTURE.md)：Host、搜索链路、Provider、Intent、Panel、战斗策略和内置功能架构。
- [SDK 合同](../docs/SDK.md)：第三方注册 API、数据 schema、交互结果、生命周期、错误码和接入示例。
- [当前 Comet 规格](../docs/comet/specs/)：与上述正式合同保持同步。
- [Comet 历史归档](../docs/comet/archive/)：历史 change 快照，仅用于追溯，不作为当前模型依据。

## 当前状态

仓库当前处于纯文档阶段，不包含 Lua/XML/TOC 运行时代码，也不复制到正式服目录。后续实现必须先按正式合同落地 Lychee Host 的 PublicAPI，再实现 Builtin Extension 和第三方 SDK fixture。
