# 测试装配与门禁

从仓库根目录执行 `powershell -NoProfile -File tests/check_contract.ps1`。测试在独立 Lua 进程运行；游戏 API、计时器和输入替身由各测试控制，不能由公共装配偷偷提供成功默认值。

公共宿主装配：

```lua
dofile("tests/support/runtime.lua").Load("provider", {"Search/SearchSession.lua"})
```

- provider 选择公共 SDK 所需宿主模块；额外列表只列测试实际依赖的业务/UI 模块。
- search 只装配搜索核心。纯函数、独立 oracle、真实 TOC 加载和逐文件测量可继续直接加载，不强制加载全宿主。
- 顺序来自所选客户端实际 TOC，缺失的显式模块报错；`root`、`toc`、`overrides` 或 `load(path)` 允许可审计的版本比较和加载期观测。
- 公共装配不生成预期结果、不替换评分器、不统一游戏替身，也不缓存跨测试全局实例。

`test_assembly.lua` 检查顺序、缺失模块拒绝、纯搜索不加载宿主；`client_manifest.py`、`client_toc_load.lua` 和构建 --check 独立验证真实打包和运行装配，不能只让测试与生产共享一份错误清单后互相证明。

`sdk_resources.lua` 检查托管生命周期、取消/回复重入、迟到 timer、额度、页面部分创建失败、设置角色/实例隔离、缓存容量。原 Provider 接收、所有权、搜索质量、原子更新、真实 UI 事件序列和性能预算继续保留。旧 Command/Capability 专项退出；其用户可见动作、视图和失效身份由公共 Provider 的交互测试覆盖。

本目录和 SDK 开发文件不进入游戏运行时目录。离线通过不等于客户端战斗、taint 或视觉验证通过。
