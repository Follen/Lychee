# 独立冷加载示例

[简体中文](README.md) · [English](README.en.md)

完整 Retail AddOn，使用 SDK / Provider API 1.0.0。将整个目录复制到 `Interface/AddOns/ColdProvider`，与 Lychee 并列，重启客户端。改目录名时必须同时改两份 TOC 文件名和 X-Lychee-Package。

X-Lychee-* 是原生 TOC 静态声明，不在发现时执行 Lua manifest。示例使用公开游戏 fileID 和自己的 ColdProviderDB，不读取 Host 私有表/媒体，也无需另复制 SDK helper。

## 验证流程

1. 原生插件列表启用两个插件；ColdProvider 是按需加载，普通登录不运行其 Lua。
2. 输入 `cold:` 或 `coldexample`；默认仅路由搜索触发，其他普通搜索不应加载。用户覆盖路由可改变这一点。
3. Lychee 读声明、加载包、等待注册。RegisterReady/WhenSavedVariablesReady 都可同步完成，示例不提前读 SV。
4. 中英文分别显示“测试冷加载动作”/“Test cold-loaded action”。搜索和打开不执行动作，点击才在本包 SV 写 acknowledged=true 并输出确认。
5. 固定入口并关闭重开，验证恢复。关闭“参与搜索”隐藏搜索结果，但不阻止有效固定引用；原生禁用是另一种状态，需 reload/重启影响加载。

关闭 Lychee 不卸载已经加载的 Lua/SV。再次测试真正冷加载时 reload/重启并避免该示例的可见固定引用；可见引用可以合法加载所属包。取消慢准备使用独立慢测试来源，本示例不人为添加 timer。

## 范围和验收

仅声明 Retail Interface 120100–120199。其他客户端需要自己的 TOC、能力证据和测试，不能仅扩大范围；宽 build 范围是接口族示例，不代表每个 build 都实测。

完整仓库运行 `lua tests/sdk/cold_example.lua`，使用真实示例 TOC/Lua 和原生加载替身覆盖中英文、就绪顺序、明确执行、损坏 SV 保留、改名/声明不符拒绝。离线通过不替代真实客户端的冷加载、关闭重开和来源禁用验证。

适配自己的功能时一起修改 ID、路由、文案、SV 名称和动作，保持冷声明与热注册一致。仅业务需要时加 prepare。参见[加载](../../docs/zh-CN/LOADING.md)、[Invocation](../../docs/zh-CN/INVOCATIONS.md)、[目录](../../docs/zh-CN/CATALOG.md)。
