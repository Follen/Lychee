# 关于页与联系浮窗布局修正

基线提交d4f3ff74613bc14d41e2e457c454368d03ac5c76。用户实机截图指出码图过大、图标贴近底边、关于内容过少，并要求中文加入“谨献给爱人：荔枝小月亮”。

## 修改与成本

- 关于页从518高长列表外壳收为中文402、英文374逻辑单位；保持640宽、统一缩放和固定顶部位置。简介、功能说明、使用方式、版本作者依次分组，献词仅在zhCN/zhTW分支以11号柔和荔枝色显示。文字归Host词典，不新增产品能力或外部链接。
- 设置底栏32→56高，三个28点击区上下各14，图标22→18，点击区间隔14→8，整组右缘内距28。内容底边同步上移，避免最后一行进入底栏；搜索和普通详情恢复32高。
- 码图显示256→176，浮窗288×338→208×252；链接浮窗380×112→316×100。浮窗固定右对齐入口组，在其上方8单位向窗口内部展开，不再围绕最右图标居中而伸出主窗口。标题14→12，提示11。
- 已批准的源图及运行纹理字节未变，没有重新生成码图或改变码点。原码图扫码确认不自动覆盖176显示尺寸，最终游戏内扫码待用户复验。
- 改动只由打开设置、切页及既有布局调用触发；底栏高度变化才写Frame高度与内容锚点，无新事件、计时器、循环扫描或Frame。关于页首次访问增加有限文案区域，之后复用；保留原浮窗焦点、纹理与动效清理。使用现行1974/1858 KiB等门禁，未再放宽任何预算。

## 回归与审查

- `analyze/about-layout/full.json`：102/102通过，包括原契约、静态解析、交互、性能与交付清单。
- 独立审查发现pending零结果搜索的提前返回会跳过底栏恢复；已将恢复移至有效Frame、非战斗检查之后且在提前返回之前，保持等待时不收缩主窗口的既有行为。补充真实关于页→关闭设置→异步搜索回归。
- about_social四语言回归验证紧凑外壳、底栏上下留白、向内展开、中文限定献词、复用和关闭，以及返回搜索的尺寸恢复。测试使用真实Bootstrap语言初始化，不再启动后覆盖IsChinese；对应品牌名也验收。最终语言、导航及静态检查7/7通过，报告final-locales.json。测试装配默认语言仍为zhCN。
- 离线预览按测试对象导出的实际文字、字号和尺寸检查中英文与浮窗四种状态。首次预览暴露测试装配事后改语言导致品牌名不随语言初始化的问题，已修正装配并通过真实品牌断言。预览不作为原生游戏字体、遮罩命中、扫码或动效的证明。
- wowdoc validate：45个Lua文件，valid=true，无诊断。文档检查、布局机械扫描和git diff检查通过；机械扫描不能解析原生像素，不能代替实机验收。

## 性能样本的限制

首次选定回归中最近使用测试触发5ms峰值（门禁严格小于5ms），失败原文保留于selected.json。三次前一提交对照峰值为4/4/5ms，三次当前版本为5/8/5ms，均无对象增长；原始报告performance-comparison.json。旧版本同样可触发门禁，样本不足以归因于此次布局，也不能证明当前版本没有尾延迟回归。未修改计时器或降低门槛。

修正pending底栏后完整检查中，100次最近使用为228ms总量、4ms峰值、24137.4KiB累计分配、无保留增长和新增Frame。单次完整通过不能解释此前8ms峰值，不宣称性能优化；游戏内性能、字体换行、缩放、码图扫码及原生Esc/鼠标分发仍待验证。

不含LDT正式服加载1488.6514KiB/19ms，完整正式服1850.6963KiB/24ms，均为2Frame、4事件；相对前一提交各增加约2.22KiB。1000来源设置列表保留656.5KiB，20次刷新28ms、累计分配0.4KiB、对象池增长0，全部沿用原门禁。

## 原生接口依据与交付

本轮source list/check后继续固定sourceId=wow-ui-source、product=retail、requestedRef=12.1.0、resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34，不混入远端latest变更。

| path | line | excerpt |
| --- | --- | --- |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua | 135 | SetPoint；IsProtectedFunction=true；point、relativeTo、relativePoint、offsetX、offsetY |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua | 124 | SetHeight；IsProtectedFunction=true；height:uiUnit |

底栏修改沿用ResizeForMode非战斗保护。无新模块、TOC或运行素材变化；提交后按五包188文件清单同步、逐项SHA-256核验并保留旧文件。实际提交和同步结果记录于analyze/about-layout/sync.json。游戏执行/reload。
