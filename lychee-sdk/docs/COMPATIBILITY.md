# 版本与兼容性

当前 SDK 发行版本 **1.0.0**，Provider **API 3 / revision 1**，UI Runtime **1**。版本分别描述开发包、Provider 协议与 UI 能力。

API 2 不兼容：注册 `entries`、searchable/searchMode、handle:Update/Settings/SetEnabled 已移除。不要只改版本数字；按[接入教程](GETTING_STARTED.md)改为 query 统一回复，并把目录和数据库留在自己的插件中。旧 Extension/Command 注册同样不是公共入口。

`LycheeAPI.lua` 默认检测 API 3 / revision 1；不静默回退旧版本。Host 不存在返回 SDK_UNAVAILABLE，版本不满足返回 UNSUPPORTED_API。SDK 示例不访问 LycheeInternal。

角色存档的数据搬迁属于对应数据所有者，不等于保留旧 SDK 接口。迁移失败保留原数据，不能清空未知或更高版本数据库。当前支持范围需明确声明并验证；参见[客户端差异](CLIENT_VARIANTS.md)。
