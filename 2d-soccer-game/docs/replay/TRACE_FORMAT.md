# 记录数据格式（`trace.mat`）

本文只描述**回放与分析实际依赖的字段**。每一条定义都能在工程源码中找到出处，出处写在“来源”一列。列号**从 1 起**（MATLAB 习惯）。本次工作**没有改变任何仿真输出格式**。

## 1. 文件结构

一场比赛保存在 `build/animation-<时间戳>/` 下，由 `LiveViewer2D.start` 写出：

| 文件 | 内容 |
|---|---|
| `trace.mat` | `P`、`trace`、`tactics`（V1 策略时）、`recovery`（仅自动交还实验，非空时） |
| `receipt.json` | 状态（`COMPLETED`/`STOPPED_BY_USER`/`FAIL`）、指标、参数副本、按钮事件 |

用 `whos('-file',...)` 在 2026-11-10 对两份真实记录核对到的变量：

| 记录 | `P` | `trace` | `tactics` | `recovery` |
|---|---|---|---|---|
| `animation-20261106-151829-226`（600 s） | 1×1 struct | 12000×98 double | 12000×171 double | 无 |
| `animation-20261106-105233-827`（5 s） | 1×1 struct | 100×98 double | 100×171 double | 100×53 double |

- `P`：完整配置（`dt`、`Tmatch`、场地与机器人参数、`v1Enabled`、`seed` 等）。回放用到 `dt`、`Tmatch`、`robotR`、`ballR` 和场地尺寸。
- `tactics` 只有 V1 模型才有；默认旧策略保存为 0×0（`runAnimatedMatch.m`）。
- `recovery` 回放**不读取**，本文不展开（53 列的含义未核对）。
- `loadReplayRecording` 要求 `P`（含 `dt`、`Tmatch`）和 `trace`（N×98、实数、有限、时间严格递增）；`tactics` 若尺寸为 N×171 且第 1 列与 `trace` 时间一致才使用，否则丢弃并给出 `Warnings`，回放照常进行。

## 2. 时间与采样

- `trace(:,61)` 是仿真时间 `state.t`，单位秒。第一行是 `dt`（默认 0.05 s），**没有 t=0 行**；600 s 比赛有 12000 行。
- 采样位置：每个控制周期结束后，“碰撞与裁判处理之后”；速度命令是**限速之前**的值（`docs/generated/trace_schema.json` 的 `sample` 字段）。
- 时间由累加 `dt` 得到，存在浮点误差，例如第 3332 行存成 `166.60000000000002`。比较“某时刻”时必须用容差。
- 回放显示用的墙钟只决定节奏，不进入记录（`LiveViewer2D` 注释，`receipt.json` 的 `wallClockUse`）。

## 3. 机器人编号、坐标与方向

- 全局编号 1–8：蓝队 1–4，红队 5–8。队内本地号 1–4 依次为 GK、DF、MF、ST。
- 第 49–56 列 `role` 存 `TdpRole` 数值：GK=1、ST=2、DF=3、SP=4、MF=5。V1 每队按 `[1 3 5 2]` 排列，即 GK、DF、MF、ST。MF 临时接管进攻时仍记为 MF。
- 场地原点在场心，x 沿 9 m 场长，y 沿 6 m 场宽；蓝队攻 +x，红队攻 −x；`th` 从 +x 逆时针为正，单位 rad。线速度单位 m/s（`docs/chapters/interfaces.md`）。
- 位置与速度是**仿真真值**，不是机器人的观测。

## 4. 98 列物理记录（`trace`）

定义顺序来自 `environment/MatchRecord.m`，并导出为 `docs/generated/trace_schema.json`。`scripts/replayColumns.m` 给出同一张表，`tests/test_replay_events.m::testColumnMapMatchesGeneratedSchema` 逐列与该 JSON 核对。

| 列 | 字段 | 含义 |
|---|---|---|
| 1–8 / 9–16 / 17–24 | x / y / th | 机器人 1–8 的位置 (m)、朝向 (rad) |
| 25–32 / 33–40 | vxw / vyw | 场地系速度 (m/s) |
| 41–48 | cool | 剩余踢球冷却 (s) |
| 49–56 | role | 角色枚举值（见上） |
| 57–60 | ballX, ballY, ballVx, ballVy | 球位置 (m)、速度 (m/s) |
| 61 | time | 仿真时间 (s) |
| 62–63 | score | 蓝、红比分 |
| 64 | lastTouch | 最后触球队 0/1/2 |
| 65 | pauseUntil | 暂停到期的仿真时刻 |
| 66–67 | shots | 两队射门计数 |
| 68–69 | touchTime | 最后触球队累计时间。**不是控球率** |
| 70 | msgUntil | 裁判提示显示到期时刻 |
| 71–72 | striker | 旧策略：本地前锋号。**V1：本队获得追球授权的本地号，0 表示无人**（`interfaces.md`） |
| 73–80 / 81–88 / 89–96 | cmdVx / cmdVy / cmdW | 当步限速前的车体系命令 `[vx vy w]` |
| 97 | kicked | 当步是否有机器人向球施加了踢球速度 |
| 98 | msg | 裁判提示枚举 `TdpEvent`：Kickoff=1、GoalBlue=2、GoalRed=3、GoalKick=4、Corner=5、KickIn=6 |

注意：第 98 列在这份记录里取值 `{1,5}`，从不为 0（`None`）。它保存“最近一次裁判提示”，不是“当步是否有裁判事件”。

## 5. 171 列战术记录（`tactics`，仅 V1）

由 `environment/V1TacticsRecord.m` 写出，列号由 `scripts/v1TraceColumns.m` 定义，语义见 `docs/chapters/v1_model_interface.md`。每个“×8”组依次对应全局机器人 1–8，“×2”组依次是蓝、红。

| 列 | 字段 | 含义 |
|---|---|---|
| 1 | time | 与 `trace` 第 61 列相同（回放要求一致） |
| 2–3 / 4–5 | phase / basePhase | 球队阶段 `TdpTeamPhase`：Hold=0、Defend=1、Attack=2、Search=3、Fallback=4 / 记忆的基础攻防 |
| 6–7 | chaser | **全局**追球者编号，0 表示无人获准 |
| 8–9 / 10–11 | ballKnown / ballSource | 是否有队级球观测 / 提供者编号 |
| 12–13 | failed | 蓝/红 ST 匹配失败锁存 |
| 14 | running | 本拍比赛许可 |
| 15 | kicker | 本拍实际踢球的机器人全局号，0 表示无 |
| 16–23 / 24–31 | available / ballFresh | 机器人位姿新鲜有效 / 球观测新鲜有效 |
| 32–39 | intent | **团队意图**动作 `TdpAction`：Stop=0、Goto=1、Kick=2、Search=3、Tap=4 |
| 40–47 / 48–55 | rawKind / kind | 个人控制器原始请求种类 / 授权后实际请求种类 |
| 56–63 | requestId | 实际请求编号（Goto 每拍都换号） |
| 64–71 / 72–79 | status / feedbackId | 执行反馈 `TdpStatus`：None=0、Running=1、Done=2、Failed=3、Rejected=4 / 其对应编号 |
| 80–87 | skill | 个人 Stateflow 阶段 `TdpPhase`：Idle=0、Search=1、Approach=2、Align=3、Kick=4、Recover=5 |
| 88–95 / 96–103 | targetX / targetY | **意图**目标（Goto 为站位、Kick 为瞄准点；Stop/Search 的 (0,0) 只是占位） |
| 104–111 | ballAge | 球观测年龄 (s) |
| 112–119 / 120–127 | rawId / executions | 原始请求编号 / 执行器累计接受次数 |
| 128–135 / 136–143 / 144–151 | feedbackStamp / validUntil / stamp | 反馈时刻 / 请求到期 / 请求发出 |
| 152–159 / 160–167 | rawSpeed / speed | 踢球标称速度 (m/s)，**不是**平移速度 |
| 168–169 / 170–171 | takeover / recovering | MF 接管 / 交还等待 |

三点容易读错：

1. **“意图”不等于“请求”。** `intent` 是球队协调器想让该机器人做什么；`kind` 是经过授权层之后真正交给执行器的请求（被撤权会变 Stop）。
2. **反馈可能是旧的。** 机器人空闲时 `status` 会保留上一次终态；必须用 `(robot, feedbackId)` 去重（`replayEvents` 就是这样做的）。
3. **`chaser` 用全局号，`trace` 的 71–72 列用本地号。**

## 6. 直接记录的信息与推断的信息

| 类别 | 例子 | 依据 |
|---|---|---|
| **直接记录**（字段取值本身） | 位置、速度、球、比分、球队阶段、追球者、意图、请求种类/编号、反馈状态/编号、实际踢球者 | 上面两张表 |
| **事件（记录值的变化）** | 由相邻两行同一字段不同而得：`phase`、`chaser`、`takeover`、`recovering`、`gameRunning`、`intent`、`request`（Kick/Search/Tap 的起点）、`feedback`（Done/Failed/Rejected 的新终态）、`kick`、`goal`、`referee` | `scripts/replayEvents.m`；事件列表标 `[R]` |
| **推断** | `chaserStationary`：追球者的世界速度 `hypot(vxw,vyw)` 连续低于 0.02 m/s 至少 1 s，且比赛在进行；这是多个记录值加阈值规则的结果 | 同上；标 `[I]` |
| **更强的推断（本文分析使用，回放不生成）** | 用 `kickSkill.m` 的公式从记录的位置重算“在球后方”等条件 | `phaseC/analyze_behaviour.py` |

**事件只是“字段变了”**。例如 `[R] phase Attack -> Fallback` 说明球队阶段在这一帧变了，不说明原因。

## 7. 缺失或有歧义的信息

| 想知道的 | 现状 |
|---|---|
| 踢球**失败的原因**（`TdpV1Reason`：Geometry/Arbitration/Subsystem/Canceled/Expired） | `Actuator2D` 会算出它，但**没有记录进 `trace` 或 `tactics`**（`V1TacticsRecord` 没有这一列；`recovery` 未核对）。只能用位置重算后推断 |
| 球队阶段**为什么**切换 | 没有记录。只能从 `basePhase`、`failed`、`takeover`、`ballKnown` 等字段推测 |
| 机器人“不动”是被命令停止、被堵住还是已到位 | 没有接触/受阻标记（`receipt.json` 只有汇总计数）。可看 `intent`、`kind`、`cmd*`（限速前命令）与实际速度 |
| 机器人自己的观测 | 记录的是真值；观测新鲜度只有 `available`、`ballFresh`、`ballAge` |
| 第 0 行（开球前） | 没有 |
| 非 V1 策略的战术信息 | 没有（`tactics` 为 0×0）。回放只显示位置，并在检查器标明“NOT RECORDED” |
| 其他目录（`build/match-*.mat`、`baseline-*.mat`、`run-*`）的格式 | **未核对** |

## 8. 兼容性

- 回放只要求 `trace` 是 N×98。其他列数的旧格式会被 `loadReplayRecording` 以 `TDP:ReplayLoad` 拒绝，不会猜测。
- 以后给 `tactics` 增加列，必须同时改 `v1TraceColumns.m`、`V1TacticsRecord.m`、`replayInfoText.m`，并更新 `loadReplayRecording` 中的 171。
- 本次没有向保存的文件添加任何东西；已验证 18 份原始 `trace.mat` 的 SHA-256 在全部开发与测试之后未变（见 [TESTING.md](TESTING.md)）。
