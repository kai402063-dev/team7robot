# 先约定“这个数代表什么”

## 问题：同样是 x=1，为什么机器人走反了？

本项目统一 SI 单位：位置 m、时间 s、线速度 m/s、角速度 rad/s、角度 rad。场地原点在场心，x 沿 9 m 场长，y 沿 6 m 场宽，team 1 蓝队攻 +x。车体 x 向前、y 向左，角度从场地 +x 起逆时针为正。车体速度 `[vx vy]` 转场地速度使用旋转矩阵：

```text
vx_world = cos(theta)*vx - sin(theta)*vy
vy_world = sin(theta)*vx + cos(theta)*vy
```

例如 theta=pi/2、车体请求 `[0.25 0]`，机器人向场地 +y 走。team 2 攻 -x，但不翻转整个世界坐标。目标点始终是场地坐标；请求的 velocity 始终是车体坐标。不能把 ROS 的角度制数值直接送入 rad 字段。

共享总线字段的实际类型和尺寸由 `interfaces/tdpTemplates.m` 定义，由 `scripts/build_types.m` 生成 `models/TdpTypes.sldd`（Simulink 数据字典，即保存模型共享类型的文件）。完整字段表自动导出到 [interfaces.md](../generated/interfaces.md) 和 JSON；以下给出逐字段的物理含义。数值字段无特别说明均为 double，布尔为 logical，枚举类型见下表。V1 的每队独立记忆由 `tdp.v1TeamMemory()` 定义，`build_v1_match` 据此生成 `TdpV1Types.sldd` 中的 `V1TeamBus`。所有机器人/请求/反馈数组是 **1×8 行数组**，团队计划是 **1×4**；8×1 不能当作相同总线尺寸。

## 物理与观测总线

| 总线 | 字段及尺寸 | 单位、坐标与有效性 |
|---|---|---|
| RobotBus | team、num 各 1×1；isGK 布尔；role 枚举 | team=1/2，num=1…4；门将身份固定，role 为当前战术角色 |
| RobotBus | x、y、th 各标量 | 场地 m、m、rad；角度规范化到 [-pi,pi) |
| RobotBus | vxw、vyw、cool 各标量 | 场地速度 m/s；剩余踢球冷却 s |
| BallBus | x、y、vx、vy 各标量 | 场地位置 m、速度 m/s；可见性在 Observation 中，不用特殊坐标表示失效 |
| RefereeBus | t 标量；score 1×2；lastTouch 标量 | 仿真 s；两队进球数；最后触球队 0/1/2，0 仅表示尚无触球，是分类值而非失效坐标 |
| RefereeBus | pauseUntil、msgUntil 标量；msg 枚举 | s；裁判事件；暂停到期时间与显示到期时间分别保存 |
| RefereeBus | shots、touchTime 各 1×2 | 射门计数；最后触球队累计时间 s，**不是控球率** |
| ObservationBus | selfIndex 标量；robots 1×8 RobotBus | 全场槽位编号 1…8；机器人测量，可为理想观测或经过传感适配 |
| ObservationBus | robotValid 1×8 布尔；robotStamp 1×8 | 每台测量的有效性与采集时刻 s；未观测槽位不能参与几何判断 |
| ObservationBus | ball 标量 BallBus；ballValid 布尔；ballStamp 标量 | 球测量、有效性、采集时刻 s |
| ObservationBus | selfValid、gameRunning、allowKick 布尔；tSim 标量 | 自身定位可用、裁判允许运行、二维仲裁允许踢球、当前输入仿真时刻 s |

`robotValid=true` 还不够。Core 检查时刻有限、不是未来、年龄不超过 maxObservationAge。默认 0.5 s，采集时刻 1.00 s 在 tSim=1.50 s 仍有效，1.55 s 失效。样本失效时保留数值也可以，但算法必须先检查标志。`NaN` 不作为日常“看不见球”的编码；未知课程参数也不能用 0 替代。

Observation2D 是唯一从世界状态创建测量的入口。理想观测不等于真实传感器验证。有限视野只约束球的方位，尚不包括遮挡、识别误差或三维相机投影。团队仍使用集中式全场观测，此配置是否符合课程自主性要求待导师确认。

## 意图、请求与反馈

| 总线 | 字段 | 语义 |
|---|---|---|
| IntentBus | type 枚举；target 1×2；heading；speed；role | 团队建议动作；场地目标 m；场地目标朝向 rad；踢球目标速度 m/s；角色。不是电机命令 |
| RequestBus | requestId uint32 标量 | 一次动作的身份；0 保留为未发出；基线比赛不会接近溢出，跨进程重启需建立新的会话 |
| RequestBus | kind 枚举；velocity 1×3 | 动作种类；车体 `[vx,vy,w]`，单位 m/s、m/s、rad/s |
| RequestBus | target 1×2；speed | 踢球方向的场地目标 m；二维目标球速 m/s，三维动作层不能把它当作已标定的出球速度 |
| RequestBus | stamp；validUntil | 发出时刻、最后允许接收时刻 s；闭区间有效 |
| FeedbackBus | requestId uint32；status 枚举；stamp | 与请求同一编号；执行状态；产生反馈的仿真时刻 s |

重复 Kick 编号只返回已保存的状态。新编号在执行器忙碌时被 Rejected，旧编号不能重新进入。控制器只接受与 kick requestId 相同的结束反馈，迟到反馈被忽略。行走是有期限的连续请求，接收过期请求时速度为零。发送 Stop 会取消正在准备的二维动作并记录 Failed；这与运动文件能否在三维中安全中断是不同问题。

## 内部总线

| 总线 | 字段 | 含义 |
|---|---|---|
| GeometryBus | command 1×3、target 1×2、speed、distance | 车体速度、场地目标、踢球速度、到球距离 m |
| GeometryBus | ready、safe、ballVisible、running；intent | 四个布尔条件及动作枚举；safe 是自身观测有效，不是机器人硬件安全认证 |
| ActuatorBus | seenId、rejectedId、executions uint32 | 已接受/拒绝编号高水位；接受动作次数，失败尝试也计数 |
| ActuatorBus | active 布尔；start；target 1×2；speed；feedback | 进行中、起始 s、锁定参数、最近反馈 |
| WorldBus | robots 1×8；ball；referee；actuator 1×8 | 环境所有的真值、裁判与执行状态 |
| WorldBus | active 1×8 布尔；lastCommands 8×3；lastKick；kickCount uint32 | 单机实验启用槽位；当步限速前命令；当步是否踢出；累计踢出次数 |

## 枚举

枚举用名字表达离散含义，避免字符串拼写和不同长度；数值仅用于日志和标准 ROS 消息的明确编码。

| 类型 | 成员（数值） |
|---|---|
| TdpRole | Unknown(0), GK(1), ST(2), DF(3), SP(4), MF(5) |
| TdpAction | Stop(0), Goto(1), Kick(2), Search(3), Tap(4) |
| TdpStatus | None(0), Running(1), Done(2), Failed(3), Rejected(4) |
| TdpPhase | Idle(0), Search(1), Approach(2), Align(3), Kick(4), Recover(5) |
| TdpTeamPhase | Hold(0), Defend(1), Attack(2), Search(3), Fallback(4) |
| TdpEvent | None(0), Kickoff(1), GoalBlue(2), GoalRed(3), GoalKick(4), Corner(5), KickIn(6) |
| TdpMode | Compat(0), Delayed(1) |
| TdpRules | ACompat(0), CourseSimplified(1), ReferenceRestarts(2) |

V1 每队本地 1–4 号按 GK、DF、MF、ST 排列，角色枚举值依次为 1、3、5、2。MF 临时接管进攻时仍记录为 MF。TdpPhase 记录各机器人个人的技能阶段，TdpTeamPhase 记录球队这一拍的战术状态。[V1 参数与团队记忆](../generated/v1_contracts.md)

比赛物理轨迹为 98 列。在旧 ACompat 中，第 71、72 列分别记录蓝、红队当前的本地前锋编号。在 V1 中，这两列分别记录本队获得追球授权的本地编号，0 表示无人。V1 的独立 171 列战术记录使用全局机器人编号，chaser 第 6、7 列按蓝、红队排列，7 号表示红队本地 3 号。用 `v1TraceColumns()` 取得每个字段的实际列号。[完整列定义与接线](v1_model_interface.md) · [运行和排错步骤](tactics_v1_design.md)

手动增加字段时，应先改模板和字段说明，再改生产者/消费者，再运行 build_types 和全部建模脚本。不要只在一个 MATLAB Function 内临时追加结构体字段。若报 bus element mismatch，先核对字段顺序、枚举类型和 1×8 方向，再查数值。
