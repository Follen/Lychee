# 构建与交付

命令从仓库根目录执行。运行源码只在 `addon/Lychee`，SDK只在 `lychee-sdk`；游戏中仍安装为 `Interface/AddOns/Lychee`。

## 先检查，再生成

```powershell
python tools/build_client_tocs.py --check
python tools/build_sdk.py --check
python tools/check_repository.py
python tools/build_release.py --check
powershell -NoProfile -File tests/check_contract.ps1
```

变更SDK版本或文件清单时修改 `tools/sdk_contract.json`，执行 `python tools/build_sdk.py --write`。它更新声明、manifest与SDK性能规范副本，不自动创建ZIP或发布。API公共能力不因目录迁移升版。

新增/移除运行资源必须同步 `tools/release_manifest.json`；该清单包含运行Lua/XML/TOC、媒体与许可证。TOC加载顺序只在 `tools/client_manifest.json` 维护，两个清单分别回答“随包交付什么”和“客户端加载什么”，不是两个加载入口。门禁拒绝漏文件、未声明文件和越界路径。

## 发布产物

```powershell
python tools/build_release.py
```

输出忽略的 `dist/Lychee.zip`、`dist/lychee-sdk.zip` 和 `dist/manifest.json`。压缩包分别以Lychee和lychee-sdk为顶层目录，固定ZIP元数据，按完整清单逐文件验证字节和SHA-256；manifest记录来源commit与dirty状态。正式交付应先提交再构建，确认dirty=false。

`dist/legacy`只保存整理前的旧产物，不能当成当前版本。不要把ZIP放回源码目录，也不要把测试、SDK或文档塞进Lychee游戏包。

## 本机游戏同步

检查通过 → 查看git status → 只暂存相关文件 → 提交并记hash → 从addon/Lychee覆盖复制到已验证的目标 → 核对清单与哈希。提交失败不复制。

本机唯一目标为 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`。校验源和AddOns父目录存在、末级为Lychee，防止越界或链接误写。默认保留目标多余文件；已获明确清理授权才定向删除。构建工具本身不操作游戏目录。

仅已加载运行文件更新使用/reload；新增模块、TOC或加载顺序变化重启客户端。仅仓库布局/文档/工具变动且游戏运行字节一致时不重复复制。离线通过不等于实机通过。

完整开发和验收说明见[开发与验证](DEVELOPMENT.md)，性能约束见[PERFORMANCE.md](../../PERFORMANCE.md)。
