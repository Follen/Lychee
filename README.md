# Lychee

Lychee 是 World of Warcraft 内的单入口命令平台。用户通过统一搜索框查找命令、角色技能、任务、怪物与副本数据，并通过结构化结果执行点击、拖拽、面板或受保护动作。

Lychee 只发布一个 Host AddOn。第三方 AddOn 通过 Host 暴露的 `_G.Lychee` 公共 API 注册 Extension、Command、CapabilityProvider、IntentHandler 和 PanelFactory；SDK 不是独立 AddOn。

## 文档

- [架构设计](docs/ARCHITECTURE.md)：Host 模块、搜索与执行链路、内置 Extension、性能和战斗策略。
- [SDK 合同](docs/SDK.md)：第三方接入 API、数据协议、生命周期、交互与错误码。
- [当前 Comet 规格](docs/comet/specs/)：当前生效规格，须与正式合同保持一致。
- [Comet 历史归档](docs/comet/archive/)：历史快照，仅用于追溯。

## 当前状态

仓库目前处于设计文档阶段，没有 Lua、XML 或 TOC 运行时代码。运行时实现与正式服复制流程将在后续实现阶段启用。
