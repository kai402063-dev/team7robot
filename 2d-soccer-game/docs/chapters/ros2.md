# ROS 2：从标量到原控制器在线回放

## 问题和边界

二维控制器原来每拍直接接收 MATLAB 结构体。跨进程后，数据可能重复、迟到或已经过期；收到一个包，不代表可以继续走。ROS 2 的节点是进程中的通信参与者，主题是带消息类型的通道。这里用系统已有 Jazzy、Python rclpy 和标准消息，不构建自定义消息，不修改系统 Python。

本机缺少 ROS Toolbox、Simulink Coder、MATLAB Coder。因此原生 MATLAB ROS 2 在线块和生成独立控制器节点仍 BLOCKED。`tdpRosProxy` 是已存在 JVM 的本地 socket 加 Python ROS 2 代理：真正执行的仍是 Simulink 中原 ControllerCore，不把算法复制成 Python。这条路径只支持 normal simulation（普通仿真模式），不能当作独立生成节点。代理通信通过也不能证明机器人动力学有效。

## 两个外层模型和时序

`scripts/build_ros_adapter.m` 从空白生成两个模型：`tdpFrameReplay` 从固定矩阵逐行取样，`tdpRosProxy` 从本地 socket 收到一行。两者其余部分完全相同：Receive→Decode→ControllerCore→Record；Decode 的 held 输出→Unit Delay→previous 输入，断开当前包与上一有效包的环路。Unit Delay 初值是20个0（表示尚无有效帧），采样周期 P.dt。数字时钟只调度 Simulink 的运行步，控制器 tSim 来自帧内已与 `/clock` 核对的时间。

Python 代理先等同一时刻的 `/clock` 和观测，再通过绑定127.0.0.1的 socket 发送20个数；Simulink 返回11个动作数后，代理发布动作和诊断年龄。一次只允许一个在途观测，保持回放确定性。接收超时是进程故障，控制状态的技能超时仍只用输入 tSim。网络等待期间不声称满足真实时间控制要求。

## 消息契约

标准 `std_msgs/msg/Float64MultiArray` 的布局固定，第一项协议版本为1。它只是传输容器；不要省略字段，也不要把多个不同时间的消息拼成一帧。编号需为能精确表达的 uint32 整数值，Python/MATLAB传输层校验长度和有限数。

| 观测帧索引（MATLAB从1开始） | 内容 | 单位/约束 |
|---|---|---|
| 1 / 2 | 协议版本 / tSim | 1 / s，来自 `/clock` |
| 3 | 自身位置采集时刻 | s |
| 4…6 | x,y,yaw | 场心ENU平面，m,m,rad |
| 7 | 自身有效 | 0或1 |
| 8…11 | 球x,y,vx,vy | m,m,m/s,m/s |
| 12 / 13 | 球有效 / 球采集时刻 | 0或1 / s |
| 14 | 比赛运行 | 0或1 |
| 15…17 | feedback requestId,status,stamp | uint32整数值 / TdpStatus值 / s |
| 18 / 19 | 机器人z / 球z | m；记录定位来源，控制核心不据此直接控制球 |
| 20 | 观测包序号 | 正uint32整数，单会话递增 |

动作主题 `/tdp/request` 的11项为 kind、requestId、phase、车体vx/vy/w、目标场地x/y、speed、stamp、validUntil，与二维回放相同。`/tdp/observation` 是上述20项；`/clock` 类型为 `rosgraph_msgs/msg/Clock`；新增主题 `/tdp/diagnostics/action_age` 为 `std_msgs/msg/Float64`，表示 tSim减自身采集时刻，单位s。

Decode 的 quality 输出依次为 IsNew、自身年龄、自身过期、球年龄、球过期、时钟有效。IsNew表示序号比上一接受序号大。重复/乱序包保留上一有效内容和采集时间；未来时间、过老数据、无效标志使对应观测无效。旧包不能把年龄归零。时钟回退必须重开控制器会话，代理显式报错；本版未实现在线重置或编号回绕。

## 手工路径：先标量，再过期，再控制器

先在工程根目录构建本地包（不安装系统依赖）：

```bash
./scripts/run_ros.sh colcon --log-base build/colcon/log build --base-paths ros2 --build-base build/colcon/build --install-base build/colcon/install
```

在三个终端分别执行，终端都先进入同一工程根目录：

```bash
./scripts/run_ros.sh python3 -m tdp_webots_bridge.scalar_echo
./scripts/run_ros.sh ros2 topic echo /tdp/scalar_out std_msgs/msg/Float64 --once
./scripts/run_ros.sh ros2 topic pub --once --wait-matching-subscriptions 1 /tdp/scalar_in std_msgs/msg/Float64 '{data: 3.5}'
```

观察输出是输入加一，再用 Ctrl+C 结束本任务节点。该脚本设置独立 ROS_DOMAIN_ID=97、仅本机发现和工程内日志目录；不要同时运行另一套同域实验。通过 `ros2 topic info /tdp/scalar_out --verbose` 检查发布者、类型和端点。先确认通信，再谈算法。

下面在新的 MATLAB 批处理里手动制造过期：

```matlab
tdpSetup; P=tdp.defaultConfig(); f=makeBridgeFrames(P,1);
[o,~,~,~,q,held]=BridgeDecode(f,zeros(1,20),P);
f(2)=0.6; % Clock advances, acquisition time and sequence do not.
[stale,~,~,~,after]=BridgeDecode(f,held,P);
assert(q(1)==1 && after(1)==0 && after(3)==1 && ~stale.selfValid);
```

模型内手搭这一段时：Unit Delay 的 InitialCondition=`zeros(1,20)`、SampleTime=`P.dt`；Decode 的 frame/previous/held 均显式设 Size=`[1 20]`，quality=`[1 6]`；P是Parameter。使用 Unit Delay 保留上一接受帧，不在收到重复包时更新 stamp。测试入口 `test_ros_adapter` 包含新包、重复、乱序、未来、非法包、时钟回退、反馈和真正的 Core 回放。

完整标准消息在线对比（目录必须未存在）：

```bash
./scripts/run_ros.sh python3 scripts/validate_ros.py build/ros-manual-01
```

程序启动/关闭本任务进程，保留每个进程的日志、`ros2 topic` 原始输出、固定输入、在线/离线动作及回执。预期通信与代理在线回放通过；原生 ROS Toolbox/生成节点字段仍为 BLOCKED。不要因相同进球就称动作序列相同；脚本比较每一行全部11个值。

## 模块卡片与扩展

| 模块 | 职责和源码 | 来源、测试和改动方法 |
|---|---|---|
| BridgeDecode | `environment/BridgeDecode.m`，20项→观测/反馈/质量/保持状态 | 本次接口设计；不是A/B行为。改字段须同时改协议、Python及测试 |
| BridgeSocket / Read / Write | 本地阻塞输送，绝不产生控制时间 | 本次运行适配；仅普通仿真。用外层记录比较其透明性 |
| proxy | `ros2/tdp_webots_bridge/tdp_webots_bridge/proxy.py`，核对clock与观测，发请求/诊断 | Jazzy标准消息，固定一个在途输入；不控制机器人 |
| replay_driver | 发布录制观测及合成clock，收集动作 | 只用于阶段4；Webots运行时不得同时启动它，以免两个clock发布者 |
| scalar_echo | 接收标量并加一 | 学习主题通信的最小例子，CLI输入输出证明通信 |

第六个已实现扩展示例是 action_age 主题：在代理建立 Float64 publisher，在完成交换后发布帧时间减采集时间；回放驱动订阅并逐项与输入算出的年龄比较。新增其他主题先写字段/单位/时间来源，再加发布与订阅断言，最后保存topic证据。不要从日志文本反推时间。

若解除产品缺失，原生路线是 Digital Clock（或Webots `/clock`）→年龄判断，ROS2 Subscribe(IsNew,Msg)→保持消息→转换接口→Core→转换接口→ROS2 Publish。Subscribe的采样时间P.dt、消息类型与上述表一致、QoS可靠/深度10；保持旧Msg时不改采集stamp。先用同一录制流验证原生在线，再单独生成/运行节点并逐项比较。本版没有实测这些块，不把此操作说明当证据。

常见错误：无订阅者先查域号/消息类型；ROS已导入的动态库污染MATLAB时只用 run_matlab.sh；矩阵被当成可变尺寸时显式设 `[1 20]`；socket EOF先查MATLAB编译日志；重复包持续显示新鲜则查是否重写stamp。完成后应能解释：IsNew与新鲜度有什么区别？哪个进程拥有控制状态？代理退出后为什么不能沿用旧requestId会话？

当前代理在没有新观测包时阻塞接收：Core不会仅随持续的 `/clock` 自行推进，也不会在这条代理链上主动把保持样本变成过期。此时是transport stall，随后触发墙钟接收超时；Webots锁步环境停止推进物理。本次新鲜度验收证明收到旧stamp/重复序号时的处理，**不证明**“真实连续时钟下停发观测、控制器仍持续运行”的NoNew看门狗。后续原生异步适配必须增加独立时钟调度、保持采集时刻和超时停步，再单独验收。

## 启动时为什么重复发同一张图像

Webots 首帧采用 volatile（不向晚加入订阅者补发历史数据）消息。DDS 是 ROS 2 底层的发现和传输机制；节点刚启动时，订阅者可能尚未与发布者匹配。如果首帧只发送一次，观察器可能收不到它，控制器又在等观察器的图验证回执，便无法开始仿真循环。

`ros2/tdp_webots_bridge/tdp_webots_bridge/bootstrap.py` 的 `wait_for_graph_evidence` 负责启动握手：读取回执是否就绪，按配置重发已有的 clock/image 并处理 ROS 回调，成功返回重发次数，超时抛错。它不持有机器人/球状态，不调用 Webots 的 step；输入消息对象和采集 stamp 原样重复。来源是本次工程设计，无 A/B 对应行为。间隔和超时见生成的 Webots 参数表，单位为墙钟秒；正常控制周期仍由仿真时间决定。

手动检查时依次看 `camera.json`、`camera-ros.json`、`graph-ready.json` 和最终 `bootstrapRepublishes`：它们分别是本地相机读取、ROS 接收、图验证和握手重发记录。参数变更应运行 `python3 -m unittest discover -s tests -p test_webots.py -v`，再做真实 M2 回归。延迟发现/丢首帧回归与删除重发的有效变异见 `evidence/6/ros-bootstrap-race-*`；真实修复回归见 `evidence/6/m2-bootstrap-01/`。限制：这是启动握手，不是持续运行时的异步 NoNew 看门狗。
