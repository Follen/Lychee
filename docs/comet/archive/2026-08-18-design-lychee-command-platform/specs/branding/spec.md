# Lychee Branding

## 本 change 的交付形式

本 change 只在设计文档中记录品牌约束。源 PNG 继续保存在本机 `analyze/inputs/`，不复制到运行时目录；媒体转换、打包和游戏内显示验证由后续实现 change 处理。

## Logo 源文件

- 用户提供的源图为 500x500 PNG，`Format32bppArgb`。
- 四角 alpha 为 0，主体像素不透明；运行时显示必须保留透明背景。
- SHA-256：`96887564230FA250D2AF4B151DEC219E9A166F245771C4414135F498E9E4E7E3`。
- 本机保存在 `analyze/inputs/lychee-logo-source.png`；后续实现 change 再复制到正式运行时媒体目录。

## 使用规则

- Logo 用于插件识别和 Palette 品牌位置。
- 缩放保持 1:1 比例，不拉伸、不裁掉叶片和荔枝主体。
- 不增加黑色或不透明方形底。
- 可生成尺寸优化副本，但必须能追溯到相同源文件并保留 alpha。
- TOC/媒体路径变更后需要重启客户端或 `/reload` 验证实际纹理加载。
