# main：大米助手技能图标裁切

用户明确要求在 main 的单插件实现修复。仅在 `addon/Lychee/Builtin/LDT/View.lua` 的八个技能行图标首次创建时设置 `SetTexCoord(0.07, 0.93, 0.07, 0.93)`，与首页及搜索列表一致。尺寸仍为 32×32，刷新、翻页、展开及重开不追加裁切调用；无新增对象、缓存、事件、timer 或每帧逻辑。测试替身补齐该原生接口。

## API 证据

本会话已经执行 wowdoc source list / source check 和版本化查询。sourceId=`wow-ui-source`，product=`retail`，requestedRef / matchedTag=`12.1.0`，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。

路径 `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua`，576 行 excerpt：`Name = "SetTexCoord"`；583–586 行列出四个必填 number 参数 `left`、`right`、`bottom`、`top`。

## 验证与边界

修改前通过 `lua -` 运行 tests/ldt_provider.lua 的真实装配和 Mount，在纹理替身记录裁切坐标，断言失败：`main LDT icon missing inward crop`。这是 main 的独立复现，不沿用五包分支的测试结论。

- main 完整入口 `pwsh -NoProfile -File tests/check_contract.ps1` 通过。
- 214 个 Lua 文件语法检查、Bindings XML、TOC / SDK / 发布清单检查和 `git diff --check` 通过。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：有意使用递归 Lua 模式；111 个运行 Lua，`valid=true`，零诊断。TOC 清单由完整契约检查覆盖。
- 修改后在完整 LDT 用例末尾运行内存探针：八个图标均保留向内裁切，翻页、展开、滚动及二十次卸载重挂载后每个图标仍仅调用一次裁切。
- LDT 探针：模块 378.1 KiB，20 查询分配 1209.7 KiB，保留增长 0.0 KiB，最大批次 3 ms；未调整门槛。

客户端像素效果及真实 UI 缩放仍未验证。新 lychee-dev 探针需要输入侧 reload；为避免先加载误同步版本，本轮没有提交新游戏任务，没有留下任务或回执。

当前仓库目录已经切到 main；不合并五包分支。游戏交付恢复 main 的单包清单，先备份并核对，再可逆隔离本会话误新增的四个包；不删除或改写 SavedVariables。运行文件及加载关系改变后须重启客户端。
