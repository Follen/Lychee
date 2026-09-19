# Invocation（可选能力，SDK 1.0.0）

注册前检查 `Lychee.SDK.Invocation` 是否存在。SDK/API 版本保持 1.0.0；动作和目标的数据版本独立编号。未声明参数 schema 的普通动作使用 `run(entry, context)`，不自动解释为参数调用。

项目内的音量条目属于 `builtin.blizzard-settings`，动作与目标由设置来源声明；没有独立音量 Provider。下面的 `example.volume` / `set-volume` 是第三方教学示例，不是可直接调用的内置动作。第三方自行定义稳定 Provider ID、目标 key 和参数，不依赖内置业务结构。

## 动作与参数

```lua
actions = {
  ["set-volume"] = {
    title = "Set volume", actionVersion = 1, absolute=true,
    conflictKey="volume", panel="controls", -- controls 必须在 views 中显式注册
    schema = {percent={type="integer", min=0, max=100, step=1, required=true}},
    run = function(invocation, context, reply)
      -- Provider 执行业务并验证结果后，才报告 succeeded。
      return {status="succeeded", changed=true}
    end,
  },
}
```

`schema` 是参数名到字段规则的纯数据映射。所有类型可声明 `required`、`default`、`unit`；缺省默认值只在成功准备时展开，`false` 是合法默认值。未知字段、函数、metatable、循环、secret/不可访问值及非有限数被拒绝，输入不被修改。

| type | 类型专属字段 |
| --- | --- |
| string | 必填 `maxLength`，可选 `minLength`（字节） |
| number | 必填 `precision`（0–6），可选 `min`、`max`、`step` |
| integer | 可选 `min`、`max`、`step` |
| boolean | 无 |
| enum | 必填 `values`，1–32 个互不重复的稳定字符串 ID |
| list | 必填 `items`、`maxItems`，可选 `minItems`、`set`；items 为上述标量字段，列表不嵌套 |

参数最多32字段，列表最多32项。每次纯数据接收限制深度6、256节点、16384逻辑字节；单字符串最多1024字节，参数名64字节。逻辑字节按字符串实际字节、其他节点16字节计量，不是 Lua 堆大小。schema、参数和具体引用均执行有界接收，默认值展开后再检查结果预算。

数字可使用 Lua number 或有界十进制文字；数字文字不支持单位或指数，业务解析先单独处理单位。`30` 和 `30.0` 等价；`-1` 保留负号。按 precision 转为十进制整数后验证 step（相对于 min，未设 min 时相对于0）。只容忍二进制表示误差，不对非法用户值舍入、夹取或改用默认值。数值绝对值最多十亿。列表顺序默认有意义；显式 `set=true` 时排序去重后判等。

## 引用与准备

```lua
local invocation = {
  kind="invocation", product="retail", providerID="example.volume",
  actionID="set-volume", actionVersion=1,
  target={version=1, key={channel="master"}}, args={percent=30},
}
```

TargetRef 必须包含正整数 `version` 和非空、有界的具名 `key`。没有可恢复目标的动作也应由 Provider 声明一个稳定目标，不以显示名称猜身份。

`Lychee.SDK.Invocation` 使用冒号方法：

- `ValidateSchema(schema)`：返回隔离 schema 或 `nil,error`。
- `NormalizeArgs(schema,args)`：展开明确默认值，返回隔离规范化参数或字段错误。
- `ParsePatterns(raw,patterns,schema?,rawOffset?)`：按有界字面片段和具名参数槽完整匹配原文，可保留路由前输入位置，见下方句式合同。
- `NormalizeStoredRef(ref)`：严格校验纯引用，不加载目标、不执行动作。
- `Equal(a,b)`：有界结构判等；包含 kind、product、Provider、动作/版本、目标/版本和参数，忽略 title/icon/sourceTitle 显示回退。非 legacy-entry 的 entryID 仅是展示与排序提示，也不参与身份。
- `Prepare(providerID,actionID,target,args,context,reply)`：成功同步返回 `prepared,nil,operation`；异步返回 `nil,{code="PENDING"},operation`。可选 reply 接收 `(prepared,error)`，至多一次。
- `PrepareStoredRef(ref,context,reply)`：按保存的具体 Invocation 准备，拒绝不同产品、不同动作版本；其他 kind 返回 `INCOMPLETE_INVOCATION`。不静默降为打开页面。
- `ToInvocation(prepared)`：导出隔离的规范化具体调用，不能导出执行凭据。
- `Release(prepared)`：放弃尚未消费的凭据，返回是否确实释放。
- `Invoke(prepared,context,reply)`：返回 `operation,error`；reply 接收终态结果。

上述规范化接口返回隔离数据；调用方修改返回的列表、默认值或 target，不会改写输入或其他调用结果。Host 在已接收的记录内部可使用只读校验，避免仅为检查而再次深拷贝；这不是公开的免校验入口。只读路径仍执行可访问性、纯数据、循环、深度、节点、逻辑字节及字段限制。每次调用仍检查当前 schema，不缓存可变的第三方参数声明。SDK / Provider API 版本保持 1.0.0。

也可用 `Lychee:PrepareInvocation(...)` 和 `Lychee:InvokeInvocation(...)`。公开 Prepare/PrepareStoredRef 为显式请求进行必要的冷加载和 Provider 就绪准备，再调用目标恢复与能力描述；关闭参与搜索不阻止该入口。SDK 不在准备阶段调用 run；Provider 也必须保持这些回调只读。

Prepared 是 SDK 私有弱键表签发的不透明凭据，绑定当前 Provider 注册实例、启用生命周期、角色、目标身份、动作身份/版本和能力描述。全 Host 最多64份有效凭据；超过返回 RESOURCE_LIMIT。用户数据字段不能制造授权。Invoke 消费凭据一次，失败或能力改变后重新准备；不能重复提交或持久化 Prepared。

## 可选目标恢复与动态描述

```lua
resolveTarget = function(ref, context, reply)
  return {status="ready", target=ref, identity="stable-target-instance"}
end
describe = function(target, actionID, context, reply)
  return {available=true, revision=1} -- 可带当前 schema、不可用 code
end
```

两者可以同步返回纯数据，或者异步 `reply(data)` 并返回 `cancel(reason)`。重复、超时和生命周期结束后的 reply 无效。resolveTarget 的其他状态为 `notReady`、`temporarilyUnavailable`、`deleted`、`incompatible`；不猜同名替代目标。describe 的严格字段为 available、revision、schema、code；revision/identity 为有界字符串或有限数。没有动态回调时使用已注册静态动作及目标引用。

Invoke 重新恢复目标、描述能力、校验参数，再核对先前准备身份；能力/schema/目标变化返回 `CAPABILITY_CHANGED`，不替换用户参数。Provider 关闭参与搜索不阻止独立 Invocation。

## 完成与取消

新动作 `run(invocation,context,reply)` 接收隔离调用与有界纯 context。它可同步返回结果，或返回取消函数后异步 reply。结果严格字段为 `status`、`code`、`value`、`changed`。

- `pending` 只表示等待，不是成功，允许之后回复终态。
- 终态为 `succeeded`、`failed`、`cancelled`、`indeterminate`；至多消费一次。
- 成功结果由 SDK 附带临时 operationID 和规范化 invocation，Host 才可据此记录历史。
- `operation:GetState()` 返回隔离状态；`operation:Cancel()` 幂等。未 dispatch 可取消；已 dispatch 时只有取消函数明确返回 true（确认不会再生效）才报告 cancelled，否则报告 indeterminate。
- 5秒期限覆盖同一请求的加载、就绪与参数准备；`context.deadline` 可传入更早的绝对时间（同 Host QueryTime 时钟），所有阶段使用剩余时间，不能重新起算5秒。Invoke 的再准备继承其外层截止时间。同步慢回调不能被抢占，但返回后仍拒绝过期成功。
- 抛错或非法业务结果不能证明未写入，已 dispatch 返回 indeterminate；不自动重试。
- 业务完成后导航失败不撤销业务成功；旧 UI、旧角色、迟到 reply 不得重新打开面板或重复记录历史。

操作复用 Provider Resources 的64项额度，活动作用域内只有一个 deadline，终态关闭并断开取消函数、上下文和接收闭包。Provider 即使保留旧 reply，也不会通过它继续保活已丢弃的 operation、Invocation 或终态结果；调用方主动持有 operation 时，GetState 仍可读取其隔离结果。无新增 Frame 或空闲驱动；诊断最多32项。Host 在战斗/角色结束入口使用内部 `I.Invocations:CancelAll(reason)`；Provider 生命周期结束由其 Resources 关闭。用户关闭搜索不进入该结束路径。

`execution="secure"` 的动作由普通 Invoke 返回 `SECURE_ACTION_REQUIRED`，绝不调用普通 run。技能/物品的合法物理点击继续使用 Host SecureActionBroker；Prepared 不是绕过安全点击的权限。

## StoredRef 分支

所有新分支包含 kind、product、providerID，可带有界 title/icon/sourceTitle 显示回退：

| kind | 身份字段 |
| --- | --- |
| legacy-entry | entryID，保留旧打开对象语义 |
| target | target |
| command | actionID、actionVersion，可选 target；缺参进入 Provider 自建补参界面 |
| invocation | actionID、actionVersion、target、完整规范化 args |

纯引用校验不等于当前可执行。具体调用重放仍经过 PrepareStoredRef/Invoke；未知版本和损坏原始存档必须保留，不按显示回退恢复业务身份。

## Entry、收藏与恢复

搜索 Entry 可带 `invocation`、`command` 或 `targetRef` 之一，并可带 `{code,field?,span?}` 形状的 `invocationError`。可选 span 为原始完整输入的 UTF-8 字节位置 `{start,finish}`，采用下文 originalSpans 的闭区间规则；统一记录边界拒绝未知字段、非整数和越界位置，不根据当前文本猜位置。入口仍需显式声明 actions。完整参数动作对应 actions 中的动作 ID；非法或缺失参数应返回 command 与明确的补参面板动作，不能把非法值改成默认值执行。旧式 `actions.panel.run(entry)` 返回打开面板结果可继续使用，因此右键打开面板不必执行 Entry 的具体 Invocation。

### 同一条结果的不同参数动作

菜单描述符可使用 `kind="invocation"`，为每个入口携带自己的具体引用。描述符 `id` 在这条 Entry 中唯一；它不必等于 `invocation.actionID`。例如开启和关闭复用同一个参数动作：

```lua
actions = {
  {id="enable", title="Enable", kind="invocation", invocation={
    kind="invocation", product="retail", providerID="example.settings",
    actionID="set-enabled", actionVersion=1,
    target={version=1,key={setting="notifications"}}, args={enabled=true},
  }},
  {id="disable", title="Disable", kind="invocation", invocation={
    kind="invocation", product="retail", providerID="example.settings",
    actionID="set-enabled", actionVersion=1,
    target={version=1,key={setting="notifications"}}, args={enabled=false},
  }},
},
primaryActionID = "enable",
```

引用必须属于发布 Entry 的 Provider，动作已注册、版本相符且参数满足其 schema。不能传 command、不完整引用、其他 Provider 的身份或额外字段。Host 在接收时复制并校验，在用户操作时重新准备目标和参数；过期行不能执行。历史记录保存实际执行的 Invocation，因此关闭动作不会误存成默认的开启参数。数量和数据预算仍遵循现有 Entry/Invocation 限制。

整行 `invocation` 与菜单描述符可同时存在：完整输入的默认动作执行整行引用，菜单各自执行自己声明的引用。行上的输入错误阻止默认执行，但用户仍可通过明确的其他菜单动作打开调整面板或原生设置。第三方不需要访问 Host 内部执行器。

`action.panel` 必须是已注册 views 的 ID。command 收藏恢复时打开此面板，state 为保存的 target.key 或空表；没有面板返回 TARGET_VIEW_UNAVAILABLE。具体 Invocation 收藏恢复先只读 PrepareStoredRef，完成后保留执行和可选面板动作，不触发写入。异步恢复保持 pending，终结失败不降级为旧 entryID。

目标收藏需要 Provider 显式声明 `targetView="target-controls"` 和 `resolveTarget`。恢复成功后只打开指定 view，并传 `state={target=normalizedTarget}`。该 view 的 stateSchema 必须接收这一形状，例如 `{target={version="integer",key={channel="string"}}}`。没有 targetView 返回 TARGET_VIEW_UNAVAILABLE；Host 不猜第一个 view，也不以目标显示名查找替代对象。

旧 `{providerID,entryID,...}` 存档不改写 schema，仍由原 resolve(entryID) 恢复。新引用按完整参数身份区分收藏；同一入口的30与50不会合并。搜索排序只投影稳定 entryID 提示，每个入口最多一份收藏权重和一份近期权重；这些权重不携带或替换当前参数。具体 Invocation 的自定义别名只有完整匹配才恢复保存参数，业务解析始终使用原始 request.raw，不能从会丢弃负号的搜索规范化文本反推数值。

Host 仅在执行确认 succeeded 后记录具体 Invocation。pending、failed、cancelled、indeterminate 不被记为新成功；保存近期最多8项、65536逻辑字节，固定项最多64项、65536逻辑字节。损坏原始记录保留并停止覆盖。SDK 直接 Invoke 只报告结果，搜索执行器和 ViewContext 负责记录历史；业务不得把 Prepare 的成功当作完成。

别名与查询选择分别最多128条、128 KiB总逻辑字节，保存新引用时保留完整身份。写入先检查候选集合，超过容量拒绝且不修改原值；加载时超限保留原存档并进入 PERSONALIZATION_LIMIT 恢复状态，不截断大引用以绕过预算。

## Provider 自建面板

以下冒号方法在 `Mount(self,context,state)` 起可用，限定当前挂载的 Provider 和注册实例：

- `context:Prepare(actionID,target,args,reply)`：与 SDK Prepare 返回协议相同；关闭面板取消未提交准备并释放未消费凭据。
- `context:Invoke(prepared,reply)`：返回 operation,error。面板关闭撤 UI 监听，已提交操作仍受 Provider 生命周期和5秒期限约束；其确认成功可记录当前角色历史。
- `context:BeginEdit(actionID,target,options)`：返回 edit,error。options 为 `{mode="single"|"latest",interval=0..1,onState=function(state) end}`；默认 single，latest 要求动作声明 `absolute=true`。
- `context:Observe(target,publish)`：订阅当前挂载；关闭、替换、停用撤订阅，旧 publish 返回 false。Provider 的 `observe(target,{resources=scope},publish)` 返回取消函数或带 Cancel 的句柄。

观察值严格为 `{stateRevision=number|string,values=plainTable,correlation=number|string?}`，执行相同纯数据容量限制。它是 Provider 报告的当前状态，不是执行授权；外部写入与本次写入关联由 Provider 解释。

edit 提供 `Push(args)`、`Finish()`、`Cancel(reason)`、`GetState()`。状态包含 status、draft、lastApplied、pending、code；draft 与实际确认值分开。一次最多一个准备/执行和一个覆盖最新值的队列，首个值可立即提交，后续按 interval 节流。Finish 提交最新队列值并在最终确认后只记一次历史；Cancel 丢弃未提交值，撤准备并停止节流，已经提交的操作仍等待有界完成，其最后确认值可进入历史。关闭面板立即断开编辑 UI 回调。

同一 Provider、conflictKey（默认 actionID）和规范化稳定目标使用同一执行序列。SDK、搜索、历史和 ViewContext 的 Invoke 都会拒绝与活动编辑或在途提交重叠的调用，返回 OPERATION_BUSY；另一个非幂等动作声明相同 conflictKey 也不能绕过。只有编辑会话自身的内部提交可以进入该会话已占用的序列，公开调用者不能传入伪造授权。

非幂等动作禁止 latest；任何入口已提交的结果不可判定时返回 indeterminate，保留有界冲突记录并以 OPERATION_UNCERTAIN 阻止重试，避免迟到旧值覆盖新值。取消函数尚未返回确认前，重入提交同样被锁阻止。当前冲突恢复以 Provider 实例/启用生命周期结束为界，没有自动业务状态对账、撤销或重放接口。全 Host 最多64个编辑会话；在途 Invoke 与不可判定记录合计最多64条，在提交前预留可能的不确定记录位置。仍使用原有 Resources 额度，不提高任务预算。

## 有界句式

```lua
local parsed = Lychee.SDK.Invocation:ParsePatterns(request.raw, {
  {"volume ", {slot="percent"}, "%"},
  {"音量", {slot="percent"}, "%"},
  {"音量百分之", {slot="percent"}},
}, {percent={type="integer",min=0,max=100,required=true}}, request.rawOffset)
```

patterns 最多32条，每条最多32片段，整个声明仍受深度6、256节点、16 KiB与字符串1024字节限制。片段为非空字面字符串或严格 `{slot="参数名"}`；相邻槽、重复槽、未知 schema 槽均拒绝。不使用正则、自动分词、目标枚举或回溯。字面词按字节和大小写精确匹配；需要本地化时由 Provider 按 i18n 选择声明。槽以其后的第一个字面分隔符终止，因此带分隔符的自由字符串需由 Provider 使用自己的明确语法。

返回 `{status,raw,args?,spans?,rawOffset?,originalSpans?,code?,field?}`。status 为 notMatched、incomplete、invalid、ambiguous 或 ready；原文必须从头到尾匹配。spans 保存参数在本次 raw 的 UTF-8 字节位置，start 从1开始，finish 为包含在内的末字节；空槽使用 finish=start-1。数字原文先保留再交 NormalizeArgs。负数、精度错误等返回 invalid，不夹取或默认；多个句式得到不同完整参数时返回 ambiguous。未匹配的句式不产生执行候选。此工具只解析纯数据，不加载 Provider、不调用动作；业务目标解析仍归 Provider。

可选 rawOffset 是0起始的 UTF-8 字节偏移，必须为0..1024整数且 rawOffset+#raw<=1024。提供它时，返回同值 rawOffset，并为已有 spans 添加 originalSpans：每个 start/finish 均加上偏移；ready、invalid 和 incomplete 都保留位置。省略时返回形状与原有 raw 相对位置兼容。Query request 提供 originalRaw，并且只有精确满足 originalRaw:sub(rawOffset+1)==raw 时才公开 rawOffset；不能从 normalized 或字符数反推。解析工具只校验偏移数值和容量，不自行验证调用者持有的 originalRaw。

例如 `originalRaw="  装备：音量-1%"` 路由后 `raw="音量-1%"`，将 request.rawOffset 传入后，`originalRaw:sub(parsed.originalSpans.percent.start,parsed.originalSpans.percent.finish)` 仍为 `-1`。Provider 可以把出错字段对应的 originalSpans 值放入 Entry.invocationError.span。Palette 主提交遇到带 span 的错误会保持不可执行，聚焦并选中出错原文；空 span 只定位插入点。消费前后都核对行身份、会话、代次和完整输入，拒绝超过当前文本或拆分 UTF-8 字符的位置。无 span 时保留错误提示，不猜测位置；明确的补参面板动作仍可使用。

原生位置依据：wowdoc `wow-ui-source` / `retail`，requestedRef 与 matchedTag 均为 `12.1.0`，resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:435–443` 声明 `HighlightText(start,stop)`，默认 start=0；`Interface/AddOns/Blizzard_AutoComplete/AutoComplete.lua:409–410` 以 `strlen(editBoxText), strlen(newText)` 调用高亮，再以 `strlen(editBoxText)` 设置光标。因此闭区间 span 转为 `HighlightText(start-1,finish)` 与 `SetCursorPosition(start-1)`，不转换为字符数量。离线测试 `tests/ui/invocation_input.lua` 覆盖真实查询结果提交、中文/ASCII、空槽与过期/重入输入；尚未替代实机输入法与选区绘制验收。

当前不提供通用 NLP、自动参数表单、动作/目标数据版本迁移或通用冲突对账。Provider 可使用句式工具，也可自行做有界、完整匹配的业务解析和本地化面板。业务词表和句式由接入方自己的功能语言文件维护，不向 Host 注册全局业务语法，也不借用 Host 的 UI 词典。显示语言与允许的输入语言由 Provider 分别声明。

自带音量功能就是 Player 子插件中暴雪设置 Provider 的动作分支：`Audio/Language.lua` 保存通道同义词、绝对设置动词和百分比单位，`Audio/Provider.lua` 将完整输入解析成该 Provider 的 `set-volume` Invocation。它不是独立的 Audio Provider；第三方可按同样边界组织自己的实现，无需使用这些项目内部路径或模块。新增句式须验证完整匹配、否定/相对意图、多目标、多数值及解析无副作用。保存的 title 是显示回退，不构成实时语言格式化协议。

离线验证：`lua tests/sdk/invocations.lua` 和 `lua tests/sdk/invocation_flow.lua`。前者覆盖公开注册、数据隔离、十进制和列表语义、伪造/重复凭据、动态能力、目标替换、搜索关闭、同步/异步/超时/取消、注销重注册、跨角色和取消回调重入；后者覆盖真实 query→执行→历史/收藏→恢复、缺参面板、目标面板、观察释放和连续编辑。离线逻辑通过不替代真实游戏业务、战斗和控件验收。
