# 关于页与底部社交素材

两张码图以用户提供的微信赞赏小程序码、作者微信二维码为输入，经内置imagegen生成荔枝配色版本；用户于2026-09-13明确回复“两张都能正确识别”。采用深荔枝红码点、红色中心标识和白色留白，原PNG保留供复验。生成提示词保存在 imagegen-prompts.json。不得以AI生成过程本身证明码图可扫描；当前扫码证据是用户明确实测确认。

- wechat-support-v1.png：微信赞赏。
- wechat-contact-v1.png：作者微信。
- icons/github.svg、paypal.svg、x.svg、wechat.svg：[Simple Icons](https://github.com/simple-icons/simple-icons/tree/develop/icons)，2026-09-13下载，CC0-1.0；完整授权在 icons/LICENSE.txt。
- icons/support.svg：项目绘制的手托爱心图标。

使用 `python tools/build_about_assets.py` 构建，依赖Pillow与CairoSVG；脚本只编译本地已确认素材，不在线下载或重新生成码图。图标64×64透明RGBA，码图512×512 RGBA；运行纹理存于 addon/Lychee/Media/About，SHA-256清单见 textures.json。

实际图标显示22×22（点击区28×28），码图显示256×256；放在原生游戏窗口中的最终扫码能力、物理像素和不同UI缩放由客户端复验。PNG、SVG、生成提示词及预览不打入游戏运行包。
