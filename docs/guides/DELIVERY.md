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

变更SDK版本或文件清单时修改 `tools/sdk_contract.json`，执行 `python tools/build_sdk.py --write`。它更新声明、manifest与SDK性能规范副本，不自动创建ZIP或发布。本分支 SDK / Provider API 均为 1.0.0。接口与版本文档必须同实现核对，不能只改标记。

新增/移除运行资源必须同步 `tools/release_manifest.json`；该清单包含运行Lua/XML/TOC、媒体与许可证。TOC加载顺序只在 `tools/client_manifest.json` 维护，两个清单分别回答“随包交付什么”和“客户端加载什么”，不是两个加载入口。门禁拒绝漏文件、未声明文件和越界路径。

## 版本号

插件采用 `x.y.z`：小更新递增 `z`；大更新递增 `y` 并清零 `z`；`x` 仅在用户明确要求时升级。唯一版本声明是 `tools/client_manifest.json`，生成 TOC 并同步 README 版本标记。SDK / Provider API 独立版本，不随插件整理自动变化。

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

## 从多包开发版转换

只在实际安装过多包开发版时执行本节；普通单包更新沿用上面的同步流程。转换涉及 TOC 和模块边界，必须完全退出客户端。

1. 列出游戏 AddOns 中实际存在的自带旧包、当前加载关系和文件清单，记录 SHA-256。独立第三方、Lychee Dev 和其他插件不属于转换范围。
2. 在游戏目录之外备份旧运行包及相关账号/角色 SavedVariables，核对备份文件与哈希；不要删除 WTF。核对旧 Provider ID、固定项、别名、最近记录、搜索偏好和业务缓存的实际 schema，完成可验证的迁移处理后才能启动。
3. 确认提交后的单包构建清单完整。将已列明的旧自带包可逆地隔离到备份目录，避免旧包继续注册相同功能；删除必须有对应清单的明确授权。不要按 `Lychee*` 通配批量删除。
4. 部署 `addon/Lychee` 到经过校验的 `AddOns/Lychee`，核对每个交付文件的 SHA-256；旧 Host 多余加载文件也需按清单处理，不能混合两套运行时。
5. 重启后确认只有单包自带内容注册；用 lychee-dev 验证用户偏好、恢复、搜索与动作，另测全功能时间/内存。未测试语言和客户端明确保留待验收。

备份和离线检查不是迁移成功证据。出现存档损坏、重复来源或恢复异常时停止交付，先保留失败现场；按提交回滚规则和已核对备份恢复。不能把“新版 API 不兼容”当作清空用户数据的依据。

### 离线转换角色存档

[存档迁移工具](../../tools/migrate_single_addon_saves.py)只解析 Lua 字面量，不执行存档代码。`--host` 必须是选定角色的 `Lychee.lua` 备份，其中包含 `LycheeCharacterDB` 且 `settingsVersion=1`；不是账号级存档，也不会自动寻找其他角色。以下路径仅为示例，替换为已经核对的备份路径。

先预览报告：

```powershell
python tools/migrate_single_addon_saves.py --host "D:/Backups/Lychee/Character/Lychee.lua" --business "D:/Backups/Lychee/Character/Lychee_Player.lua"
```

默认 **dry-run**，JSON 报告只打印到终端，不创建输出目录，也不改源文件。`--business` 可省略或重复多次；这些文件只作为原始备份记录，不会将其业务设置或缓存导入 Host。

检查报告后，再显式生成候选文件：

```powershell
python tools/migrate_single_addon_saves.py --host "D:/Backups/Lychee/Character/Lychee.lua" --business "D:/Backups/Lychee/Character/Lychee_Player.lua" --output "D:/Backups/Lychee/Character-migrated-review" --write
```

`--output` 必须是**尚不存在的新目录**，父目录须已存在；工具拒绝覆盖现有目录。将它放在游戏目录和实际 SavedVariables 目录之外。成功输出包含：

- `Lychee.lua`：待人工审查的迁移候选，不能当成已安装存档。
- `originals/`：所有输入文件逐字节保留的副本，文件名前有输入序号；原输入不变。
- `report.json`：源路径、大小、SHA-256、候选文件哈希、身份映射依据，以及逐项 `mapped`、`preserved`、`conflict` 事件。

当前工具将已核对的 16 个自带 Provider 偏好 ID 从 `lychee.*` 对应到 `builtin.*`；普通引用只接受代码中列出的稳定 ID 模式，参数引用只转换已核对的历史音量 `set-volume` v1 身份。此转换只保留引用，不恢复已移除的设置动作；当前暴雪设置参数引用仍不可执行，也不自动转成定位入口。未知的自带来源、无法证明的条目/动作/目标及冲突保留原文并报告，不猜测替代目标。报告出现 `preserved` 或 `conflict` 必须逐项审查；第三方引用保持原样，不能将“报告没有映射”理解为它已经恢复成功。

语言或 build 变化产生的动态设置 ID 不做离线转换，不能保证中文记录在英文环境中仍指向同一设置；其他条目的名称显示、实际存在性与动作资格也需运行时重新核对。未知角色 schema、非法语法、重复键或超过解析预算会拒绝整个输入，不降级执行 Lua。

工具**不会自动写游戏 WTF，不会安装候选文件，也不会执行任何游戏动作**。审查和备份核对完成后，保持游戏完全退出，另行将确认后的候选部署到对应角色；不要覆盖其他角色或账号存档。随后按上节步骤做 lychee-dev 恢复与功能验收。转换失败时原始存档仍是回退依据，不能以脚本成功或哈希正确代替实机恢复成功。

工具回归：[合成存档测试](../../tests/build/single_addon_save_migration.py)，运行 `python tests/build/single_addon_save_migration.py`；该测试不读取真实 WTF。

完整开发和验收说明见[开发与验证](DEVELOPMENT.md)，性能约束见[PERFORMANCE.md](../../PERFORMANCE.md)。
