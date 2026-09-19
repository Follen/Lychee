# Lychee 文档导航

本分支使用一个 `addon/Lychee` 运行包，SDK / Provider API 为 1.0.0；第三方仍独立接入。功能迁移与实机验收状态见[迁移计划](architecture/2026-09-14-single-addon-feature-port.md)，本导航不代表迁移已验收。

这里先列当前规则。带日期的设计与验证是当时的决策和证据，不能单凭文件较新就覆盖现行规范。

## 我想做什么

| 任务 | 阅读入口 |
| --- | --- |
| 安装、使用插件 | [中文首页](../README.md) · [English](../README.en.md) |
| 找源码、改构建或新增 Provider | [项目结构](guides/PROJECT_STRUCTURE.md) |
| 开发、测试、同步游戏 | [开发与验证](guides/DEVELOPMENT.md) · [发布流程](guides/DELIVERY.md) |
| 理解当前内部职责 | [架构](ARCHITECTURE.md) · [当前上下文](../CONTEXT.md) |
| 改名称、翻译、别名或语言回退 | [国际化规则](../i18n.md) |
| 改页面、控件、动画或图标 | [设计规范](../DESIGN.md) |
| 改性能、缓存或生命周期 | [性能规则与内存审查](../PERFORMANCE.md) |
| 接入第三方 Provider | [SDK 首页](../lychee-sdk/README.md) |
| 查看产品范围 | [产品](../PRODUCT.md) · [内置功能](PROVIDER_FEATURES.md) |
| 找历史决策和测量证据 | [设计记录](architecture/README.md) · [验收记录](validation/README.md) |

## 一项规则只维护一份

- PERFORMANCE.md 管性能规则、测量口径与 Agent 内存审查；CPU、容量和生命周期门禁继续执行，SDK 中的副本自动生成。
- DESIGN.md 管用户看到和操作到的行为，主题值由 UI/Theme.lua 实现，动效参数由对应 Motion 模块实现。
- SDK 的接入、协议、兼容和示例都在 lychee-sdk；本目录不复制协议正文。
- API 版本和 SDK 交付清单归 tools/sdk_contract.json；客户端加载清单归 tools/client_manifest.json。
- tools/release_manifest.json 管发布资源；dist 是产物，不是源码。
- docs/comet 由工作流管理；历史报告保留原路径、原读数和未验证限制。重跑使用现行开发指南。

文档新增先放进上述入口；不要将一次排障经历追加成当前 API 规则。文档变动运行 `python tools/check_repository.py`。
