# Webots：一个球、一台 NAO V5 的物理闭环

## 先看具体问题

在二维里，Actuator2D 可以根据模型写球速；三维中必须让足部碰到球。`Shoot.motion` 到末帧，只能证明动作结束。本项目做了两个实际实验：原地单动作结束但远处球不动；原控制器先接近球再执行动作，球确实从静止开始移动。结果和采样时刻见生成的 M2 数字表，不把这两类结果混为一谈。

实际球速图还揭示本场景的滚动衰减不足：球被踢动后在记录区间几乎保持恒速。Webots ContactProperties 的默认 rollingFriction 为0（本机节点定义），本基线未把二维估计减速度0.4 m/s²映射成已标定三维接触参数；该项保留为物理模型限制和后续标定工作。

机器人是 Webots R2025a 的 Nao H25 **V5**，不是 NAO6。定位使用明确标注的 Supervisor 真值读取，尚未实现视觉定位/识球。速度、球质量和接触参数没有实机标定；成功的仿真闭环不是模型得到验证。

## 场景、运动和参数属于谁

`reference/kidsize_pitch.wbt` 是小组只读文件的副本，`scripts/check_pitch.py` 读取实际 DEF 节点里的 translation 和 Box 尺寸，按标线外沿计算比赛区，按门柱内面计算净宽、横梁底面计算净高。Grass 的盒体顶面是地面；不能把11×8的草坪当作9×6的比赛区。原场景没有写 basicTimeStep，派生场景明确补入20 ms；控制采样40 ms即每两个物理步一次。

`scripts/build_webots.py` 生成 `webots/worlds/tdp_single.wbt`，保留原场地全部标线、球门和看台，只添加一个 Sphere 球和一个 Nao。机器人平移初值和球初值只在场景文件中定义。运行时 Supervisor 只调用 getPosition/getOrientation/getVelocity 等读取方法；没有 setVelocity、位置重置或把球绑在机器人上。电机由现成 motion 驱动，末尾 simulationQuit 仅结束本次进程。

参数源为 `config/webots.json`；源码表中的未知参数仍保持 null。球质量是显式教学假设，不能把本次成功倒推为这个质量真实。接触参数参考本机 nao_demo.wbt；请求速度只用来选择运动方向，motion的实际速度没有标定。详细来源、单位、状态见生成参数表。版本、40 ms接口、相机固定尺寸若改变，应先改契约和测试，不接受静默截断。

`webots/motions/SOURCES.json` 记录每个复制的原 motion 来源、哈希和末帧时间。Nao PROTO/网格依赖 Webots 的 R2025a远程资源或既有缓存；启动器将现有缓存复制到本任务build内，绝不写原缓存。其他机器可设置 TDP_WEBOTS_HOME 和 TDP_WEBOTS_CACHE；没有这些资源时需先提供现成Webots环境，不能以空机器人替代验收。

## 一个物理步的实际顺序

1. Webots `robot.step(20)` 运行物理；读取 `robot.getTime()`，发布唯一 `/clock`。
2. 只读获取机器人、球和姿态；执行器检查当前motion是否到末帧以及直立判据。
3. 每40 ms采样一次相机/观测，给每份数据填真实采集时刻。初始稳定期间不发控制观测。
4. `/tdp/observation`→Python代理→Simulink的BridgeDecode和原ControllerCore→`/tdp/request`。
5. 执行器按requestId接受、拒绝或忽略重复请求；下一物理步才看到运动结果。期间等待网络时暂停推进物理时间，属于锁步仿真，不声称满足实机实时延迟。

初帧会等待相机观察进程完成ROS图证据，再继续控制。它不改tSim，也不提前推进机器人。第一次已结束的Shoot之后，本单次实验把gameRunning设为false，以便记录球后续运动并结束试验；不是完整比赛裁判实现。

## 执行层卡片

`ros2/tdp_webots_bridge/tdp_webots_bridge/motion_executor.py` 管电机动作，属于环境侧。输入是11项请求和当前仿真时间；输出是同号反馈及实际motion事件。ControllerCore仍只看到观测和反馈。

| 情形 | 实际行为 |
|---|---|
| 新的行走请求 | 保存方向和validUntil；当前有限motion结束后选择下一段 |
| 行走过期 / Stop | 停止当前motion；Stop也取消技能并反馈Failed |
| 新Kick | 记录Running；若仍在走，等当前段末帧，再启动Shoot |
| 重复requestId | 不重新play、不延长有效期；已结束后仍不能重启同号动作 |
| 迟到编号、过期/未来请求、忙时新技能 | Rejected；保持正在执行技能的反馈归属 |
| Shoot末帧 | Done，同号；另行记录球位置，不自动宣称踢中 |
| 直立判据失败 | Failed并停止motion；该判据是教学设置，不是NAO6摔倒检测器 |

当前执行器把Tap也映射为同一个Shoot，不能宣称三维已实现轻踢；本次闭环只验证Kick，Tap扩展示例的验收在二维。需要三维Tap时，应增加并实测不同运动文件。

Forwards、Backwards、SideStepLeft/Right、TurnLeft/Right40按归一化速度分量中的最大项选择。它不是连续速度跟踪器；切换可能等一个motion周期，控制精度和反应速度有明显限制。本版本只验证单机器人受控场景，不用于真实机器人安全控制。

## 手工路径A：读场地和相机

先从工程根目录执行，输出目录每次换新名称：

```bash
python3 scripts/build_webots.py
python3 scripts/check_pitch.py webots/worlds/tdp_single.wbt
./scripts/run_ros.sh python3 scripts/run_webots.py build/webots-camera-01 --mode probe
./scripts/run_matlab.sh "tdpSetup;validate_camera('build/webots-camera-01','build/webots-camera-01/decoded');"
```

打开 JSON 中的width、height、encoding、step、stamp、sha256，与实际 `/tdp/camera/top/image_raw` 消息比较。`camera-ros.bgra`来自真正订阅到的ROS Image；不是为测试合成的图。`decoded/camera.png`应能看到场地/对侧球门。解码模块 `DecodeBgra` 把[4,width,height]数组排列成[height,width,3]，并选择BGR中的RGB次序。两个相邻已知像素的测试同时检查通道顺序和行列顺序。

| 解码输入/输出 | 固定设置 |
|---|---|
| bytes | uint8，共76800；BGRA每像素4字节 |
| width / height / rowStep | 160 / 120 / 640 |
| encodingCode | uint8(1)表示bgra8，其余报错 |
| rgb | uint8，120×160×3 |
| ErrorCode | 0成功；1编码；2尺寸/步幅；3字节长度/类型 |

此ErrorCode属于本项目固定相机适配器。ROS Toolbox Read Image未安装，**原生块的ErrorCode验收保持BLOCKED**，不使用相同字段名混淆验证对象。改变分辨率必须同时修改固定维度、字节数、步幅与测试。

完成后应能解释：为什么相机通信/解码成功仍不能证明识别出球？为什么采集时刻不能写成收到消息的时间？

## 手工路径B：只执行一个动作

```bash
./scripts/run_ros.sh python3 scripts/run_webots.py build/webots-motion-01 --mode motion
```

这个实验不启动MATLAB策略，只给执行器同一个Kick请求并重复投递，球仍在初始远处。查看webots-receipt中的motion_start、motion_end、executions和kickResults。应看到动作结束而球未动；这条路径用来学执行协议，不用它替代闭环验收。若重复请求使executions增加，检查seen_id判断；若动作不结束，检查已有motion末帧时间、是否误设Loop=true以及是否一直setTime(0)。

## 手工路径C：接上原控制器

先按一键流程生成SLX；然后：

```bash
./scripts/run_ros.sh python3 scripts/run_webots.py build/webots-closed-01
python3 scripts/analyze_webots.py build/webots-closed-01 --output build/webots-closed-01/analysis.json
./scripts/run_matlab.sh "tdpSetup;validate_webots_replay('build/webots-closed-01','build/webots-closed-01/replayed');validate_camera('build/webots-closed-01','build/webots-closed-01/decoded');"
```

分析脚本分别断言：1001帧/40 ms、有限值、逐拍及CLI的单clock发布者、接近进展、同号一次物理启动、motion结束、原先静止的球在Shoot期间加速并位移、机器人直立。随后把实际Webots观测离线重放，要求动作与在线Simulink完全相同。精确物理轨迹只对当前Webots/软件渲染环境记录；其他平台要报告实测差异，不把展示数字当跨平台位级保证。

生成图和数值在 `docs/generated/`。看结果时区分20 ms动作事件时刻和其后首个40 ms观测时刻；二者球位置会不同。测试手册中的变异把录制球强行固定，保留“motion已结束”，分析必须失败，证明它没有只检查Done。

## 从真实故障开始排错

- Qt报告xcb加载失败：本机Webots启动脚本强制QT_QPA_PLATFORM=xcb；本项目调用实际bin/webots-bin并设置私有Wayland环境。不要改系统脚本。
- DBus绑定失败：沙箱禁止socket，需要主机独立进程；没有sudo/安装步骤。路径含空格与&必须按地址规则编码。
- 深层clone的Unix socket路径过长：私有显示使用指向本任务目录的进程目录FD短地址，真实写入仍在build；XDG_RUNTIME_DIR保持真实目录，避免Qt把符号链接当异常。
- `ros2 topic info /clock`暂报Unknown：实际遇到发现时间不足。现在不用旧daemon，明确等待发现，保留每次查询文本，并在图证据准备好后继续物理。
- 软件渲染/无音频/计分板纹理警告：本机真实遇到，保留日志；不影响已经通过的相机/物理验收。缺失计分板贴图没有通过修改原场景来掩盖。
- 自定义解码ErrorCode非0：先查encoding、宽高、step和字节数，勿仅按颜色猜。

后续多机器人需要命名空间、每机器人实例和编号会话标识、共享唯一clock、团队协调器和真实观测融合；还需以实测替换球质量/接触/运动速度估计，验证V6模型与实际NAO6。不能直接复制八个Supervisor真值闭环就宣称完成课程的感知与硬件验证。
