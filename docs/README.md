# Lychee 文档

[简体中文](README.md) · [English](README.en.md)

## 使用与开发

| 任务 | 入口 |
| --- | --- |
| 安装和使用 | [插件首页](../README.md) · [English](../README.en.md) |
| 找源码和构建入口 | [项目结构](guides/PROJECT_STRUCTURE.md) |
| 开发、测试、同步游戏 | [开发指南](guides/DEVELOPMENT.md) · [交付指南](guides/DELIVERY.md) |
| 维护文档与翻译 | [文档维护](guides/DOCUMENTATION.md) |
| 接入第三方 Provider | [中文 SDK](../lychee-sdk/README.md) · [English SDK](../lychee-sdk/README.en.md) |
| 准备平台文案和封面 | [发布素材](../assets/release/DESCRIPTION.md) |

## 现行规范

| 范围 | 维护源 |
| --- | --- |
| 产品和内置功能 | [PRODUCT](../PRODUCT.md) · [功能说明](PROVIDER_FEATURES.md) |
| 内部职责和上下文 | [ARCHITECTURE](ARCHITECTURE.md) · [CONTEXT](../CONTEXT.md) |
| 交互和视觉 | [DESIGN](../DESIGN.md) |
| 性能、容量和内存审查 | [PERFORMANCE](../PERFORMANCE.md) |
| 名称、词典与语言回退 | [i18n](../i18n.md) |

SDK 协议只在 SDK 中维护；版本和 SDK 文件清单来自 tools/sdk_contract.json。插件版本、客户端装配来自 tools/client_manifest.json，运行交付清单来自 tools/release_manifest.json。dist 是构建产物。

## 历史记录

[归档入口](archive/README.md)集中设计、验收和原始测量。旧工作流资料单列在 [Comet](comet/README.md)，读取它不会启动工作流。历史状态不代表当前实现或当前客户端验收。
