# 0.3.36 分类下划线

运行提交57b305c5004b31d833ce8064cd16fe0be2238620。大米计算页固定28宽下划线改为文字完整宽度向上取整；左缘锚点、厚度、颜色不变。分类渲染时仅宽度改变才写入，无新增Frame、timer、事件、SV或增长缓存。DESIGN.md同步规则。

完整契约、Lua语法、Mainline wowdoc验证及diff检查通过。API来源wow-ui-source/retail/12.1.0，commit4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，SimpleFontStringAPIDocumentation.lua:398–408，GetUnboundedStringWidth返回uiUnit。

已同步正式服200个运行文件并核对全部SHA-256，保留目标额外文件。Retail12.1.0.69875/zhCN，灵止光—死亡之翼，实机Ticket LYCHEE-20260921-083449-0096，request underline36-20260921-c/revision3，complete=true、pass=true。三分类文字宽39.7826/39.7826/39.1304，请求下划线40，实际40.000019；原生坐标浮点误差小于0.01。切换三个分类均符合文字宽度，不再固定短线。ACK received及临时任务清理完成。

前一Ticket LYCHEE-20260921-083308-0095使用精确浮点相等断言失败，已ACK；补采实际值证明是0.000019的精度差异，生产代码未因测试调整。没有截图视觉验收或其他语言客户端实测；无常驻路径变化，不宣称游戏性能收益。
