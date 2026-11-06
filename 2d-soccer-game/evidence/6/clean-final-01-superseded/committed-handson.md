# 亲手做七条最小路径

先完成一键复现，再做本章。不要第一次就手搭八台机器人。每条路径都先保存为自己的模型名，放在 `build/learning/`；自动生成的 `models/` 由脚本负责。手动练习完成后，对照脚本生成版和测试结果。自动验收只操作新的批处理进程；自己观察图形时才打开 MATLAB 桌面。

## 1. 写一个函数和测试：线段是否能传球

问题：障碍在传球线旁 0.3 m，安全余量 0.4 m，应该允许传球吗？计算最近线段点 `a+clamp(dot(p-a,b-a)/dot(b-a,b-a),0,1)*(b-a)`，再比较距离。clamp 就是限制到指定区间，保证最近点不会落到线段延长线上。

1. 在自己的练习目录建 `laneClearLesson.m`，输入 `a(1×2), b(1×2), obstacles(4×2), margin`，返回 logical。从 `tdp.laneClear` 读公式，再自己写出来。
2. 建 `test_laneClearLesson.m`，首行函数返回 `functiontests(localfunctions)`；局部测试使用 `verifyFalse` 验证线段 (0,0)→(2,0)、障碍 (1,0.3)、余量 0.4。
3. 加一例障碍在线段延长线上，一例 a=b，一例距离恰好等于 margin。比较符号 `<` 与 `<=` 的选择必须明确。
4. 执行 `runtests('test_laneClearLesson.m')`；再故意把 `<` 改成 `>`，确认测试失败，恢复后再通过。

本仓库对应测试为 `test_algorithms/testLaneClear`，包含 1000 组。常见错误是没有夹紧投影参数、把米和米平方直接比较、忘记零长度线段。完成后应能解释：为什么只测一条无障碍线路无法证明函数正确？

## 2. 搭闭环与 Unit Delay

问题：目标位置是 1 m，当前位置为 0，怎样用比例速度逐步接近？模型为 `x[k+1]=x[k]+dt*Kp*(1-x[k])`。第一次先输出 x[0]=0，再保存下一拍位置。

| 模块 | 参数 |
|---|---|
| Constant Target | Value=1 |
| Sum Error | Inputs=+- |
| Gain Kp | Gain=0.8 |
| Gain dt | Gain=P.dt；P.dt=0.05 |
| Sum Integrate | Inputs=++ |
| Unit Delay PositionMemory | InitialCondition=0；SampleTime=P.dt |
| To Workspace Records | VariableName=records；SaveFormat=Array |
| 模型配置 | Fixed-step / discrete；FixedStep=P.dt；StopTime=0.2；Algebraic loop=error |

接线：Target→Error 正端，PositionMemory→Error 负端；Error→Kp→dt→Integrate；PositionMemory 同时→Integrate 另一正端；Integrate→PositionMemory；PositionMemory→Records。环路必须经过 Unit Delay。

手工搭好后和 `scripts/build_lessons.m` 生成的 `tdpDelayLesson` 对照。运行 `test_lessons/testClosedLoopUnitDelay`，输出应符合 `1-(1-0.8*0.05).^(0:4)`；具体数组由手册生成脚本输出到 generated。若第一点已非 0，检查记录位置是否放在延迟前；若编译报代数环，检查是否绕过延迟；若跳变过大，检查有没有漏乘 dt。完成后应能解释：Unit Delay 的初值属于哪个物理状态？

## 3. 先画平铺状态图

问题：先学转换，不要同时处理总线、层级和动作编号。建立 `tdpFlatLesson` 的手工副本。

| 模块/数据 | 参数 |
|---|---|
| Digital Clock | SampleTime=P.dt |
| Step BallSeen | Step time=0.1；Initial=0；Final=1；SampleTime=P.dt |
| Chart | Action language=MATLAB；Update=Discrete；SampleTime=P.dt |
| Chart tSim / seen | Input，double，标量，端口 1 / 2 |
| Chart phase | Output，Enum: TdpPhase，标量 |
| Data Type Conversion | double，用于输出记录 |

Clock→tSim，Step→seen，phase→类型转换→To Workspace。三个平铺状态文字如下：

```text
Idle
en,du: phase=TdpPhase.Idle;

Search
en,du: phase=TdpPhase.Search;

Approach
en,du: phase=TdpPhase.Approach;
```

默认箭头→Idle；Idle→Search `[tSim>=0.05]`；Search→Approach `[seen~=0]`；Approach→Search `[seen==0]`。运行 0.2 s，对照生成的 phase 序列与 `test_lessons/testFlatStates`。常见错误是省略默认箭头、把 phase 定义为 double 却写枚举、误用 continuous 更新。完成后应能解释：进入动作和保持动作何时各执行一次？

## 4. 增加层级、计时和 requestId

问题：动作需要准备时间，怎样避免每拍重发都从头开始？先用下面命令生成一个新的可编辑回放外壳，再在其中重画自己的图。它从空白建模，保留 Geometry、Request、输入回放和记录接线；Core 已解除库链接。练习目录存在同名模型时会报错以保护手工作业。

```matlab
root=tdpSetup;
file=build_learning_replay('myKickReplay',fullfile(root,'build','learning'));
load_system(file);
open_system('myKickReplay/ControllerCore/SkillStages');
```

在 **myKickReplay** 的 SkillStages 中删除原状态与转换，保留 Symbols 中的数据定义及 Chart 块本身；把路径 3 的平铺状态组织成 Idle 和父状态 Active，再在 Active 内画 Search、Approach、Align、Kick、Recover。不要修改 `ControllerCore.slx` 或只打开原 `tdpReplay`。

1. 先在 Symbols/Data 面板建立 g:GeometryBus、fb:FeedbackBus、tSim:double 输入和 P 参数；输出 phase:TdpPhase、requestId:uint32、kickStart:double、kickTarget:[1 2]、kickSpeed:double；局部 recoverStart:double。
2. 默认转换必须初始化编号、目标、速度和两个起始时刻。完整可复制文字来自 `docs/generated/stateflow.md` 的状态及 T1…T14 围栏代码块；转换表是索引，复制代码块原文，不能把 HTML 实体当成 MATLAB 的 `||`。不要靠截图猜语句。
3. Kick 进入时把 requestId 加一并保存 tSim、目标和速度；保持 Kick 时不重新赋值 kickStart。Recover 进入时保存 recoverStart。
4. Kick→Recover 的终态反馈条件必须先比较编号，再判断 Done/Failed/Rejected；超时条件为 `tSim-kickStart>=P.kickTimeout`。按生成表设置 Execution Order，匹配反馈优先于超时。
5. Active→Idle 检查自身观测有效和停赛。将父边界包住所有子状态和转换曲线中点，避免意外重入。
6. 用以下命令把固定场景明确送入 **myKickReplay**。原 `runReplay(P,s)` 默认仍测试生成库；第三参数才选择自己的图。先无反馈超时，再注入同编号 Done 和旧编号 Done。

```matlab
P=tdp.defaultConfig(); P.mode=TdpMode.Delayed;
s=makeScenario(P,2);
own=runReplay(P,s,'myKickReplay');
reference=runReplay(P,s);
assert(isequaln(own,reference)); % Same graph text should give the same sequence.
k=find(own(:,1)==double(TdpAction.Kick),1);
j=k+2; id=uint32(own(k,2));
s(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*P.dt);
finished=runReplay(P,s,'myKickReplay');
assert(finished(j,3)==double(TdpPhase.Recover));
s(j).feedback.requestId=id-uint32(1);
late=runReplay(P,s,'myKickReplay');
assert(late(j,3)==double(TdpPhase.Kick));
save_system('myKickReplay',file);
```

Chart 端口与外壳接线如下，重画内部状态时不应改变它们：

| 来源 | 目的 | 类型/尺寸 |
|---|---|---|
| Geometry/1 | SkillStages/1 (g) 及 Request/1 | GeometryBus 标量 |
| feedback/1 | SkillStages/2 (fb) | FeedbackBus 标量 |
| tSim/1 | SkillStages/3 及 Request/7 | double 标量 s |
| SkillStages/1 (phase) | Request/2 及 phase 输出 | TdpPhase |
| SkillStages/2 (requestId) | Request/3 | uint32 标量 |
| SkillStages/3 (kickStart) | Request/4 | double 标量 s |
| SkillStages/4 (kickTarget) | Request/5 | double 1×2 m |
| SkillStages/5 (kickSpeed) | Request/6 | double 标量 m/s |
| Request/1 | request 输出 | RequestBus 标量 |

`test_lessons/testLearningHarnessUsesItsOwnChart` 会在内存中把可编辑图的超时改成一半，确认只有自己的回放提早 Recover，原库回放不变，再恢复原文。这是“接到了自己的图”的证据。

默认参数表：准备 0.20 s、超时 1.0 s、恢复 0.5 s、进入 Align 距离 0.35 m、离开距离 0.45 m；均为教学设计，不是三维标定。精确周期表由脚本生成，状态名与 requestId 逐拍列出。

如果编号每拍递增且执行器一直拒绝，查父状态是否意外重入；如果编号不变却动作被重启，查执行器去重；如果无反馈永不退出，查超时是否使用输入 tSim。完成后应能解释：动作结束、请求被接受和球被踢出为什么是三件事？

## 5. 做一次回放测试

回放就是把已经固定的输入序列重复送入控制器，排除物理环境和随机数的干扰。

```matlab
tdpSetup;
P=tdp.defaultConfig(); P.mode=TdpMode.Delayed;
s=makeScenario(P,2);
a=runReplay(P,s); b=runReplay(P,s);
assert(isequaln(a,b));
assertSuccess(runtests('tests/test_controller.m'));
```

`makeScenario` 每个采样保存 obs、intent、feedback。修改一项输入时保存为新场景，记录唯一变量。无反馈、Failed、Rejected、失球、停赛、旧编号 Done 都有现成测试。不要把环境改动后的新观测也送进去，然后声称“真值不影响控制器”；隔离测试要求输入观测本身不变。

常见错误是回放数组长度与 StopTime 不一致、timestamp 更新了但数值来自更早一拍、模型工作区仍保存旧 P。完成后应能解释：确定性回放能证明接口与状态逻辑，但为什么不能证明 NAO6 动力学？

## 6. ROS 2 标量与过期标志

这一项的可运行 CLI/Python 路径和 MATLAB 适配测试见 [ROS 2 章节](ros2.md)。ROS Toolbox 当前未安装，因此 Simulink ROS Publish/Subscribe 的手工接线步骤只能作为解除阻塞后的操作说明，不能记为已经跑通。预备知识：节点是独立进程，主题是带类型的数据通道；同名主题但类型不一致不能通信；IsNew 只说明本次接收到新样本，不说明样本采集得足够新。

完成 CLI 标量回环后，要故意停止发布，观察过期变为 true。年龄必须由仿真时钟减采集时间计算；没有新消息时不能把 stamp 重写成当前时刻。完成后应能解释：收到了一个旧包为什么仍然需要停止？

## 7. Webots 读场景、读相机、单个动作

实际场景路径、场地检查脚本、相机和动作命令见 [Webots章节](webots.md)。先读取 WorldInfo/basicTimeStep，再读机器人版本，最后试现有 motion。不要先写追球策略。

必须分别记录：ROS 通信是否成功；motion 是否到末帧；球是否有可测位移。Supervisor 可以读取真值作教学定位，但不能用它设置球速。相机消息的宽高/编码正确也不等于识别正确；ROS Toolbox 的 Read Image ErrorCode 门限缺依赖时必须保留 BLOCKED。
