# IconPark 菜单图标替换

日期：2026-09-10。替换全部 34 个手绘菜单图标，保留浅色轮廓与荔枝红点缀。Provider、菜单操作、冒险指南六个页签和灰色类型标签不变。

## 资产来源与处理

来源为 [ByteDance IconPark](https://github.com/bytedance/IconPark) 的官方 npm 包 `@icon-park/svg@1.4.2`，Apache-2.0。使用完整的一套原始 SVG 轮廓，统一为 48 单位画布、3 单位线宽、圆角端点和连接。只重配现有元素的颜色，不手工重画曲线。

34 个语义映射见 [selection.json](../../assets/menu-icons/selection.json)。例如货币使用金属钱币、专业技能使用锤与砧、冒险指南使用指南针；红色用于钱币中心、勾选、宝石、搜索镜片等局部。原始 SVG、版本、构建方法和许可证固定在 [assets/menu-icons](../../assets/menu-icons/README.md)。运行时另含 `Media/MenuIcons/LICENSE.txt`，记录来源、修改内容和完整许可。

构建时使用 CairoSVG 2.8.2 渲染原始曲线，以 Pillow 12.1.1 缩采样并输出 64×64 未压缩 RGBA TGA；每边 5 px 透明安全区，适配既有 UV 0.07–0.93。34 个纹理的文件名、尺寸、格式和总大小均保持不变：每个 16,428 bytes，合计 558,552 bytes；像素数据仍为 544 KiB。新增的许可文本不是纹理。

## 检查结果

- `python tests/build_menu_icons.py`：34 个 Provider ID 与资产一一对应；原始路径可追溯；双色、索引、64×64 RGBA、32-bit 未压缩 TGA 头及透明裁切边界通过。PNG/SVG 和 SHA-256 清单均已生成。
- 视觉检查采用 [预览](../architecture/2026-09-10-menu-icons.png) 中的 32、34 和 48 像素三种尺寸，模拟 Host 的实际裁切；一轮整体检查后只调整货币语义，再确认最终图。未观察到裁边或失去红色细节的图标。
- `pwsh -NoProfile -File tests/check_contract.ps1`：11 组测试通过，包括冒险指南页签、搜索、菜单、灰色类型标签、最近使用及安全技能交互。
- `luac -p`：运行时、SDK、测试共 51 个 Lua 文件通过；Bindings XML 解析和 TOC 文件引用检查通过。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：35 个运行时 Lua，`valid=true`，零诊断，见 [原始结果](../architecture/2026-09-10-iconpark-validate.json)。本次只改媒体与离线构建脚本，没有 Lua/XML/TOC/API 改动；纹理 API 的版本依据沿用 [原查询证据](../architecture/2026-09-10-menu-icons-wowdoc.json)，sourceId=`wow-ui-source`、product=`retail`、requestedRef=`latest`、resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`，`SimpleTextureBaseAPIDocumentation.lua:600` 的 SetTexture 路径参数定义。
- `git diff --check`：已清理脚本末尾多余空行后通过。

本次没有改变任何常驻 Lua 路径、对象数量、事件或刷新频率；游戏内仍直接加载 TGA，不包含 SVG 渲染器、npm 包或字体。离线测试不能替代实机视觉和性能验收，本次没有新的游戏内 CPU、帧时间、taint 样本。

## 交付

检查通过后创建 Git 提交，再覆盖复制 `package/Lychee` 的运行时文件及菜单许可证至 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`。复制后比较全部文件清单和 SHA-256；不删除正式服文件。构建工具、源 SVG 和文档不复制。

游戏内使用 `/reload` 查看；若客户端继续使用旧纹理缓存，重启客户端。回滚采用新的 `git revert` 提交，验证后重新覆盖复制。
