# 2026-10-17 启动器 Logo 范围验收

## 变更范围

- 插件版本：0.4.5 → 0.4.6。
- 原图由用户指定的 `D:/Code/wow/addons/Lychee Blightfall/assets/footer-icons/launcher.png` 原样复制为 `assets/release/launcher.png`，用于发布平台 Logo。
- 插件列表独立使用 `Media/launcher.tga`：64×64、RGBA、无压缩 TGA；由原 PNG 使用 Pillow LANCZOS 缩放导出。
- 六份 TOC 只调整版本和 IconTexture 元数据，Lua/XML 加载顺序不变。
- 游戏内原有 PNG/TGA、Palette、公共品牌组件和动画代码保持不变。斜杠命令来源对 Lychee 自身保留原图，避免 TOC 图标变化影响搜索与引用恢复；其他插件继续读取各自的 IconTexture。
- 仅新增一个静态小纹理（RGBA 解码像素 16 KiB，TGA 文件 16,428 字节），不新增 Frame、事件、timer、OnUpdate 或缓存。

## Blizzard 来源证据

- sourceId: `wow-ui-source`
- product: `retail`
- requestedRef: `refs/heads/live`
- resolvedCommit: `b9be9379719047977fca4dba1bb1d9988e8840b3`
- snapshot: `PIN-e27ee47add003213c856f4e7fd49391e382baa79f23a26cb8c960c4b90a41e9a`
- path: `Interface/AddOns/Blizzard_AddOnList/AddonList.lua`
- line: `390`
- capture: `CAP-73fb6eb49f83929b95f62c905fd7c4814f72961b15b1bcd7ac205888c8aa0198`
- 原始文件 SHA-256：`95942b8356860089bcd0a9a11dea8b84789a65a52c6a7dbb581eec7f86b836ad`
- 当前 lycheedev 使用 `source sync` 固定提交，以 `source list --snapshot` 核对来源就绪；这是当前 CLI 中对应旧 source check 的检查入口。

```lua
390: 	local iconTexture = C_AddOns.GetAddOnMetadata(addonIndex, "IconTexture");
391: 	local iconAtlas = C_AddOns.GetAddOnMetadata(addonIndex, "IconAtlas");
392:
393: 	if not iconTexture and not iconAtlas then
394: 		iconTexture = [[Interface\ICONS\INV_Misc_QuestionMark]];
395: 	end
396:
397: 	if iconTexture then
398: 		titleText = CreateSimpleTextureMarkup(iconTexture, 20, 20) .. " " .. titleText;
399: 	elseif iconAtlas then
400: 		titleText = CreateAtlasMarkup(iconAtlas, 20, 20) .. " " .. titleText;
```

上述调用将 TOC 的 IconTexture 用于插件列表中的 20×20 纹理。

## 验证状态

- 完整契约通过：设置当前测试进程的 `PYTHONUTF8=1` 后运行 `pwsh -NoProfile -File tests/check_contract.ps1`。包含新增的自身命令图标查询/恢复检查、既有品牌几何及面板动画、客户端清单、SDK、仓库与发布包检查。首次运行因 Windows 默认 GBK 读取 UTF-8 TOC 失败；切换解释器编码后通过，未改变断言。
- 256 个 Lua 文件经 `luac -p` 解析通过，Bindings XML 解析通过，`git diff --check` 通过。
- lycheedev 静态验证：Mainline 加载闭包 137 个文档，`loadValid=true`、`staticValid=true`。`complete=false`，客户端 Interface 映射及动态引用等语义未覆盖；不作为完整 API 或实机兼容性证明。验证 capture：`CAP-1dc8b76266ffcff1797159986a5e154f809b84a9f5e651f46a62eab2d719ec06`。
- 平台 PNG 与用户源文件逐字节一致，SHA-256 为 `5cb65895a2abe60097759e8860573c2f27d9082cda9858a6b1dde6199347e76b`。旧 PNG/TGA、Palette 和公共品牌组件未改；六份 TOC 的 Lua/XML 加载顺序一致。
- 导出 TGA 的 20/28/34/48 像素离线预览已检查，透明背景及启动箭头正常。

客户端新图标显示、各语言/客户端实际外观仍待重启游戏后验收。此次不涉及搜索匹配、动作、生命周期或存储逻辑变更，不增加完整游戏性能场景；离线品牌回归不代替实机显示验收。

## 平台范围

新手盒子沿用项目 27164，仅修改 Logo；其他资料和已发布版本保持原值，执行与读回结果保留在本机 `publish` 记录。网易 DD 当前 fupload 的 plugin edit/update 均不接受 logo/logo_file，现有四个条目的线上 Logo 未修改；本地发布素材已准备好。
