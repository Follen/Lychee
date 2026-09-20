# Provider Logo 验收（0.3.5）

运行提交：1dd3a4f。Exwind / Ellesmere 在 Init 读取各自 TOC IconTexture，注册元信息及结果复用同一字符串；无声明回退通用图标。未修改 UI、存档、搜索或动作逻辑。

## 证据

wowdoc source check：retail 已同步。sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。
Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:165–177：GetAddOnMetadata(name: uiAddon, variable: cstring) returns value: cstring。

本机 ExwindCore.toc:10 声明 Interface\AddOns\ExwindCore\Textures\LOGO\EXUI.jpg（文件头实际为 PNG）；EllesmereUI.toc:7 声明 Interface\AddOns\EllesmereUI\media\eg-logo.tga。直接引用第三方安装资源，不复制素材。

## 验证

- 完整 check_contract.ps1、仓库检查、发布清单检查、retail wowdoc validate、git diff --check 通过。
- 196 个运行文件同步到正式服 Lychee，逐文件 SHA-256 相同，目标旧文件保留。
- Ticket LYCHEE-20260920-165734-0055，requestId=logo035-20260920，complete=true/status=succeeded；Retail 12.1.0.69875 / zhCN，晴昼秋岚—白银之手。
- 功能来源列表两条 icon 与 TOC 一致；实际 Texture 可见。WGC 截图确认 Exwind 白底 EX、Ellesmere 绿色标志显示正常。测试关闭页面并恢复引导确认状态。
- 每个 Provider 只增加初始化的一次元数据读取及一个临时标量；复用既有 icon，无新增 Frame、事件、timer、持久缓存或热路径工作。无需重复战斗/团本性能测量。
- 未实测英文客户端、未安装第三方场景及真实搜索动作；本次不改变这些行为。四客户端离线检查不代表四客户端实机验收。
