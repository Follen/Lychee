# 性能规范的 EllesmereUI 历史来源

本记录于 2026-09-13 从根 PERFORMANCE.md 移出，保留原有参考版本、源码链接与机制说明，供追溯规则来源。本次仅整理文档，未重新核验上游源码，也未新增性能测量。现行要求与预算以[性能硬门禁](../../PERFORMANCE.md)为准；本记录不是执行入口，上游后续变化不自动修改 Lychee 规则。

## 原来源说明

规则参考 EllesmereUI 实际源码，并结合 Lychee 的搜索、Provider 和 SDK 契约制定。上游代码不是无条件复制模板；下面标注为 Lychee 门禁的要求，不代表上游全部已经实现。

近期核对基线：`8da5dfe182c7809e3f61b5a9ca856d16b891726f`（2026-09-09）。

| 上游证据 | 可借鉴的机制 |
| --- | --- |
| [贡献验收标准](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/.github/CONTRIBUTING.md#L26-L46) | 未启用零活动成本、首次启用时创建、可选设置默认关闭、事件驱动、限制热路径分配、避免 taint |
| [共享驱动](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_Ticker.lua#L62-L120) | 幂等订阅、密集数组、交换删除、零订阅时隐藏驱动 |
| [搜索索引](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_GlobalSearch.lua#L385-L411) | 用轻量控件替身提取搜索文字，避免为索引预建整页 UI；少数自定义框架仍存在 |
| [分批预处理](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_GlobalSearch.lua#L646-L718) | 首次使用触发，每批一个页面、间隔 0.05 秒，战斗中暂停 |
| [结果行复用](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_GlobalSearch.lua#L815-L894) | 搜索 UI 创建一次，复用固定数量结果行 |
| [主题刷新](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_UICore.lua#L344-L379) | 重控件约 15 Hz 刷新、结束时局部更新，完整 GC 延后两帧 |

原有准则还参考了 `1b37158d7533deb2d5b0a74292438a8ea2191588`（v8.9.1）：[AuraKit](https://github.com/EllesmereGaming/EllesmereUI/blob/1b37158d7533deb2d5b0a74292438a8ea2191588/EllesmereUI_AuraKit.lua)、[aura 容器](https://github.com/EllesmereGaming/EllesmereUI/blob/1b37158d7533deb2d5b0a74292438a8ea2191588/EllesmereUIRaidFrames/EUI_RaidFrames_AuraContainers.lua)、[皮肤契约](https://github.com/EllesmereGaming/EllesmereUI/blob/1b37158d7533deb2d5b0a74292438a8ea2191588/SKINNING_API.md)，保留其缓存、池化、幂等 setter 和成功后写状态戳原则。

上游 12.1 专用、ASCII 限制等产品或打包政策不自动成为 Lychee 要求。API 以本项目 wowdoc 版本证据为准。上游搜索采用平铺扫描，仍有临时结果表；不能据此认定其算法适合 Lychee 的全部数据规模。
