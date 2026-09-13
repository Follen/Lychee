# 关于页文案与排版

基线 `88a743a7fabb53b365515e3b514e9f098240897c`。按用户指定的 humanizer-zh 改写中英文，并重排现有关于内容。保留产品用途、固定与别名能力、作者、安装版本，以及仅中文显示的“谨献给爱人：荔枝小月亮”。

## 内容和布局

删除“少一点翻找，多一点冒险。”及收进搜索框、按习惯留下等宣传表达。中文改为“在游戏里搜技能、物品和插件设置。”和“常用的可以固定到首页，也能设置好记的别名。”；英文使用 “Search for spells, items and addon settings in WoW.” 和 “Pin favorites to the home page and add your own search aliases.”，直接说明实际功能。别名不是修改技能或物品名称，不添加作者经历、承诺或未经确认的功能。

原左右两列合并为572宽的单列阅读区，所有文字左对齐：

| 内容 | 字号 / 颜色 | 顶部偏移 / 行盒高度 |
| --- | --- | --- |
| 品牌名 | 20 / text，品牌前缀保留荔枝红 | 0 / 28 |
| Follen 与安装版本 | 11 / textMuted | 32 / 18 |
| 用途说明第一句 | 14 / textMuted | 64 / 22 |
| 固定与别名说明 | 14 / textMuted | 86 / 22 |
| 中文献词 | 14 / tooltipAccent | 124 / 24 |

正文不再重复标题层级，两句同字号、明度与行距。中文正文152高、完整窗口338高；英文正文112高、完整窗口298高。共享56高底栏及原有图标、浮窗保持。相对基线，中文/英文文本区域分别由7/6降至5/4；首次进入关于时创建并复用，版本仍只读一次。没有新增Frame、事件、timer、轮询、素材或持久缓存。

## 验证

- `python tests/run.py --report analyze/about-plain-copy/full.json`：103/103通过，包含本地化回退、关于内容、正文边界、共享底栏、二维码/链接弹窗、焦点、复用、战斗、输入法及搜索重开回归；静态语法与发布清单均通过。
- 不含LDT加载常驻1493.5361 KiB / 22ms，完整正式服1855.5811 KiB / 28ms；均为2个Frame、4次事件登记。相对基线完整常驻1855.7939 KiB略降，未修改任何性能门槛。最近使用100轮245ms、峰值4ms、0新增Frame。
- 独立只读文案与布局评估建议保留准确的“别名”称谓、合并作者版本、统一两句正文样式，已采用。
- Impeccable当前启动器的布局扫描返回空结果；此前旧版detect.mjs路径已失效，不计为通过证据。检测器不能证明WoW原生字体和布局正确，仍以源码边界、回归和预览检查作为离线依据。
- `analyze/about-plain-copy/preview.png` 来自实际运行代码导出的文字、尺寸和颜色，包含中文与英文；使用系统字体近似客户端字体，版本9.8.7为测试夹具。检查了左边线、英文占位、献词间距和底栏边界，不代表游戏内截图。

## 原生证据与交付边界

修改前已检查并同步 wowdoc source、构建对应索引后 inspect。sourceId=`wow-ui-source`，product=`retail`，requestedRef=`12.1.0`，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua` 第135行的摘录包含 `Name = "SetPoint"`、`IsProtectedFunction = true`；布局继续在已有非战斗创建路径使用原接口，没有引入新API。修改后 `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0` 检查45个Lua文件，valid=true、无诊断。

游戏内字体、不同UI缩放和实际阅读效果尚未实测。完成文档/差异检查并提交后，使用 `analyze/about-plain-copy/sync.py` 覆盖复制五包188个运行文件，逐个核对SHA-256并保留目标旧文件，交付清单记录于同目录sync.json。没有新增模块或TOC，更新后执行 `/reload`。
