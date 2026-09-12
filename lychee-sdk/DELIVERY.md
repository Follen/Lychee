# SDK 版本与交付约束

SDK 开发包只提供协议、编辑器声明、可选 helper 和示例，不是第二个 Host，也不直接安装为 AddOn。

当前 API 为 **2 / revision 7**。可选 `LycheeAPI.lua` 分开声明：

- `API_VERSION=2`、`API_REVISION=7`：本开发包描述的当前能力。
- `MIN_API_REVISION=6`：省略 `API.Supports(facade)` 参数时保留的最低兼容要求。

默认下限 6 保留旧 helper 的行为，不表示 revision 6 提供托管资源。使用 `Resources`、角色设置、有界缓存或 query/view 资源时，必须显式检查 `API.Supports(facade, 2, 7)`，并在 Provider 中声明 `minApiRevision=7`。已接入的旧 Provider 不会被统一强制升级到 revision 7。

## 构建期唯一依据

仓库 `tools/sdk_contract.json` 管理当前版本、helper 兼容下限、错误码和 SDK 文件清单。它不在游戏中加载。

```text
python tools/build_sdk.py --check
python tests/sdk_delivery.py
```

检查器核对 Host 版本行、编辑器声明、helper 版本与默认兼容检查、manifest，以及交付目录中的全部文件。缺少声明文件、新增文件未列入契约、重复路径或声明漂移都会失败。

维护者修改契约后显式执行 `python tools/build_sdk.py --write`，仅更新生成的声明和 manifest；不会创建 ZIP、复制运行时或发布。业务 helper 的转发实现仍在 `LycheeAPI.lua`，不在工具中另写一份运行时。

`manifest.yaml` 自身随开发包保留，`contents` 列出其余全部文档、类型、helper 和示例，包括托管资源与 UI 生命周期示例。示例目录各自的 TOC 只用于示例插件；`ApiStubs.lua` 不得写入运行时 TOC。

自动测试会分别破坏 Host、类型、helper 和交付文件，以确认门禁能识别单边修改；同时验证合法的 revision 6 默认兼容下限与显式 revision 7 要求。
