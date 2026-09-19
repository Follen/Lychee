# 大米助手技能详情图标裁切

截图中的技能详情行保留原图边框。详情页使用独立纹理，没有经过首页或搜索列表的 cropIcon；创建时只设置尺寸，RenderSkills 只更新纹理和位置。

修复在八个复用技能行的图标创建时设置 `SetTexCoord(0.07, 0.93, 0.07, 0.93)`，沿用现有列表的裁切比例与 32×32 尺寸。首次创建新增八次 setter；翻页、展开、刷新和重开不追加裁切调用。没有新增对象、缓存、事件、timer 或每帧逻辑，性能预算不变。测试替身补齐 SetTexCoord 接口，不为样式常量新增重复实现的永久测试。

## 版本化 API 证据

- 已执行 source list / source check；check 提示远端有更新，本次使用确定版本 12.1.0，不以 latest 代替。
- 查询：`wowdoc query --source wow-ui-source --product retail --ref 12.1.0 --topic api --text SetTexCoord --limit 1`。
- sourceId: `wow-ui-source`；product: `retail`；requestedRef / matchedTag: `12.1.0`。
- resolvedCommit: `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。
- path: `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua`；line: 576，参数位于 583–586。
- excerpt: `Name = "SetTexCoord"`；四个必填 number 参数为 `left`、`right`、`bottom`、`top`。

## 验证

诊断阶段通过 `lua -` 执行内存探针：使用 tests/providers/ldt_provider.lua 的真实装配与视图 Mount，在纹理替身记录 SetTexCoord，断言坐标四边均向内。原实现输出 `cropCalls=0` 并失败；只在内存中给真实 View.lua 创建路径补上裁切后，八个图标通过，且每个仅调用一次。未修改磁盘源码来制造对照结果。

- `python tests/run.py --report analyze/tests/2026-09-20-ldt-icon-crop.json`：full，103/103 通过，包含 199 个 Lua、1 个 XML、20 个 Python 文件的语法检查，以及 TOC、交付、SDK、业务、UI 和性能门禁。
- 正式修复的内存探针执行完整 LDT 用例后检查八个图标，向内裁切均保留，完整生命周期中每个图标仅一次 SetTexCoord。覆盖既有翻页、展开、重绑、滚动和二十次卸载重挂载。
- LDT 专项：模块 376.1 KiB，20 次查询累计分配 1192.3 KiB，保留增长 0.0 KiB，最大批次 4 ms，沿用现有门槛。
- wowdoc TOC 模式：Host 在约 4 分半钟 CPU 时间后仍未返回，改为 Encounters 正式服 TOC 后也持续未返回；两次均中止，不能计为通过。
- 有意改用 legacy 递归 Lua 验证，并以已通过的完整契约覆盖 TOC 清单。`wowdoc validate --path addon/Lychee_Encounters --source wow-ui-source --product retail --ref 12.1.0` 在不到一秒内返回，14 个 Lua，`valid=true`，零诊断。它证明包内递归 Lua 检查通过，不代表 wowdoc 的 TOC 模式已通过。
- 其余四包同版本递归检查均通过：Host 45、Player 32、Integrations 8、Inspector 7 个 Lua；五包合计 106 个 Lua，均 `valid=true`、零诊断。
- `git diff --check` 通过。

离线验证不能证明客户端像素效果；游戏字体、UI 缩放下的裁切与实机性能尚未验证。目标游戏目录此前只有旧单包 Lychee，交付将按发布清单补齐五包并保留额外旧文件，因此需要完整重启客户端以发现新增包。
