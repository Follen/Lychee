# 空白搜索修复

前版本 f38be2c。原始空格不等于空字符串，Host 启动动态查询；成就规范化空词匹配全部。回归在旧代码失败：whitespace must not query all achievements。现在无类别且规范化为空时直接返回空结果，不调用静态/动态来源；界面统一用 IsBlank 判断 ASCII 空格/制表/换行，显示并操作最近使用，不改写用户输入，不改变正常多词及显式类别过滤。

成本：IsBlank 单次线性字符串检查，无表、Frame、timer 或缓存新增；查询短路减少来源工作，未改变预算。完整契约及原有内存门禁通过；纯空白不启动 Provider job、成就类别浏览、真实 Palette 最近使用保持均 PASS。独立动画测试补加载真实 Normalizer。Lua/XML 静态、wowdoc validate、diff 检查结果见日志；无新增 Blizzard API，沿用已核对的输入/布局接口。游戏显示与键盘行为待实机 /reload 后复核。
