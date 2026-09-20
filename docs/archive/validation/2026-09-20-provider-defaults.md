# 2026-09-20 来源默认开关与客户端范围

## 行为

在 main 单包结构上调整来源参与搜索的默认值：EllesmereUI 或 ExwindCore 未安装、当前角色禁用时默认关闭；已安装并启用但尚未加载时默认开启。自动默认值不写入角色偏好，显式开启/关闭分别保存 false/true。非当前 product/interface/build 范围的来源不显示列表与详情，默认关闭；保留原有角色偏好供兼容客户端恢复。

不改变来源 owner 生命周期；只调整参与搜索的偏好。安装检测仅缓存两个会话布尔值；接口异常、角色身份尚不可用时不缓存失败。没有新增事件、计时器、后台扫描或业务存档。管理列表沿用既有遍历与行池；scope 检查无持久缓存。

## 源码证据

- sourceId: `wow-ui-source`; product: `retail`; requestedRef: `12.1.0`; resolvedCommit: `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:98`: `GetAddOnEnableState` 接收 `name` 和 `character`，返回 `AddOnEnableState`。角色参数沿用项目 AddonDiscovery 的 UnitGUID 约定。
- 同文件 `:114`: `GetAddOnInfo` 接收插件名并返回名称及加载信息；检测安装而非是否已经加载，覆盖 LoadOnDemand。
- 当前安装的 ExwindCore TOC/源码定义 `_G.ExwindTools`；ExwindTools 模块依赖 ExwindCore，因此检测核心包。

## 离线验证

- 新回归先红后绿：缺少依赖时旧实现默认开启，`tests/provider_defaults.lua absent` 失败；修复后 absent/disabled/installed/error/classic 五种场景全部通过。
- 测试真实 Ellesmere/EX 注册、显式偏好重注册、范围列表/详情隐藏与搜索排除；模拟未来/过期 build、interface 和其他产品。暖态 100 轮不重新扫描安装信息。
- 完整 `tests/check_contract.ps1` 通过，包括 SDK、TOC/发布清单、现有来源、生命周期、存储和性能回归。旧 EUI/EX 测试补充核心插件已安装启用的环境；UI 性能测试补载真实 RuntimeIdentity。
- UI 1000 来源仍复用 8 行，无池增长；EUI/EX 性能与保留内存预算通过，EX 不新增 Frame。
- Lua 5.1 静态语法检查 215 文件及 Bindings XML 解析通过；后续两个测试初始化修改随完整契约实际执行通过。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：111 Lua 文件，valid=true，diagnostics=[]。使用递归 Lua 校验；TOC 结构与加载清单由完整契约覆盖。
- `git diff --check` 通过。

## 实机与交付

- 运行提交 `89a0a61030c53c09ae748ea71912aab7c1a09bc6` 已推送 main；仅同步 Lychee 包的 173 个清单文件，SHA-256 全部一致。同步证据保留在本地 `analyze/provider-defaults-game-sync.json`。
- 使用更新后的 lychee-dev 脚本完成输入 reload、一次运行、匹配二维码、输出 reload、受限 SV 读取及 ACK。后台旧投递未产生结果；新版前台投递在路径格式和焦点校验通过后成功，未重复执行测试。
- Ticket：`LYCHEE-20260920-012655-0015`；task：`provider-defaults`；request：`provider-defaults-20260920-0140`；revision：`defaults-r1`。来源 `automation_result`，环境 retail `12.1.0.69875` / Interface `120100` / `zhCN`。
- 完整 payload：`%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260920-012655-0015/content.json`，2418 字节，SHA-256 `565a03262f27d47a5e77204bea303bde45be50629d8e759feb849015fb574d28`。解析结果 `succeeded`、`complete=true`、`outputTruncated=false`。
- 27 项功能断言全通过：真实 EUI/EX 核心包已安装且角色启用、无显式偏好时默认参与；显示与搜索一致；显式关闭不停止 owner；重新注册保留偏好并拒绝旧实例凭据；合成未来 build、过期 Interface 和其他 product 来源默认关闭，列表与详情隐藏，搜索排除；测试注册与临时角色键全部清理。
- 已发送 ACK received，世界画面的聊天回执明确确认该 Ticket 的读取结果；未留下二维码或聊天草稿。磁盘临时任务块已通过工具移除，保留其他任务。
- 未覆盖：真实未安装/禁用依赖、其他客户端/语言、实机 CPU/内存专项；前两类默认行为有离线场景回归，不能视为相应客户端实测。本次没有禁用用户已安装插件，也没有修改真实 EUI/EX 开关。
