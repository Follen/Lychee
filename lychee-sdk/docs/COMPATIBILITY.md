# 版本与兼容性

当前 SDK 与 Provider API 版本统一为 **1.0.0**。公开 API 使用完整字符串，不再单独维护 revision；UI Runtime **1** 是独立的 UI 能力标识。

API 2 不兼容：注册 `entries`、searchable/searchMode、handle:Update/Settings/SetEnabled 已移除。不要只改版本数字；按[接入教程](GETTING_STARTED.md)改为 query 统一回复，并把目录和数据库留在自己的插件中。旧 Extension/Command 注册同样不是公共入口。

`LycheeAPI.lua` 默认检查 `Supports("1.0.0")`；当前精确匹配此版本，不推断未来版本兼容，不静默回退旧数字版本。注册声明 `apiVersion="1.0.0"`；不再接受 minApiRevision，也不暴露 API_REVISION。Host 不存在返回 SDK_UNAVAILABLE，版本不匹配返回 UNSUPPORTED_API。SDK 示例不访问 LycheeInternal。

角色存档的数据搬迁属于对应数据所有者，不等于保留旧 SDK 接口。迁移失败保留原数据，不能清空未知或更高版本数据库。当前支持范围需明确声明并验证；参见[客户端差异](CLIENT_VARIANTS.md)。
