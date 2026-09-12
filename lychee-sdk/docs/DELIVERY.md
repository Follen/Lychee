# SDK 交付合同

SDK 与公开 API 版本统一为 1.0.0；API_VERSION="1.0.0"，helper 默认检查这个完整字符串。不提供修订号或数字版本兼容入口。编辑器声明 ApiStubs.lua 不进入 AddOn TOC。

开发包可单独解压，文档仅引用包内文件或明确远程资料。LycheeAPI.lua 是可选能力检查器；Storage.lua 是可嵌入模块，放进自己的插件并由自己的 TOC 加载。不是把整个 lychee-sdk 安装到 AddOns。

唯一构建合同是 tools/sdk_contract.json：版本、错误码、全部文件清单。`python tools/build_sdk.py --write` 只更新生成字段和性能文档副本；`--check` 只读检查。完整发布工具另生成五运行时目录组成的 Lychee.zip 和独立 lychee-sdk.zip，校验路径、文件清单、SHA-256 和可重复构建。

测试必须分别破坏 Host、类型、helper、文档、交付文件和统一版本合同，验证单边漂移会失败。不能仅搜索版本字符串，也不能修改输入补齐必填字段后宣称公开边界通过。
