# 纹章详情图标裁剪

用户实机截图显示五个纹章图标保留了原始纹理的白色边缘。详情页只设置纹理与尺寸，未像 ResultList / Palette 一样设置裁剪坐标。

在 Crests 面板首次创建每个图标时设置 `SetTexCoord(0.07, 0.93, 0.07, 0.93)`，与现有搜索结果和首页比例一致。保持 32 × 32 尺寸及布局；五个图标总计新增五次初始化 setter，刷新和重开不重复调用，无新增对象、事件、timer 或每帧逻辑。

## 版本依据

- 查询：`wowdoc source list --source wow-ui-source --product retail`；`wowdoc query --source wow-ui-source --product retail --ref latest --topic api --text SetTexCoord --limit 2`。
- sourceId：`wow-ui-source`；product：`retail`；requestedRef：`latest`；resolvedCommit：`8ea15b61e45c0ed4eba01439c90757f86eb78d34`（source list 对应 12.1.0）。
- path：`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua`，line：576。
- 返回 excerpt：`Name = "SetTexCoord"`；583–586 行列出四个必填 number 参数 `left`、`right`、`bottom`、`top`。

## 验证范围

这是单处固定样式修改，不新增仅复述常量的测试。沿用完整契约检查、Lua 解析、XML/TOC 检查和 wowdoc validate；实际结果在本次交付中报告。裁剪比例沿用现有 UI，更新后真实客户端像素效果仍需 `/reload` 后查看；不以静态检查代替实机视觉验证。

实际检查：20 组契约测试通过、39 个运行时 Lua 解析通过、Bindings XML 解析与 TOC 引用检查通过、wowdoc 返回 `valid=true` 且无诊断，`git diff --check` 通过。首次契约运行因纹理替身缺少 SetTexCoord 而失败，补齐该 API 后通过；未改变原有测试断言。
