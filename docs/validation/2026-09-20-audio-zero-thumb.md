# 音量 0% 初始滑块缺失

## 原因与修复

基线 `2b0c777`。首次打开音量面板时，音乐为 0%，红色滑块缺失。实机 `GetValue()` 返回 0，但新 thumb 的锚点数为 0，`GetRect()` 无有效位置；其余四行都有一个锚点。补一次同值 `SetValue(0)` 仍不产生布局，不能只绕过 Lua 的同值检查。

创建 thumb 后设置一个位于轨道左端的初始锚点；数值变化仍由原生 Slider 更新位置。没有改动音量写入、历史、拖动提交、观察订阅或刷新频率。

成本：只在五条复用 Slider 首次创建时各多一次 SetPoint。没有新增 Frame、纹理、表、持久字段、事件、计时器或空闲驱动；原有同值跳过 setter 继续保留。关闭取消编辑与观察，重新打开复用原对象。战斗/团本/姓名板常驻路径不适用本次局部初始化修复，不宣称性能提升。

## 版本证据

wowdoc source list/check；sourceId `wow-ui-source`、product `retail`、requestedRef/matchedTag `12.1.0`、resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua:195–203`：`SetThumbTexture(asset: TextureAsset)`。
- 同文件 `206–214`：`SetValue(value: number, treatAsMouseEvent: bool = false)`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135–148`：`SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)`。

原生同值不建立锚点是下面的实机观测，不是根据 API 签名推断。原始查询保存在本地 `analyze/audio-thumb-*-api.json`。

## 复现与验证

后台 lychee-dev messages，Retail 12.1.0.69875 / Interface 120100 / zhCN，晴昼秋岚—白银之手，PID 29260、HWND 0x50c9e。测试只改变控件显示，不调用音量写入；临时隔离历史/搜索选择，结束恢复原数组。

- 基线 Ticket `LYCHEE-20260920-024735-0022`，request `audio-thumb-baseline-20260920` / revision `baseline`：五项检查中音乐失败，其他四项通过。完整 payload 2072 字节，SHA-256 `90b2c5b1536219e42a718740f74cab4303c065747b8a89525751a7a9642ff5f6`。
- 同值赋值对照 Ticket `LYCHEE-20260920-024945-0023`，request `audio-thumb-initialize-20260920` / revision `initialize`：音乐仍无锚点，否定只补 SetValue(0) 的方案。完整 payload 2180 字节，SHA-256 `ac7f0d66e00d67c9ec67910cae33745079980b0d05e8cfab73c2de3eed207f02`。
- 两个报告均完整读取、核对环境并 ACK received，确认码已清理。报告外层 succeeded 仅表示探针成功采集；音乐检查明确为 false，不能视为功能通过。
- payload 根目录：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/<Ticket>/content.json`，同目录包含 evidence/report。

离线回归 `lua tests/ui/audio_controls.lua` 覆盖首次 0%/100%、外部更新、同值刷新、拖动不被覆盖、关闭取消及重开复用。替身的原生布局行为依上述实机证据建立，不能替代最后的原生几何及视觉验收。

最终检查、同步及修复后实机结果待补记。
