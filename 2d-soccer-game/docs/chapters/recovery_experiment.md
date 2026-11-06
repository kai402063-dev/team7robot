# 二维实验：前锋何时接回追球职责

前锋（ST）准备踢球时，球可能已经滚出了它的触球范围。中场（MF）可以临时接管追球。如果稍后前锋恢复了，队里要分别回答两个问题：前锋能否重新工作？中场刚才那一脚是否已经结束？实验把这两个判断分开，以免两台机器人同时接到踢球授权。

## 选哪种比赛

在工程根目录运行下面任一入口。两个入口都能看实时运动，金色外圈表示本队当前有追球授权的机器人。

| 想观察的行为 | 桌面启动文件 | 终端启动 | MATLAB 配置和 Simulink 模型 |
|---|---|---|---|
| 复现球队 V1。前锋失效后中场接管，显式恢复信号触发交还流程 | `START_2D.desktop` | `./start_2d.sh` | `tdp.v1Config()`，`tdpV1Match` |
| 试验自动交还。协调器逐拍读取前锋健康情况，再处理现有动作编号 | `START_2D_RECOVERY.desktop` | `./start_2d.sh --recovery` | `tdp.recoveryConfig()`，`tdpRecoveryMatch` |

实验沿用 V1 的球场、二维物理、四种角色和攻守阵型。三条交接规则是小组针对 V1 恢复条件所选的实验设计。两队各有一个协调器。蓝队中场和前锋的全场编号分别为 3、4，红队分别为 7、8。从 MATLAB 看默认实验动画可运行 `start_2d_recovery`。实际策略选择与模型生成见[配置函数](../../algorithms/+tdp/recoveryConfig.m)、[模型选择](../../scripts/matchSimulationInput.m)及[生成脚本](../../scripts/build_recovery_match.m)。

## 手走一次交接

1. **几何失败先接管。** 例如红 8 在准备阶段与球拉开距离，执行器在真正施加球速时发现距离或朝向超限，返回该次请求的 `Failed / Geometry`。下一控制拍，协调器核对机器人、动作编号和时刻，锁存临时接管；红 7 可用且比赛进行时承担追球。仅仅有一条旧的红 8 失败反馈不能重复触发接管。若前锋自身定位失效、执行器故障或健康通信中断，同样进入接管。
2. **前锋连续健康才恢复资格。** 协调器检查自己的位姿观测有效且足够新，执行器本拍有新鲜心跳、已就绪且没有旧动作。用输入的仿真时间 `tSim` 从首个合格样本开始计时，满 0.50 s 才可交还。默认周期 0.05 s 需再过 10 个完整间隔，换成 0.04 s 需 13 个间隔，即 0.52 s。强制故障期间 `ready=false`；掉线期间重复收到的旧心跳无法凑满时间。故障清除、连续的新鲜样本恢复后重新计时。看球和定位分开判断；全队暂时看不到球时，定位和执行器均合格的前锋仍能恢复，比赛进行中转入 Search（寻找球）。
3. **根据中场当前动作选择交还方式。** 若中场还在走向球，没有在途的 Kick（踢球）或 Tap（轻推），前锋满足时间门后就回到正常分工。有合规在途动作时，例如蓝 3 的编号 17 已经开始准备，仅准蓝 3 把 17 做完。重复 17 不会再踢一遍，蓝 3 的新编号 18 和蓝 4 的新踢球都不能抢占这一脚。停赛、中场自己看球过期、自身不可用、心跳失效或请求过期时，发给蓝 3 的是原编号的 `Stop(17)`。若上游尝试换编号，同样撤销原动作。直到确认 17 的终态才释放该编号；若此时前锋又失去定位，则继续中场接管，前锋须再次满足健康时间。回到正常分工后，进攻时由前锋追球，防守时继续按 V1 的防守条件选人。

**终态如何认。** 协调器把中场全场编号和 `releaseId` 配成一对保存。有效终态需来自该机器人、对应此编号、发生在请求之后，且不早于最近一次确认它还在执行的心跳。新鲜心跳须再次确认同编号并报告 `activeId=0`。自然完成用 `Done`，执行失败或已取消用 `Failed` 并结合原因判断。原踢球请求直接被拒绝，可以据此确认它未开始；发送取消后收到 `Rejected` 不能证明旧动作已结束。旧编号、错机器人、未来时刻或缺少执行层确认都要继续等。断流后可由恢复通信时送回的同编号终态解锁；即便本地等待超时也不放行新的踢球。

队级门控见[恢复与编号跟踪](../../algorithms/+tdp/updateRecovery.m)，动作在真正进入执行器前还会经过[逐机器人授权](../../environment/V1AuthorizeRequests.m)。如果要改 0.50 s，应调整实验配置并重跑下方两个周期的测试；要改接管后的跑位，阅读[两种模型共用的队级分工](../../algorithms/+tdp/v1TeamPlans.m)。

## 配置和信号

| 字段 | 类型、尺寸与单位 | 用法 |
|---|---|---|
| `P.v1AutoRecovery` / `P.v1RecoveryHealthySeconds` | logical 标量 / double 标量，s | 由实验配置设为 true / 0.50。这是二维实验的策略阈值 |
| `P.dt` / `P.maxObservationAge` / `P.kickTimeout` | double 标量，s | 默认 0.05 / 0.50 / 1.0。位姿和球观测各按自己的采集时刻判断。健康心跳年龄限一个控制周期。在途动作最晚至原 `validUntil` 与原请求时刻加 `kickTimeout` 的较早者 |
| `P.v1UnavailableWindow` / `P.v1FailWindow` / `P.v1HealthDropWindow` | 每项 double，8×2，s | 每行是一台机器人的起止仿真时刻，含起点、不含终点。分别模拟自身观测不可用、执行器故障、回传链路保持最后一个包。默认区间为空。`P.v1RecoveryWindow` 可为原 V1 注入显式恢复；实验始终检查实际传入的健康数据 |
| `health(i).stamp` / `ready` | double 标量，s / logical 标量 | 第 i 台执行器的心跳采集时刻 / 当前是否可接新动作。回传正常时，即使最近一次动作结果未变，心跳时间也会前进 |
| `health(i).requestId` / `activeId` | uint32 标量，各一项 | 最近反馈对应的请求 / 当前真正执行的编号；后者为 0 表示无活动动作。比较编号前先选对机器人 |
| `health(i).reason` | `TdpV1Reason` 枚举标量 | None 无附加原因，Geometry 几何条件，Arbitration 同步仲裁，Subsystem 子系统，Canceled 已取消，Expired 已过期。该字段随对应反馈编号保存 |

实验专用的健康数组固定为 1×8。[健康结构](../../algorithms/+tdp/v1Health.m)和[枚举](../../interfaces/TdpV1Reason.m)定义接口，[执行层](../../environment/RecoveryPlant2D.m)填写健康状态，[回传适配](../../environment/RecoveryFeedback2D.m)按窗口模拟丢包。Unit Delay（单位延迟）令第 k 拍协调器读取第 k−1 拍回传，第 k 拍记录的是本拍队级决策和本拍新回传。对齐两列时要留出这一拍。

## 自己制造一次接管并看逐拍日志

在 MATLAB 中把当前文件夹设为工程根目录，把下面整段粘贴到命令窗口后运行。短实验只遮挡蓝 4 的定位，便于在一屏内找到接管和交还。把 `P.dt` 换为 0.04 可重复练习。

```matlab
tdpSetup;
P = tdp.recoveryConfig();
P.Tmatch = 8;
P.dt = 0.05;
P.v1UnavailableWindow(4,:) = [2 4];
[trace,tactics,recovery] = runMatch(P);
c = v1TraceColumns();
h = v1RecoveryColumns();
team = 1;
takeover = tactics(:,c.takeover(team));
idx = find([true; diff(takeover) ~= 0]);
disp(table(tactics(idx,c.time), takeover(idx), tactics(idx,c.chaser(team)), ...
    recovery(idx,h.releaseId(team)), 'VariableNames', ...
    {'tSim','takeover','chaser','protectedId'}))
```

在无桌面的独立 MATLAB 进程里复做时，先将上方代码框的内容原样存成工程下的 `build/handback_demo.m`，然后在工程根目录运行 `./scripts/run_matlab.sh "tdpSetup; run('build/handback_demo.m');"`。终端应打印带 `tSim`、`takeover`、`chaser`、`protectedId` 四个列名的表。若只见进程退出却没有表格，请用上述脚本文件方式保留 MATLAB 的换行，避免把整段含续行符的代码折进一个终端参数。

第一行是初态。在定位窗口内，蓝 3 接管，`takeover` 升为 1；恢复正常分工时它降为 0。这个样例解除接管的那一拍，`chaser=0` 表示当前无人获准追球。蓝 4 已恢复参与正常分工的资格，何时重新追球仍取决于 V1 的攻守判断。核对[八秒练习的实测三行](../generated/recovery_results.md#八秒练习的逐步输出)。若持续为 1，依次查前锋的 `c.available(4)`、`h.stamp(4)`、`h.ready(4)`、`h.activeId(4)` 和本队 `h.healthTiming(1)`。若需要等中场的旧动作结束，查看 `h.releaseId(1)` 和 `h.cancelPending(1)`，再对照中场的 `c.rawId(3)`、`c.kind(3)`、`c.requestId(3)`、`c.feedbackId(3)` 及 `c.status(3)`。每项应在其所属矩阵中查找：`c` 对应 `tactics`，`h` 对应 `recovery`。判断球是否真的踢出，另看 `c.kicker` 以及物理矩阵 `trace(:,57:60)` 中的球位置和速度。可用 `tdpRun(P)` 将三组记录和配置保存到独立的 `build/run-*/trace.mat`。[战术列名](../../scripts/v1TraceColumns.m)及[实验诊断列名](../../scripts/v1RecoveryColumns.m)

## 复验与证据

在工程根目录的终端运行。第一条只跑模型定向场景，输出的每条 `RECOVERY_CASE` 都带控制周期、关键拍仿真时刻、追球者、编号、反馈与实际踢球者。搜索 `natural-geometry-return` 找自然几何失败，`finish-original-mf-kick` 找原脚结束，`hold-through-missing-terminal` 找丢失终态。第二条还会重建实验模型并配对比较两种策略，默认 0.05 s 和 0.04 s 各 20 个种子，每场 600 s。

```bash
./scripts/run_matlab.sh "tdpSetup; r=runtests('tests/test_recovery_model.m'); assertSuccess(r);"
./scripts/run_matlab.sh "tdpSetup; reproduce_recovery;"
```

[队级测试结果](../../evidence/recovery-v1/team-unit-02/receipt.json)和[移除编号检查后的变异结果](../../evidence/recovery-v1/team-mutation-01/receipt.json)可用来核对为什么不能换号；[模型定向测试](../../tests/test_recovery_model.m)给出场景初值和逐拍断言。调试时先区分心跳送达、动作确认和球发生位移这三件事。这里验证的是两个控制周期下的二维代理，实机定位时延、NAO6 的步态与踢球接触仍需各自的实测。

正式一键复验在本机干净克隆中约需 21 分钟，耗时包括编译、定向测试、整场对照和重复回放。每组比赛双方使用相同策略；比较的是该组条件下的比赛节奏、接管与总进球。实验在常规比赛中成功解除所有自然接管，快速交还同时伴随更多射门、更少进球。保护中场在途踢球和失效后同编号取消的情形由定向场景实际触发。采用哪套规则仍由小组决定。[干净运行总回执](../../evidence/recovery-v1/clean-01/receipt.json) · [故障与交还逐拍记录](../../evidence/recovery-v1/model-scenarios-02/events.json)

[两种策略的整场对照与证据](../generated/recovery_results.md)
