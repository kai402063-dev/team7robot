# V1 运行配置、团队记忆与记录列

由 `scripts/export_v1_contracts.m` 从当前工程生成。类型、尺寸、默认值和列号均取自可执行定义。

## 启用 V1 时增加或覆盖的参数

完整实际配置见 [v1_config.json](v1_config.json)。其余继承字段的单位及出处见[基线参数表](parameters.md)。

| 参数 | 类型 | 尺寸 | 默认值 | 单位 | 来源和用途 |
|---|---|---|---|---|---|
| v1Enabled | logical | [1 1] | true | 开关 | 实施选择。启用八机器人 V1 比赛模型 |
| mode | TdpMode | [1 1] | Delayed | 枚举 | 实施选择。Delayed 接入技能阶段、搜索转动和关联反馈 |
| rulesProfile | TdpRules | [1 1] | CourseSimplified | 枚举 | 教学规则。默认 CourseSimplified，规则配置与战术配置分开 |
| freezeDuringPause | logical | [1 1] | true | 开关 | 配置覆盖。Delayed 执行器和授权层遇停赛均阻止运动 |
| v1MidlineBand | double | [1 1] | 0.15 | m | 教学设定。半场切换死区的半宽，边界相等时保留原相位 |
| v1SupportTrail | double | [1 1] | 0.7 | m | 教学设定。进攻 MF 支援点相对 ST 的后移量 |
| v1SupportWidth | double | [1 1] | 0.8 | m | 教学设定。左右候选支援点及 ST 反击接应点的侧移量 |
| v1LooseRange | double | [1 1] | 1.2 | m | 教学设定。防守时 MF 可以争自由球的最大距离 |
| v1LooseSpeed | double | [1 1] | 0.35 | m/s | 教学设定。自由球允许的最大速度模长 |
| v1OpponentClearance | double | [1 1] | 0.6 | m | 教学设定。判自由球时每个已确认对手距球须严格大于此值 |
| v1KeeperInset | double | [1 1] | 0.35 | m | 教学设定。GK 站位离己方球门线向场内的距离 |
| v1ScreenDepth | double | [1 1] | 1.4 | m | 教学设定。MF 中央防守目标距中线向本方的距离 |
| v1CounterDepth | double | [1 1] | 0.4 | m | 教学设定。ST 反击接应及 MF 未知球保持点距中线向本方的距离 |
| v1UnavailableWindow | double | [8 2] | [0 0;0 0;0 0;0 0;0 0;0 0;0 0;0 0] | s | 定向测试。每个机器人一行，不可用时 Poses 无效，身体仍在场 |
| v1BlindWindow | double | [8 2] | [0 0;0 0;0 0;0 0;0 0;0 0;0 0;0 0] | s | 定向测试。每个机器人一行，令本机球观测无效 |
| v1StaleWindow | double | [8 2] | [0 0;0 0;0 0;0 0;0 0;0 0;0 0;0 0] | s | 定向测试。每个机器人一行，球采集时刻设为超过最大年龄 |
| v1StopWindow | double | [1 2] | [0 0] | s | 定向测试。全场一行，撤去比赛运行许可 |
| v1RecoveryWindow | double | [2 2] | [0 0;0 0] | s | 定向测试。每队一行，向协调器给出显式 ST 恢复信号 |
| v1FailWindow | double | [8 2] | [0 0;0 0;0 0;0 0;0 0;0 0;0 0;0 0] | s | 定向测试。每个机器人一行，该窗内准备完成的踢球执行强制失败 |

时间窗每行是起始和结束秒数，包含起点，不包含终点。两个端点相同表示禁用。8 行按全局机器人 1–8 排列，2 行按蓝队、红队排列。

## V1TeamBus 初值

每队持有一份标量结构，每拍用一个 Unit Delay 保存。

| 字段 | 类型 | 初值 | 单位与含义 |
|---|---|---|---|
| basePhase | TdpTeamPhase | Attack | 团队枚举。最近有效观测确认的基础攻防，初次中线自由开球为 Attack |
| phase | TdpTeamPhase | Attack | 团队枚举。本拍对外显示的模式 |
| chaser | double | 0 | 全局机器人号 1–8，0 表示本队无人获准追球 |
| failed | logical | false | 布尔。本队 ST 的匹配执行失败已锁存 |
| recovering | logical | false | 布尔。正在等待 MF 旧动作终态，暂缓交还 |
| releaseId | uint32 | 0 | 请求号。待结束的 MF 动作，0 表示当前无等待 |
| handledFailureId | uint32 | 0 | 请求号。最后一次已处理的 ST 失败，用于去重 |
| ballKnown | logical | false | 布尔。本队本拍选到了有效且新鲜的球观测 |
| ballSource | double | 0 | 全局机器人号。提供所选观测的队员，0 表示无来源 |
| takeover | logical | false | 布尔。MF 临时责任已锁存，球未知时仍保存 |
| releaseStamp | double | 0 | s。发起本次 MF 撤权的仿真时刻，过滤过早的终态反馈 |

## tacticsRecords 的列号

所有列存为 double。双列按蓝队、红队顺序；八列按全局机器人 1–8 顺序。布尔量以 0/1 保存。

| 字段 | 列号 | 单位或枚举 | 信号含义 |
|---|---|---|---|
| time | 1 | s | 本拍 tSim |
| phase | 2–3 | TdpTeamPhase | 两队对外模式 |
| basePhase | 4–5 | TdpTeamPhase | 两队基础攻防相位 |
| chaser | 6–7 | 全局号 | 两队本拍追球授权人，0 表示无人 |
| ballKnown | 8–9 | 布尔 | 两队是否有可用球观测 |
| ballSource | 10–11 | 全局号 | 两队选中的观测源，0 表示无来源 |
| failed | 12–13 | 布尔 | 两队 ST 匹配失败锁存 |
| running | 14 | 布尔 | 裁判与场景给出的本拍比赛许可 |
| kicker | 15 | 全局号 | 环境在本拍确实踢球的机器人，0 表示无人 |
| available | 16–23 | 布尔 | 个人可用且定位有效、新鲜 |
| ballFresh | 24–31 | 布尔 | 个人球观测有效、新鲜 |
| intent | 32–39 | TdpAction | 队级计划动作类型 |
| rawKind | 40–47 | TdpAction | 各个人 Core 的原始请求类型 |
| kind | 48–55 | TdpAction | 授权层实际交给执行器的请求类型 |
| requestId | 56–63 | 请求号 | 有效请求编号，须与机器人号一同匹配 |
| status | 64–71 | TdpStatus | 执行器返回的反馈状态 |
| feedbackId | 72–79 | 请求号 | 执行器反馈关联的请求编号 |
| skill | 80–87 | TdpPhase | 个人 Stateflow 技能阶段 |
| targetX | 88–95 | m | 队级意图的场地目标 x，按 intent 区分站位或踢球方向目标 |
| targetY | 96–103 | m | 队级意图的场地目标 y |
| ballAge | 104–111 | s | 本拍 tSim 减去本机球采集时刻，与 ballFresh 一起解释 |
| rawId | 112–119 | 请求号 | 授权前 Core 请求编号 |
| executions | 120–127 | 次 | 执行器累计接受的踢球动作次数，包含随后失败/取消的尝试 |
| feedbackStamp | 128–135 | s | 本次记录的反馈采集时刻，反馈可保持上一状态 |
| validUntil | 136–143 | s | 实际请求的最后有效时刻 |
| stamp | 144–151 | s | 实际请求的发出时刻 |
| rawSpeed | 152–159 | m/s | 原始请求所带的踢球目标速度 |
| speed | 160–167 | m/s | 实际请求所带的踢球目标速度 |
| takeover | 168–169 | 布尔 | 两队当前是否锁存 MF 临时责任 |
| recovering | 170–171 | 布尔 | 两队是否正在取消 MF 旧动作并等待交还 |

## 中线五拍回放

输入按既定顺序送入当前协调器。这里的结果是函数回放，整场比赛另行验收。红队输入 x 取反。

| tSim (s) | 蓝队输入 x (m) | 蓝队输出 | 红队镜像输出 |
|---:|---:|---|---|
| 1.00 | -0.20 | Defend | Defend |
| 1.05 | 0.04 | Defend | Defend |
| 1.10 | 0.16 | Attack | Attack |
| 1.15 | -0.10 | Attack | Attack |
| 1.20 | -0.16 | Defend | Defend |
