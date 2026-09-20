# 版本与兼容性

[目录](README.md) · [English](../en/COMPATIBILITY.md)

当前 SDK 与 Provider API 版本统一为 **1.0.0**。公开 API 使用完整字符串；UI Runtime **1** 是独立的 UI 能力标识。

当前 1.0.0 保留普通 `entries`、`handle:Update` 和可选 query 接入，不能把 API 版本更新理解为强制目录重写。所有者使用 `SetAvailability`，用户来源开关仅控制参与搜索。旧 Extension/Command 注册不是公共入口。

`LycheeAPI.lua` 默认检查 `Supports("1.0.0")`；当前精确匹配此版本，不推断未来版本兼容。注册声明 `apiVersion="1.0.0"`。Host 不存在返回 SDK_UNAVAILABLE，版本不匹配返回 UNSUPPORTED_API。SDK 示例不访问 LycheeInternal。

角色存档的数据搬迁属于对应数据所有者，不等于保留旧 SDK 接口。迁移失败保留原数据，不能清空未知或更高版本数据库。当前支持范围需明确声明并验证；参见[客户端差异](CLIENT_VARIANTS.md)。
