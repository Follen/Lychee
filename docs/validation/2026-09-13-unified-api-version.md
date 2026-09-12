# SDK 与 API 统一版本 1.0.0

基线：`83c52c6084ef2421782f2f86be0cdc4dd85b124e`。按用户要求，SDK 发行版本和公开 API 版本都使用 `1.0.0`，不再保留数字 API / 独立 revision 版本体系。

## 行为和边界

- `Lychee.API_VERSION`、`Lychee.SDK.VERSION`、SDK helper、类型和构建合同均为字符串 `"1.0.0"`。调用 `Lychee:Supports("1.0.0")`，Provider 声明 `apiVersion="1.0.0"`。
- 当前精确匹配这个版本；数字 1/2/3、缩写、未来版本、旧修订号参数均不兼容。公开注册带 minApiRevision 字段返回 INVALID_SCHEMA，不转换。Ready 通知只返回统一 apiVersion。
- 五包 Provider、可选 Catalog 私有装配、SDK 示例、类型、README/协议/兼容政策/测试说明/性能规范同步。历史验证记录保留当时版本作为证据。目录更新计数 revision、存档 schema 与 UI Runtime 能力标识不属于 SDK/API 发行版本，未改变。
- 没有改查询、排名、动作、目录内容、角色数据库或 UI；删除了旧 API 修订号判断及其不可达状态。无新事件、timer、缓存、框体或热路径解析器；版本比较只是字符串精确比较，注册和能力检查时执行。

## 验证

- `python tests/run.py --report analyze/api-version/full.json`：89/89 硬门禁命令通过。默认不含无阈值索引观测工具。
- 增加当前/旧数字/错误/未来版本、旧字段、额外修订号参数、失败后重新注册、即时与延后 Ready 通知的实际回归。SDK 交付检查拒绝 SDK/API 不一致和旧 revision 字段；类型声明、helper 默认检查与 Host 常量单边漂移都有故障注入测试。
- 新文档检查拒绝当前示例/运行声明出现旧数字版本，正常说明“旧字段已移除”仍允许；`delivery-final.json` 中相关交付与契约分组通过。Lua/XML/Python 静态解析、生成器 --check、SDK 闭包、文档链接及 diff 检查通过。
- 五包 wowdoc validate：共 104 Lua，全部 valid=true，无诊断。原始文件 `analyze/api-version/wowdoc-*.json`。
- 不含 LDT 加载组合：99 文件、1470.9 KiB、19 ms；完整组合：104 文件、1846.6 KiB、24 ms。仍 2 Frame / 4 事件，原加载与其他性能门槛未变；离线数字不是游戏实测。

## API 来源

按项目规则先 source list / source check，再 inspect `C_AddOns.IsAddOnLoaded`：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`12.1.0`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:322`，333–334 行返回 `loadedOrLoading`、`loaded` 两个 bool。原事件和存档就绪语义保持；本轮未引入新的游戏 API。

提交后按 release_manifest 将五包运行文件同步至 `D:\Game\World of Warcraft\_retail_\Interface\AddOns` 并核对 SHA-256，保留目标旧文件。同步结果单独保存在 `analyze/api-version/sync-result.json`。没有新增 TOC 模块或加载顺序变化，已识别五包的客户端 `/reload` 即可重载；本轮未执行游戏内验证。
