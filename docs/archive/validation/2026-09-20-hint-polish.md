# 首次使用气泡精简与动画 0.3.4

基线8f88724，运行提交6ebace0。将280×70双行块改为按文字宽度244–350×42单行提示，确认按钮改为11号，同排显示；尖角12缩至8。首次出现采用0.25秒原生Alpha与Translation并行动画，位移6，结束后固定最终锚点。共享Motion的96组容量、Cancel、StopAll、减少动态效果均涵盖此组；OnHide停止，无轮询、无限动画或新计时器。首次需要时最多增加一组两动画，复用，已确认用户不创建。

完整契约、Lua解析、仓库/发布检查、四客户端wowdoc校验通过。新增离线回归验证入场、取消、20次组复用、减少动态效果时立即稳定；原有容量测试保留。API证据sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimTranslationAPIDocumentation.lua:24 SetOffset。其余Alpha和AnimationGroup复用现有Motion实现。

正式服12.1.0.69875、zhCN、晴昼秋岚—白银之手，Ticket LYCHEE-20260920-162314-0052，requestId hint-polish-20260920-1。报告完整成功，9项断言通过；启动时原生组IsPlaying=true，约0.1秒采到平滑进度0.587785，0.4秒检查已完成。实测244×42，WGC截图确认文字/按钮不重叠、图标上方不遮列表；截图本地analyze/onboarding-hint.png。确认、20次重开不再出现和设置入口确认继续通过。完整报告见[运行证据](2026-09-20-hint-polish-runtime.json)。

整次主窗口Show 2.381 ms，非气泡独占CPU。GC后四批读数13703.229、13627.698、13628.597、13629.495 KiB，相比上一版同探针约+5.95 KiB；观察器单列约4298.199 KiB。新增保留归因于有界动画状态/回调与代码，不增加Frame；原生两动画内存未以Lua堆代替。每批0.898 KiB尾部增长仍包含同回调连续Show排入的既有焦点回调，不能宣称排空后的稳态已验证。接受有限共享动画组与紧凑提示的功能收益，不提高门槛或声称总体内存降低。

196运行文件已同步正式服，逐文件SHA-256一致，reload握手成功；dist已重新构建。ACK received且ticket_ack_cleared，自有任务已移除，提示确认值及动态效果偏好恢复。英文/其他客户端实机、真实战斗及长时间稳态仍未覆盖。本轮未推送或对外发布。
