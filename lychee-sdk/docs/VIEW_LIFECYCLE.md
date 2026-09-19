# 可复用视图与生命周期

性能、容量与生命周期预算统一见[性能硬门禁](PERFORMANCE.md)；本页说明接口使用方式。

当前 SDK 为 1.0.0 / API 1.0.0，UI Runtime 为 1。不兼容 API 2；资源见 [托管资源协议](MANAGED_RESOURCES.md)，本包数据库见 [Storage](STORAGE.md)，加载和数据就绪见 [LOADING](LOADING.md)。

适用 Provider API 1.0.0；页面正常回调顺序与资源清理规则如下。
可执行示例：[ThirdPartyFixture](../examples/ThirdPartyFixture/ThirdPartyFixture.lua)。

## 所有权与调用顺序

宿主管理当前挂载，Provider管理面板实例和WoW控件。每次打开都会调用
`create(context, initialState)`；工厂可以返回Provider自己缓存的同一实例。
宿主没有跨Provider面板缓存，不接受`cache`或`lifecycle`注册字段。

| 操作 | 同步调用顺序 | Provider责任 |
| --- | --- | --- |
| 首次打开 | create → Mount(context, initialState) | 首次创建控件，绑定状态和事件 |
| 更新 | Update(state, context) | 使用新数据更新文字、动作身份与订阅 |
| 关闭/替换 | Unmount(reason) → Dispose(reason) | 停止活动，清空本次业务/context引用，隐藏控件 |
| 再次打开 | create → Mount(context, initialState) | 返回缓存实例并重新绑定；父级改变时重新锚定 |
| Mount/Update异常或回调中请求关闭 | 回调结束 → Unmount → Dispose | 能清理未完整创建或挂载的实例 |
| Provider所有者停用/注销 | 当前视图退出，加上Provider自身cleanup | 两条清理路径均幂等，不依赖相对先后 |

关闭“参与搜索”不属于所有者停用，不卸载已打开的业务视图、不停止独立后台和已提交业务操作。真正所有者停用是 `SetAvailability(false)`；注销撤销该注册实例。页面作用域在退出时关闭，清理回调须允许同步重入和重复取消。

Dispose是结束这次挂载的通知，不代表WoW Frame被销毁。可复用实例应保留有界的固定控件树，
不能丢弃唯一引用后反复CreateFrame。卸载后可保留控件、其宿主父容器和固定布局状态，
不保留大业务表、旧handle、动作回调、context或活动timer。
注销后若支持再次注册，可保留一个静止结构，再绑定新handle；不要让同一个缓存实例同时挂到多个宿主。

## 参数调用与订阅

可选 [Invocation](INVOCATIONS.md#provider-自建面板) 能力提供 `context:Prepare`、`context:Invoke`、`context:BeginEdit` 和 `context:Observe`。这些方法从 `Mount` 开始可用，不能在 `create` 阶段使用；调用限定当前挂载的 Provider 及注册实例。Provider 决定控件、草稿、目标和参数，Host 不读取控件内部变量来推断业务。

关闭或替换页面会取消未提交准备、释放未消费 Prepared，并撤销观察和 UI 回调。已经提交的 Invocation 继续由 Provider 操作作用域和截止时间约束；取消可能得到 `indeterminate`，不能把关闭页面当作回滚或成功。连续编辑区分草稿与已确认值，只有确认完成才能形成成功历史。精确返回形状、错误和编辑合同以 Invocation 文档为准。

固定/最近项可能保存完整 Invocation，也可能是打开目标或缺参命令。恢复只读准备完成后才允许执行，不以旧 entryID 或显示标题替代保存参数。页面状态属于本次挂载；持久设置交给本包 [Storage](STORAGE.md)。页面使用本包媒体或经核实的游戏原生资源，不依赖 Host 私有资源目录。

## 推荐实现

示例的`cachedPanel`最多保存一个控制器，不按条目ID增长。Frame在Mount中首次创建；
每个创建成功的控件立即保留引用，下一次Mount能够补齐部分失败的创建过程。
parent或布局setter全部成功后才记录已应用状态，失败时不留下错误的“已经完成”标记。
Mount重新读取初始状态，Unmount和Dispose共用一个幂等的release函数。

需要异步工作的面板使用自己的代次：关闭时先失效，再取消任务；迟到回调同时检查active与代次。
宿主无法取消插件私自启动的timer或抢占任意慢的同步回调。

```lua
local function release(panel)
    panel.active = false
    panel.generation = panel.generation + 1
    panel.context, panel.entry = nil, nil
    panel:StopSubscriptionsAndTimers()
    if panel.frame then panel.frame:Hide() end
end
```

这是异步面板的职责示意：generation需由插件初始化；StopSubscriptionsAndTimers由插件实现，
不是宿主API。当前可安装示例没有异步任务，因此不额外创建timer或无用的代次记录。

## 错误、状态与重入

- create返回可访问方法的table或引擎对象；非法实例和方法访问抛错进入PANEL_ERROR。
- Mount/Update的返回值不作为失败信号，返回false不会自动关闭；抛错才进入清理。
  缺少可选方法仍可工作，建议实现完整四方法契约。
- 生命周期回调内同步再次挂载/更新返回PANEL_BUSY，不排队、不延迟下一帧；不能在回调里循环重试。
  请求关闭可以接受，当前回调完成后清理；被取消的挂载/更新返回PANEL_CANCELLED。
- Unmount抛错仍尝试Dispose；清理错误也不能让宿主保留活动绑定。插件仍须确保自身释放完整。
- 初始状态同时传给create和Mount；Update接收状态本身，不是`{state=...}`。
  不承诺每次挂载深拷贝状态；不要修改调用方状态或持久保存context。
  插件修改context.extensionID不会改变宿主保存的归属。
- 构造控制器时不要创建一半Frame后抛错并丢掉引用；先缓存控制器，Mount中逐项创建控件。

## 接入验收

1. 首次、换状态、换父级显示正确内容，动作参数不变。
2. 反复打开100次，Frame/Region数量稳定；隐藏后页面事件/timer归零，所有者停用/注销后对应活动资源归零；独立后台不因搜索关闭停止。
3. 两次清理、部分Mount失败、Update异常和迟到回调均安全。
4. 注销后同ID重新注册使用新handle，不保留旧context。
5. 分开统计累计分配、GC后保留、引擎对象数量，不能把GC当作Frame释放。

仓库回归：`lua tests/ui/view_lifecycle.lua`与`lua tests/ui/interaction_smoke.lua`。
离线替身只证明逻辑与计数，布局、保护操作和客户端事件顺序仍需实机验证。
