# 构建工具

当前运行时为 addon 下五个明确插件包；Host、Player、Encounters、Integrations、Inspector 分开交付。不是按需卸载代码的方案；目录和任务生命周期由各自 Provider 控制。SDK 1.0.0 / API 1.0.0，不兼容旧接口。

工具不进入 AddOns，SDK 文档与类型位于 lychee-sdk，离线验证位于 tests。

所有命令从仓库根目录运行。

| 工具 | 用途 | 依赖／输入 |
|---|---|---|
| `check_repository.py` | 当前文档链接、锚点、SDK自包含与版本徽章检查 | Python标准库 |
| `build_release.py` | `--check`内存中验包；默认生成dist中的插件/SDK ZIP及哈希清单 | release_manifest.json、sdk_contract.json |
| `release_manifest.json` | 完整游戏交付资源清单，含许可证 | 新增/删除运行文件同步维护 |
| `build_sdk.py` | `--check`只读；`--write`更新SDK声明、清单和性能规范副本 | sdk_contract.json、PERFORMANCE.md |
| `build_client_tocs.py` | 生成五个插件包和 SDK 示例的四客户端 TOC；`--check` 只校验 | Python 标准库、`client_manifest.json` |
| `client_manifest.json` | 客户端 Interface 与有序加载清单 | 由 TOC 工具读取 |
| `build_journal_catalog.py` | 从已保存的数据快照生成首领目录 | Python 标准库、`docs/architecture` 下对应 JSON |
| `build_enemy_catalog.py` | 从具名事实快照生成 LDT 数据；`--check` 检查漂移 | `assets/data/enemies.json`；普通构建不依赖分析目录或游戏 |
| `build_flat_menu_icons.cjs` | 当前扁平菜单图集导出 TGA 与预览 | Node.js、sharp、`assets/menu-icons/flat-atlas.png` |
| `build_provider_icons.py` | reload、冷却管理器、钥匙通用图标导出 | Python、CairoSVG、Pillow、`assets/provider-icons` |
| `build_addon_inspector_icon.py` | 插件识别图标导出与预览 | Python、CairoSVG、Pillow |
| `build_menu_icons.py` | 旧版 IconPark 轮廓图标重建 | Python、CairoSVG、Pillow、预览字体 |
| `export_menu_icons.cjs` | 旧版 IconPark 原始矢量素材导入 | Node.js、指定版本的已解压 IconPark 包 |

```powershell
python tools/build_client_tocs.py --check
pwsh -NoProfile -File tests/check_contract.ps1
```

客户端与子插件功能支持范围只在 `tools/client_manifest.json` 维护：`providers` 声明功能归属、产品范围、语言资源和必需能力，`packages.<包名>.files` 中的 provider 引用只决定加载位置。执行 `python tools/build_client_tocs.py` 同时生成 TOC 与 各包 `Manifest.lua`、`Bootstrap.lua`、`Activate.lua`；`--check` 检查两者漂移。见 [结构维护步骤](../docs/guides/PROJECT_STRUCTURE.md)。图标／数据生成命令会更新输出文件，不作为常规测试全部执行；旧版轮廓工具与当前扁平工具有相同输出目录，分别用于对应素材的重建。

这些文件原来位于 `tests/`。历史验证报告、已有产物的 generator 元数据及生成注释保留当时路径作为来源记录；重跑时使用此目录下同名工具。新的产物记录会使用 tools 路径。不要为清理目录而重生成游戏数据或图标。
