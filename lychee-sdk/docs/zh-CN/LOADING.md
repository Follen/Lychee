# 独立插件的发现、加载与准备

[目录](README.md) · [English](../en/LOADING.md)

SDK / Provider API 1.0.0。冷声明让 Host 在业务 Lua 尚未运行前选中已安装 Provider。注册、SavedVariables 就绪、可选准备和业务执行是不同阶段；已加载且没有冷声明的 Provider 继续走普通注册。

## 可运行示例

[ColdProvider](../../examples/ColdProvider/README.md) 是完整独立 AddOn，包含 fallback/Mainline TOC、自己的存档和公开 SDK 注册。将整个目录复制为 `Interface/AddOns/ColdProvider`。`cold:` 前缀和 `coldexample` 快捷词触发加载，默认不参与普通搜索；仅声明 Retail 范围。修改示例时同时更新目录名、包名、Provider ID、路由和热注册。

TOC 的 X-Lychee-* 字段就是发现声明。Host 不为发现执行第三方 Lua manifest。完整源码中的 `tests/sdk/cold_example.lua` 使用原生加载替身；离线通过不替代客户端验证。

## 客户端与能力

```lua
local host = _G.Lychee
if not host or not host:Supports("1.0.0") then return end
local SDK = host.SDK
local client = SDK.GetClient()
if not SDK.SupportsFeature("discovery", 1) then return end
```

GetClient 返回独立 `{product,interface,build,locale}` 快照；product 为 retail/classic/titan/anniversary，interface/build 为数值。修改快照不改变 Host、不加载包、不探测任意全局变量。支持仍需对应原生 TOC 和经过验证的版本范围。

GetClient 和 SupportsFeature 支持 SDK 点/冒号及 host 冒号调用。能力版本默认1；当前名称为 client-context、discovery、provider-readiness、preparation、invocation、search-documents、compact-storage、query-failure。未知名称或版本返回false；可选服务仅在对应实现可用时报告支持。SDK.Now() 使用 Host 截止时间的同一单调时钟。

## 静态 TOC 声明

每个独立加载包拥有自己的 TOC、依赖、SV 和媒体。一个包可声明多个 Provider：

```toc
## Interface: 120100
## Title: Example
## Dependencies: Lychee
## LoadOnDemand: 1
## SavedVariables: Example_LycheeDB
## X-Lychee-Protocol: 1
## X-Lychee-Package: Example_Lychee
## X-Lychee-Providers: example.gear,example.status
## X-Lychee-Provider-example.gear: title=Equipment;title.zhCN=%E8%A3%85%E5%A4%87;global=0;prefixes=gear;keywords=equipment;ranges=retail:120100:120199:1:9999999;icon=addon:Media/equipment.tga;requires=Lychee
## X-Lychee-Provider-example.status: title=Status;global=0;prefixes=status;ranges=retail:120100:120199:1:9999999;icon=file:134400;requires=Lychee
Provider.lua
```

X-Lychee-Package 必须等于真实目录名。Provider ID 以小写字母/数字开头，仅含小写字母、数字、点和短横线；Providers 为有序逗号列表，每个 ID 恰有一条 Provider 行。

行内字段以分号分隔，格式 key=value；未知或重复键拒绝。列表先分隔再解码。保留标量字节用大写 %HH 转义，包括百分号%25、分号%3B、等号%3D、逗号%2C。允许有效 UTF-8 原文；非法 UTF-8、控制字符、坏转义、未转义的标量逗号拒绝。不计算 Lua 表达式。

| 字段 | 含义 |
| --- | --- |
| title | 必填英文回退标题 |
| title.enGB / title.zhCN / title.zhTW | 可选本地化标题 |
| description 及相同语言后缀 | 可选本地化说明 |
| global | 必填0或1，是否默认参加普通搜索 |
| prefixes / keywords | 可选逗号分隔路由或精确快捷词 |
| ranges | 必填 product:minInterface:maxInterface:minBuild:maxBuild 列表，整数闭区间；同产品重叠矩形拒绝 |
| icon | addon:相对路径、file:正整数fileID 或 atlas:名称 |
| requires / optional | 原生包名列表；必需依赖须安装且启用，原生 TOC 规则继续生效 |
| purpose | 可选简短用途说明 |

global=0 时至少保留一个前缀或快捷词。不支持的产品/范围不会被选中。ID 或路由冲突使双方声明无效，不以枚举顺序选赢家。坏声明关闭接入，其已知 ID 也不能绕过声明通过普通路径注册。

标题/说明按精确语言→语言家族（中文zhCN，其他enUS）→英文回退。解析限制 Provider 数、行长、字段、词项、依赖和范围，扫描按需分批；扫描结束前不会加载。具体性能规则见[性能规范](PERFORMANCE.md)。

第三方在自己的构建系统维护这些元数据及经过验证的 TOC 后缀、Interface、依赖和文件顺序，不依赖 Lychee 内部清单/生成器。必须在每个声称支持的客户端验证真实冷加载。

## 热注册与资源

加载后声明 addon 为真实包名。标题、已声明的说明、路由和资源必须与冷声明一致。当前产品 scope 可缩小冷范围，但必须包含当前客户端，不能扩大范围或省略/更换包名。

先等待 host:RegisterReady，再等待 SDK.WhenSavedVariablesReady(addon,callback)，然后用普通 RegisterProvider 提交。二者都可能同步完成。同包的各 Provider 独立注册，等待一个入口不要求无关兄弟入口也注册成功。完整代码见 ColdProvider。

资源形状为 `{kind="addon",path="Media/equipment.tga"}`、`{kind="file",id=134400}` 或 `{kind="atlas",name="atlasName"}`。addon路径相对所属包，使用正斜线，禁止目录穿越、绝对路径或跨包资源。另给的 icon 必须等于解析后的纹理值。媒体随所属包交付，存储见[Storage](STORAGE.md)。

## 加载与就绪

Host 根据路由和用户偏好选中 Provider，再按包合并需求；在原生加载前挂等待者，等本包 SV 就绪并观察注册成功。不会自动启用原生禁用包。依赖缺失/禁用、声明非法、加载失败或未注册都产生终结失败。

发现、加载、存档、准备和查询共享从请求开始的绝对截止时间。新等待者不会延长旧等待者的期限。取消只移除当前订阅者，其他订阅者可以继续共享工作。同步 LoadAddOn 无法抢占，取消也不卸载已经加载的 Lua。

发现与加载器是 Host 内部实现，不是 Provider 目录 API。注册使用 RegisterReady 和 WhenSavedVariablesReady；后者返回可取消句柄，存档已经就绪时可同步回调。

## Provider 准备

可选 `prepare(context,reply)` 只准备本包数据，不发布搜索结果、不执行业务动作。同步返回 `{status="ready"}` 或 `{status="failed",code="原因"}`；异步返回取消函数后回复一次，也允许返回nil后异步回复。异常和非法返回失败。

context 包含 product、interface、数字build、locale、publicscope、deadline、resources。publicscope 常见为 search/restore；resources 是 Provider 的子作用域，完成/取消/停用/版本失效后关闭。成功只在 Host 留下有界就绪凭据，实际可复用数据和失效规则仍归 Provider。

同实例、数据代次、语言、scope 的工作可共享。各订阅者各有绝对期限，context.deadline 反映仍存活订阅者的最晚期限，不允许延长其他订阅者。未声明 prepare 同步就绪，不创建准备 timer。

已注册来源可使用：

```lua
local token, err = SDK.Preparation:Ensure(
    {"example.gear"}, {scope="search",intent="query"}, SDK.Now()+5,
    function(result)
        if result.ready["example.gear"] then
            -- 数据已准备好；这里不包含搜索结果。
        else
            local reason = result.failed["example.gear"]
        end
    end)
-- 不再需要时 token:Cancel()
```

请求 context 只含可选 scope/intent；校验 Provider数组、期限、回调和结果，拒绝元表、secret/不可访问值、未知结果字段。Provider准备结果只含status和可选≤96字节code。终态回调可能同步；取消订阅不回调。非法参数或耗尽额度返回nil,Error；接受请求后，逐来源错误在result.failed，包括 PROVIDER_UNAVAILABLE、SEARCH_DISABLED、RESOURCE_LIMIT、PREPARATION_TIMEOUT、INVALID_PREPARATION、PREPARATION_ERROR、STALE_PREPARATION。此服务不发现或加载冷包。intent 为 query/visible/prewarm；visible 明确引用恢复不被搜索关闭阻止。

## 可见恢复与设置

打开首页只恢复视口实际可见的固定/最近引用，滚动/展开形成新需求。各来源在同一视口期限内独立加载、准备、恢复，慢来源不阻塞已就绪来源，也不绕过准备。当前查询逐步发布可用结果；之后可低优先准备已加载且参加搜索的来源，真实查询可以加入并优先处理。关闭撤去未完成订阅；业务后台/独立页面按自己的生命周期运行。具体动作使用[Invocation](INVOCATIONS.md)。

可见引用暂不可用时呈只读状态；Host 仅保留有界标量分类：等待、包禁用、Provider缺失、目标删除、版本不符、超时、依赖不可用、临时不可用、其他失败。保留原引用和显示回退，不保留任意业务错误载荷或直接将其显示。视口不变不自动重试终结失败，重开或新可见需求可重试；关闭/换会话清临时状态，整个恢复沿用原期限。

来源设置页可仅读取冷元数据，不执行业务 Lua，允许编辑该角色的参与搜索和路由，注册后仍以用户选择为准。冷声明没有运行时版本；注册使已打开的声明编辑器失效，旧点击不能修改新实例。隐藏取消发现订阅。排除搜索不停止业务生命周期或阻断明确引用。
