# 通用斜杠命令归属修复

基线 422084d；版本 0.2.6。移除 /rs、ACECONSOLE_RS 与 RurutiaSuite 的专项映射和专用翻译，所有名称/Logo 都从来源插件 TOC 获取。

## 复现与来源

`lua tests/providers/slash_commands.lua` 在新增任意插件名用例上先失败：`arbitrary command must use registering addon logo`。原实现只识别 /rs。

lychee-dev 只读 Ticket `LYCHEE-20260920-113004-0034`（retail 12.1.0.69875、zhCN，397 个导入命令）证实 issecurevariable 可读取来源，但 /rs 的注册表/代理/hash/别名字段均显示 HandyNotes，原因是它首次加载共享 AceConsole 库；/dev、/eui、/bw 则分别为其实际插件。debug.getinfo 不可用。报告完整校验 71575 字节，SHA-256 a256b1466a845041532a2de0b6fbc2d95bab37e1c0cc176ce01b50b366e81189；ACK confirmed/cleared，临时任务已移除。

原始报告保存在本机 LycheeDev automation received/Ticket/content.json。精简样本：

```json
[
  {
    "hash": {
      "owner": "EllesmereUI",
      "secure": false
    },
    "key": "EUIOPTIONS",
    "list": {
      "owner": "EllesmereUI",
      "secure": false
    },
    "aliasField": {
      "owner": "EllesmereUI",
      "secure": false
    },
    "alias": "/EUI",
    "proxy": {
      "owner": "EllesmereUI",
      "secure": false
    }
  },
  {
    "hash": {
      "owner": "Lychee Dev",
      "secure": false
    },
    "key": "LYCHEEDEV",
    "list": {
      "owner": "Lychee Dev",
      "secure": false
    },
    "aliasField": {
      "owner": "Lychee Dev",
      "secure": false
    },
    "alias": "/DEV",
    "proxy": {
      "owner": "Lychee Dev",
      "secure": false
    }
  },
  {
    "hash": {
      "owner": "BigWigs",
      "secure": false
    },
    "key": "BigWigs",
    "list": {
      "owner": "BigWigs",
      "secure": false
    },
    "aliasField": {
      "owner": "BigWigs",
      "secure": false
    },
    "alias": "/BW",
    "proxy": {
      "owner": "BigWigs",
      "secure": false
    }
  },
  {
    "hash": {
      "owner": "HandyNotes",
      "secure": false
    },
    "key": "ACECONSOLE_RS",
    "list": {
      "owner": "HandyNotes",
      "secure": false
    },
    "aliasField": {
      "owner": "HandyNotes",
      "secure": false
    },
    "alias": "/RS",
    "proxy": {
      "owner": "HandyNotes",
      "secure": false
    }
  }
]
```

wowdoc：wow-ui-source / retail / 12.1.0 resolvedCommit 4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，Blizzard_Dispatcher/Blizzard_Dispatcher.lua:260 使用 `hooksecurefunc(functionOwner, functionName, ...)`；AddOnsDocumentation.lua:165–178 定义 C_AddOns.GetAddOnMetadata。issecurevariable 未被当前 wowdoc 索引收录，因此采用实际客户端探针验证、运行时能力检测和离线缺失 API 回归，不声称其他客户端已实测此 API。

本机 RurutiaSuite 的 AceConsole-3.0.lua:81–113：RegisterChatCommand 用调用者 self 和字符串方法创建闭包，字段标识为 ACECONSOLE_ 加命令；UnregisterChatCommand 清理普通/哈希/别名。AceAddon-3.0.lua:119、129 保存 object.name 与 addons[name]。这些是共享库协议，不是命令到插件的映射。

## 实现与成本

普通注册只读客户端来源；共享库使用注册时的调用对象，优先处理方法字段来源，再尝试可通过 TOC 验证的 AceAddon 名称。库最初加载者不作为未捕获 AceConsole 命令的归属。覆盖旧嵌入方法引用与后续 Embed；不写注册表，不扫描全局变量，不新增 Frame/事件/轮询。预算和生命周期见 [PERFORMANCE 第18节](../../../PERFORMANCE.md#18-斜杠命令来源)。

归属使用弱函数引用，替换后旧 Logo 不可复用；注销删除，整体注销清空，停用的不可卸载 hook 立即短路。来源/Logo 缺失时显示原命令与通用图标。共享库命令若在观察安装前已经注册，且没有再次注册，则不猜归属；不能承诺所有库、所有历史注册均可追溯。

## 验证

完整契约检查通过；四客户端四语言回归通过，新增错误共享库来源、任意命令、旧嵌入、新注册、注销、替换、缺失 API、恢复、无重复 hook 用例。千命令20查询约分配3.5 MiB，保留约41 KiB，单批1–2ms，未增加空闲Frame。四 TOC wowdoc valid=true，Lua、生成清单、SDK及交付检查通过。

实机修复后的功能与性能结果待本次提交同步、重载后补充。只读诊断不能代替动作验收；其他客户端、其他语言、物理鼠标点击、战斗/taint和团本帧时间保持待验收。
