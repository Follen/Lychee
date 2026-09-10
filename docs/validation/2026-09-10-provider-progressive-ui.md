# Provider 管理页：先展示用法，按需编辑

基线2c28d37。只改设置页、中英文文案及DESIGN；搜索策略、SDK和协议不变。

概览先展示普通搜索状态、已配置入口的本地语言优先示例；其他入口用数量提示。无入口仅显示添加按钮。修改展开一个编辑区并聚焦，切换保留草稿，取消编辑或Escape还原该字段；保存仍统一提交，取消页面仍丢弃全部未保存修改。关于信息默认折叠；没有编辑或修改时隐藏底部保存／取消。错误就地显示、页脚提示并滚动到可见区域。

成本与生命周期：复用固定两个输入、四个添加／编辑按钮和一个关于按钮，不按入口数创建Frame。已创建页面20次重开无新增Frame；布局按编辑项、字段是否为空、关于／错误／修改状态做变化检查，输入普通字符不重排整页。无新增事件、OnUpdate、timer；隐藏沿用焦点、拖动和页面动画清理。预算沿用PERFORMANCE，不提高阈值。

tests/check_contract.ps1完整通过（.codex/progressive-full.txt）。覆盖初始不显示编辑框／版本、添加只展开一项、取消编辑还原、关于展开收起，以及既有保存、来源启停保留草稿、无入口错误、重绑拒绝、关闭焦点释放。错误定位追加后interaction_smoke再次通过（.codex/progressive-confirm.txt）。固定2689条目录7261.5KiB、48次查询分配1814.1KiB不变；1000来源8行，20次刷新37.4KiB、池增长0。列表预算不代表二级页原生纹理内存，未作游戏帧率结论。

wowdoc retail source check无更新；sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。编辑框沿用SetFocus、SetText、现有共享控件。retail validate检查71 Lua，valid=true，无诊断；完整检查含Lua/XML/TOC，diff与Impeccable layout扫描通过。

视觉检查基于用户截图和源码布局；不能模拟WoW的真实字体、缩放、鼠标焦点或战斗安全环境。实机视觉、滚动和动画待/reload验收。无新模块／TOC修改。回滚使用新git revert并同步。
