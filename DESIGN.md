---
name: Lychee
description: 正式服游戏内的紧凑搜索与操作面板
colors:
  window: "rgb(5.5% 5.5% 6.3%)"
  surfaceHover: "rgb(14.5% 7.5% 8.6%)"
  surfaceSelected: "rgb(20.5% 8.2% 9.8%)"
  accent: "rgb(83.5% 23.5% 28.5%)"
  accentMuted: "rgb(44% 15.5% 18.5%)"
  border: "rgb(16.5% 17% 18.8%)"
  text: "rgb(94% 93.2% 91%)"
  textMuted: "rgb(71% 70.5% 69%)"
  textDim: "rgb(59% 58% 59%)"
typography:
  input:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "16px"
  title:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "15px"
rounded:
  panel: "10px"
spacing:
  tight: "6px"
  control: "10px"
  content: "16px"
  section: "24px"
components:
  palette:
    backgroundColor: "{colors.window}"
    rounded: "{rounded.panel}"
    width: "640px"
  result-row:
    backgroundColor: "{colors.window}"
    height: "58px"
    width: "608px"
  result-row-hover:
    backgroundColor: "{colors.surfaceHover}"
  result-row-selected:
    backgroundColor: "{colors.surfaceSelected}"
---

# Design System: Lychee

## Overview

以已获批的 uTools 紧凑搜索布局为方向：顶部搜索、中间内容、底部状态。用户保留布局，仅要求使用原始荔枝标志、更黑的面板和红色主色。整体服务于快速查找和执行操作。

本文按 `package/Lychee/UI/Theme.lua`、`Input.lua`、`Palette.lua`、`ResultList.lua` 的当前实现记录。获批参考图是布局示意，**不是真实客户端截图**；真实客户端截图、字体与缩放效果、性能采样仍待验证。

## Colors

颜色源自 Theme 的归一化 RGB，前置令牌用等值百分比表示。近黑底色贯穿窗口、顶部、内容、底部和输入区域；深红承载悬停与选中，柔和红色描边强调当前行。主文本偏暖白，描述、分类和状态降低亮度。

红色用于操作状态和品牌强调；输入框聚焦时保持与面板一体的底色，通过文字与搜索图标变化提示状态，不增加红色输入框外框。分类可采用结果数据提供的颜色。

## Typography

输入与结果标题使用客户端 `STANDARD_TEXT_FONT`，其他文字沿用 `GameFont` 字体对象，不引入外部展示字体。前置尺寸以 WoW UI 逻辑单位表达，实际显示随 UI 缩放变化。

结果标题、摘要和分类各占单行；长文本裁切，悬停提示完整标题与详情，避免文字挤压图标和右侧操作。

## Layout

面板固定逻辑宽度，顶部高 64，底部高 32。高度按内容在 164–600 之间调整；小视口整体缩放并留出边缘空间，保持居中位置和紧凑密度。

顶部左侧为原始标志，中间为 48 高搜索区，右侧为 Esc 关闭按钮。空输入时最近使用最多五项排成一行，单项 112 × 84，间隔 8；图标上、名称下。

搜索结果使用单列列表，一次最多显示八行，行间隔 2。滚轮及方向键翻动内容时复用现有行。图标位于左侧，名称与摘要居中，分类和可用的次要操作位于右侧。底部显示状态与操作提示。

## Elevation & Depth

深度来自不透明近黑面板、细分隔线和状态底色。顶部与底部分别以一条细线分隔内容；标志与搜索区之间有短竖线。当前面板没有外发光或投影层。

## Shapes

外壳使用固定圆角；内容行与小操作按钮使用平直边缘。圆角由可复用纹理区域组成，面板变高时保持角部尺寸。结果图标为 32 方形，最近使用图标为 34 方形。

## Components

- **品牌标志**：顶部以 42 方形空间显示原始 `Media/lychee-logo.tga`，保持资源本身的图形与颜色。技能图标直接使用游戏资源。
- **搜索框**：放大镜、占位文案和输入共享面板底色。输入支持方向键移动选择、Enter 提交普通操作；受保护技能需鼠标点击。Esc 关闭面板。
- **结果行**：默认与背景融合，悬停和选择呈深红底与细描边；有次要操作时，仅在悬停或选中时显示按钮。详情放在游戏原生悬停提示中。
- **最近使用**：空输入显示成功使用过的入口；没有记录时显示引导文字。
- **状态变化**：界面直接更新，不使用 Lua 过渡动画或界面常驻 `OnUpdate`。结果行复用，重复的颜色、文字与尺寸设置由状态比较跳过。
- **战斗与施法**：面板通过 `SecureHandlerStateTemplate` 的战斗状态驱动只执行隐藏，脱战不重开。技能使用 `SecureActionButtonTemplate`，`useOnKeyDown=false`；收到成功施法事件后关闭并记录最近使用，失败保留重试机会。

## Do's and Don'ts

- **Do** 保留获批的紧凑布局，使用当前近黑底与红色交互状态。
- **Do** 使用原始品牌标志和游戏提供的技能图标，保持单行标题与悬停详情。
- **Do** 在真实客户端验证缩放、长标题、搜索滚动、施法和战斗关闭，并采样 CPU、内存与帧时间。
- **Don't** 把参考图视为实际游戏截图，或宣称未完成的客户端外观与性能验证已经通过。
- **Don't** 为装饰增加常驻每帧回调，或把 Enter 改为模拟安全施法。
