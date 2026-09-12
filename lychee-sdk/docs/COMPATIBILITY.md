# SDK 版本兼容

性能、容量与生命周期预算统一见[性能硬门禁](PERFORMANCE.md)；本页说明接口使用方式。

新接入使用 API 2 / revision 7，UI Runtime 独立版本1。Host继续兼容旧Provider；helper默认最低要求6，使用托管资源必须显式要求7。旧版本是兼容说明，不是新接入步骤。

| Revision | 能力与接入条件 |
| --- | --- |
| 1 | 基础Provider；未声明产品范围的旧接口只在正式服启用 |
| 2 | scope.products与独立i18n；客户端实现仍由Provider选择 |
| 3 | searchable=false排除通用搜索，保留动作/解析；不与新组合入口混用 |
| 4 | searchMode global/prefix和searchPrefixes |
| 5 | searchMode keyword和searchKeywords，精确触发来源查询 |
| 6 | searchGlobal、searchPrefixes、searchKeywords组合入口；不与旧searchMode混用 |
| 7 | Provider/query/view资源、角色设置、有界缓存 |

准确字段限制和旧模式映射见[协议参考](PROTOCOLS.md)。新接入见[教程](GETTING_STARTED.md)，同一Provider跨客户端实现见[客户端差异](CLIENT_VARIANTS.md)。API 2不保留旧Extension/Command多角色流程。
