# V1 比赛模型与动作交接

要查“谁让中场上去踢球”，先打开一场运行的两份记录。物理记录 `records` 描述机器人、球、比分。战术记录 `tacticsRecords` 把同一拍的队级决定、个人技能请求、最后放行的动作和执行反馈对齐。两表都是每个控制周期一行，可按同一行号联查。

## 从观察到踢球的一拍

1. 上一步结束后，`WorldMemory` 保存环境状态，`FeedbackMemory` 保存执行器反馈，`RequestMemory` 保存实际放行的请求。两队各自的 `Team1Memory` 和 `Team2Memory` 保存攻防相位、追球授权及故障交接状态。五处 Unit Delay（单步延迟）把这些量留到下一拍读取。
2. `V1Observation2D` 向每个机器人生成一份限时观测。若无有效球位置或观测已经过期，适配器将位置载荷设为本机位置、球速设为零，并保留有效性和采集时刻。个人几何模块此时得到零距离；队级和个人控制都须用标志及年龄决定能否使用这份载荷。
3. 每队的 `tdp.v1TeamPlans` 比较四份本队观测，处理上一拍已授权的请求及其执行反馈，输出本队四个固定角色的意图和本拍追球者。每台机器人有独立的 `ControllerCore/Core` 库实例。它根据意图与本机观测输出一个原始请求。
4. `V1AuthorizeRequests` 根据本拍决定检查八个原始请求。丢失授权、停赛、失球或过期时，准备中的踢球会被同编号 Stop 取消。队友的合法守位移动可以继续。只有这层的输出进入执行器和下一拍的请求记忆。
5. `V1Plant2D` 调用共享的二维物理模型。实际踢球事件在执行器完成准备且接触几何仍满足时生成。记录器在物理更新后取得执行反馈及实际踢球者。执行失败、停止取消和球因碰撞或规则重置产生的位移应分别解释。

从空白生成该模型用 `tdpSetup; build_v1_match`。脚本生成 `models/tdpV1Match.slx` 和 `models/TdpV1Types.sldd`，后者引用共享的 `TdpTypes.sldd` 与固定总线。基线以后改生成脚本和 MATLAB 源码，再重新生成并提交模型。可以在新输出目录运行 `python3 scripts/audit_v1_model.py build/v1-structure-check`，检查保存的八条库链接、五个延迟状态、关键连线和代数环诊断。[生成器](../../scripts/build_v1_match.m) · [共享接线](../../scripts/build_match.m)

## 怎样读战术记录

下面的列号从 1 起。原始数据是定宽 double 行向量，枚举和逻辑量先转为数值保存。两队列依次为蓝、红；每组八列依次对应全局机器人 1–8。所有位置在场心坐标系，单位为 m。所有时刻和时长单位为仿真秒。未授权或无事件用单独的编号 0 表示；观测新鲜性另有标志。实际索引可直接从 `c=v1TraceColumns()` 读取。[记录器](../../environment/V1TacticsRecord.m) · [列索引](../../scripts/v1TraceColumns.m)

| 列 | 字段 | 语义与使用条件 |
|---|---|---|
| 1 | time | 本拍 tSim，与物理记录第 61 列一致 |
| 2–3，4–5 | phase，basePhase | 本拍对外状态、记忆的基础攻防相位。枚举 Hold=0、Defend=1、Attack=2、Search=3、Fallback=4 |
| 6–7 | chaser | 全局追球者编号，每队一个编号，0 表示无人获准。本地追球者编号另在 V1 物理记录 71–72 列 |
| 8–9，10–11 | ballKnown，ballSource | 是否有已知队级球观测，以及提供该观测的全局编号；无源时为 0 |
| 12–13，168–169，170–171 | failed，takeover，recovering | 每队 ST 匹配失败锁存、MF 接管任务、交还时等待 MF 动作终态。每列是逻辑 0/1 |
| 14，15 | running，kicker | 本拍比赛许可；实际向球施加踢球速度的机器人全局编号，0 表示本拍没有踢球 |
| 16–23，24–31 | available，ballFresh | 本机具有新鲜有效位姿；本机具有新鲜有效球观测。均为独立逻辑 0/1 |
| 32–39，40–47，48–55 | intent，rawKind，kind | 团队意图、个人控制器原始请求、授权后实际请求。动作 Stop=0、Goto=1、Kick=2、Search=3、Tap=4 |
| 56–63，64–71，72–79 | requestId，status，feedbackId | 有效请求编号、本拍执行反馈状态与编号。编号在每个机器人内部匹配；状态 None=0、Running=1、Done=2、Failed=3、Rejected=4。空闲时反馈可能保留先前的终态，统计动作须按机器人及编号去重 |
| 80–87 | skill | 个人 Stateflow 的阶段 Idle=0、Search=1、Approach=2、Align=3、Kick=4、Recover=5 |
| 88–95，96–103 | targetX，targetY | 团队意图的全局 x/y 目标。Goto 指站位，Kick 指踢球瞄准点，Stop/Search 的占位坐标不作为目标 |
| 104–111 | ballAge | tSim 减去本机采集时刻，须结合 ballFresh 判读。年龄超限的坐标在传感器出口屏蔽 |
| 112–119，120–127 | rawId，executions | 个人原始请求编号；执行器累计接受的新踢球动作数，同编号重发不增加次数 |
| 128–135，136–143，144–151 | feedbackStamp，validUntil，stamp | 本拍反馈时刻、实际请求到期时刻、实际请求发出时刻；准备中的 Kick 保留原始发出时刻，取消的 Stop 用本拍时间 |
| 152–159，160–167 | rawSpeed，speed | 原始请求与授权后请求的踢球标称速度 (m/s)。并非机器人的平移速度；Stop 为零 |

固定身份在物理轨迹第 49–56 列，蓝红各自按 GK=1、DF=3、MF=5、ST=2 排列。对射门计数时看实际踢球者和授权请求速度，MF 接管时保留 MF 身份。[物理记录](../../environment/MatchRecord.m) · [角色枚举](../../interfaces/TdpRole.m)

## 手动复现准备中的交接

在 MATLAB 中执行 `tdpSetup; r=runtests('tests/test_v1_model.m'); assertSuccess(r);`。首先确认正常夹具中 ST 能进入 Kick，得到同编号的 Running，再按准备时间完成。测试从实际出现 Running 的下一拍起注入不可用、停赛、失球或过期，所以调整控制周期后仍针对同一技能阶段。成功的取消应看到旧编号 Stop 和匹配的 Failed，接管比赛中 MF 始终保留 MF 身份。查一次未取消的踢球时，先检查当前 chaser，再沿 rawKind、kind、status、kicker 同一行向下查。退回到个人图的 Kick 状态只说明请求曾存在，实际动作要看执行层。[模型测试](../../tests/test_v1_model.m) · [授权层](../../environment/V1AuthorizeRequests.m) · [动作执行](../../environment/Actuator2D.m) · [实测交接表](../generated/v1_model_events.md)

故障窗口均为仿真秒半开区间 [开始,结束)。相等的起止时刻关闭该窗口，每场正式比赛默认全部关闭。`v1UnavailableWindow`、`v1BlindWindow`、`v1StaleWindow` 与 `v1FailWindow` 各有八行，每台机器人对应一行。`v1StopWindow` 只有一行，`v1RecoveryWindow` 有两行，对应两队 ST 的显式恢复。不可用场景通过观测撤销资格，物理机器人仍在场上；若场景从物理世界移除了机器人，V1 环境会给尚在准备中的动作发送终止反馈。停赛注入窗口撤去控制器侧比赛许可。真实比赛进球后，裁判用世界状态 pauseUntil 控制物理重开时序。失败窗口仅在执行器准备结束时生效。测试日志还保留了无反馈的独立单机控制器回放，供组员对照超时与明确失败的区别。[V1 配置](../../algorithms/+tdp/v1Config.m) · [感知适配](../../environment/V1Observation2D.m) · [物理执行入口](../../environment/V1Plant2D.m)
