# 构建、提交与正式服同步

`python tools/build_release.py --check` 在内存中构建并校验归档；不安装、不上传。去掉 --check 输出 dist/Lychee.zip（五个运行时根目录）、dist/lychee-sdk.zip（独立开发包）和带源码提交/dirty 状态及 SHA-256 的 manifest.json。

先运行完整契约、Lua/XML/TOC 检查和版本化 wowdoc 验证，再检查 git diff --check 和 git status，仅暂存本轮相关文件并创建描述性提交。提交失败禁止复制；记录成功 hash 后才同步。

同步源为 `addon/` 的五个明确包，父目标固定为 `D:/Game/World of Warcraft/_retail_/Interface/AddOns`。每个目标末级必须与源包同名；确认源及 AddOns 父目录存在，目标缺少时可创建，任何路径越界立即停止。

只复制发布清单中的运行时资源。复制后逐包比较全部源文件的相对路径和 SHA-256；目标已有额外旧文件单独列出，不默认删除。SDK、测试、文档、分析资料和工具状态不复制。

本轮新增子插件及 TOC，须完全退出并重启客户端，启用五个包；/reload 不足以发现新 AddOn。只修改已经加载的 Lua 内容时才使用 /reload。离线通过不能写成实机验证通过。

仅文档或测试改动不复制。撤回已交付提交使用新的 git revert，不改写历史。推送 GitHub 与安装是独立操作，按用户授权执行。
