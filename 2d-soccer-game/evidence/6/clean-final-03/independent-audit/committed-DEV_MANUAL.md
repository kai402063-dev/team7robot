# TDP 足球迁移开发手册

TDP 是 Team Design Project（团队设计项目）。这份工程把 A 的 4v4、9×6 m 足球算法迁移到纯 MATLAB 算法库、每机器人独立的 Stateflow ControllerCore 和分离的二维环境中。它提供固定输入回放、动作编号/反馈/超时、规则配置、可再生模型及测试证据。**二维圆形代理不是已验证的 NAO6 动力学；Webots 参考机器人最高为 V5，不能把它的结果称为 NAO6 结果。**

读者只需已有 MATLAB/Simulink 基础。先运行下面的一键复现，再按“具体问题→原理与算例→源码→手动操作→预期现象与排错”的章节顺序学习。代码及注释为英文；概念说明为中文。所有“通过”以日志/回执为准，未执行的操作不会因文档写了步骤而变成通过。

当前已恢复执行最终验收；最终M2全量干净clone、完工哈希及baseline-v1标签尚未完成。续接见 [PROGRESS.md](PROGRESS.md)。

## 1. 当前交付层级

| 项目 | 实际达到的层级 | 证据 / 限制 |
|---|---|---|
| 阶段 0 原始基线 | 80 场 × 600 s；20 种种子 × 两种噪声 × 两次完全相同 | `evidence/0/FINAL_RECEIPT_v2.json`；首步与 90 步滚动校核通过 |
| 阶段 1 算法迁移 | 11 个入口各 ≥1000 组；误差 ≤1e-12；screener 零阻塞诊断 | `evidence/1/FINAL_RECEIPT.json`；coder.screener 是代码生成兼容性的静态检查；实际模型编译仍另行验收 |
| 阶段 2 单机 | 实际 Stateflow、延迟执行层、反馈、超时、失败/拒绝、失球/停赛、去重和迟到反馈；两个周期闭环 | `evidence/2/FINAL_RECEIPT.json` |
| 阶段 3 两队 | 8 个 Core、2 个协调器；40 场完整对照；0.05/0.04 s 长跑 | `evidence/3/FINAL_RECEIPT.json`；默认噪声轨迹有分歧，指标一致，见下文 |
| 行为修复 | 接触迭代、同心分离、可选规则、清晰统计含义；先复现再独立提交 | `evidence/3/repairs-02/`；ACompat 仍保留旧行为以便对照 |
| 教学扩展 | 阈值、角色、有限视野、观测延迟/噪声、Tap；两个手搭小模型 | `evidence/6/teaching-02/receipt.json` |
| 阶段 4 MATLAB 在线 ROS 2 / 独立生成节点 | **BLOCKED**：ROS Toolbox、Simulink Coder、MATLAB Coder 未安装，且本任务禁止安装 | 许可测试为 1 不等于产品已安装；不得用 Python 测试冒充这些验收门 |
| 阶段 4 CLI / 代理在线 | 标量回环、101帧原Core在线/离线动作完全一致；年龄适配与变异通过 | `evidence/4/FINAL_RECEIPT.json`；[ROS章节](chapters/ros2.md)，不是原生ROS Toolbox验证 |
| 阶段 5 Webots | 单NAO V5闭环接近/物理踢球；1001帧回放一致；去重/唯一clock/真实相机通过 | `evidence/5/FINAL_RECEIPT.json`；[Webots章节](chapters/webots.md)。原生Read Image仍BLOCKED，动力学未实机验证 |
| 阶段 6 手册 | 本手册、生成数字/图片、测试、手工路径；干净 clone 一键与 API 手搭路径已通过 | `evidence/6/clean-room-01/` 与 `clean-room-02/`；GUI 拖拽未自动验收 |

严格区分三个结论：通信成功只证明数据传到了；动作执行成功只证明执行层按协议结束；模型得到验证还需要与真实机器人/实测数据比较。当前没有 NAO6 实机标定证据。

兼容性结果：零噪声 20 场最大逐元素差异约 5.153e-14，在 1e-12 门限内；默认噪声 20 场最大差异约 0.0246225，不能称为轨迹等价。40 场的进球、射门和首次触球都相同。第一处分歧、原因判断及影响见 [逐场对照](COMPAT_COMPARISON.md)。修复后种子 13 的 600 s 长跑：50 ms 完全受阻请求约 0.068%，40 ms 为 0；两者机器人重叠和越外缓冲边界均为 0。越比赛区边线的采样仍存在，不能把“未越缓冲边界”写成“始终在比赛区”。

## 2. 一键复现

本机工程根目录是：

```text
/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1
```

需要现成 MATLAB R2026b、Simulink、Stateflow；本机还有 Robotics System、Navigation、Image Processing。Python 3.12 和系统已有的 NumPy/SciPy/Matplotlib 用于证据与图片；不改系统 Python，不安装产品。自动流程用独立 `matlab -batch`，不连接已打开的 MATLAB，不弹出模型或绘图窗口。

```bash
cd '/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1'
./scripts/run_matlab.sh "tdpSetup; reproduce_all;"
```

脚本会从空白重建全部新模型，生成手册数字/图片，运行完整基线、算法等价、Stateflow/比赛/修复/教学测试，再检查各套件已有的有效变异回执，随后运行完整M2标准ROS/单动作/Webots闭环、实际相机与回放。不是只跑几秒的快速演示。输出位于新建的 `build/reproduce-时间戳/`；最后一行给出 receipt.json 的绝对路径与实际耗时。**当前M2预期总状态为 `PASS_AVAILABLE_M2_WITH_BLOCKERS_AND_NOISY_TRACE_DIFFERENCES`；二维标签的状态为 `PASS_2D_WITH_DOCUMENTED_NOISY_TRACE_DIFFERENCES`。依赖缺失项仍为 BLOCKED。** 独立干净 clone 的完整二维流程实际运行 1805.77 s（约 30.1 分钟），包含 MATLAB 启动的墙钟时间为 1834 s；手工路径自动验收另用 101 s。证据见 `evidence/6/clean-room-01/FINAL_AUDIT.json`。这份耗时只对应二维标签；当前M2总耗时以最终新clone回执为准。机器负载和编译缓存会影响耗时。

`run_matlab.sh` 默认 MATLAB 安装路径为 `/home/fayne/Applications/MATLAB/R2026b/bin/matlab`。其他电脑先把脚本中的可执行路径改为自己的安装位置，并记录 MATLAB 版本；不要修改源算法来迁就结果。脚本清除终端继承的 ROS 动态库路径和 DISPLAY，使用 `build/matlab-prefs`；`tdpSetup` 将缓存/生成代码放到 build。不会 savepath 或改用户偏好。

需要先看一个具体数值时：

```bash
./scripts/run_matlab.sh "tdpSetup; a=runA(1,0,0.05);disp(a.trace(1,76));disp(a.robots(4).x);"
```

预期值与完整周期表由程序生成，见 [数字算例](generated/manual_numbers.md)。首步为什么得到这些数：前锋距球后接近点 0.55 m，比例增益 0.8 给出请求；执行侧再限速和积分。球模型先减速再积分，因此离散停止距离与连续时间公式不同。若不符，先查运行目录、`which runA -all`、P.dt、随机种子、噪声与轨迹列定义，不要改 reference 原文件。

## 3. 阅读和动手顺序

1. [架构与一个时间步](chapters/architecture.md)：谁保存状态、谁能写球速、Unit Delay 在哪里。
2. [接口契约](chapters/interfaces.md)：坐标、单位、有效性、采集时刻、全部总线/枚举；自动字段表见 [interfaces](generated/interfaces.md)。
3. [模块卡片](chapters/modules.md)：每个模块的任务、A/B 对应源码、数字算例、输入输出、测试、改动方法和限制。
4. [Stateflow 详解](chapters/stateflow.md)：完整状态文字与优先级来自 [生成表](generated/stateflow.md)，实际周期来自 [回放表](generated/manual_numbers.md)。
5. [七条手工复现路径](chapters/handson.md)：函数与测试→闭环延迟→平铺图→层级 Kick/Recover→回放→ROS→Webots。
6. [测试手册](chapters/testing.md) 和 [已做过的扩展示例](chapters/extensions.md)。
7. [原问题与修复边界](chapters/defects.md)、[参数表](generated/parameters.md)、[决策记录](DECISIONS.md)、[真实排错记录](chapters/troubleshooting.md)。
8. [ROS 2标准消息与在线适配](chapters/ros2.md)、[Webots场景/相机/单动作/物理闭环](chapters/webots.md)、[M2实测数字](generated/m2_numbers.md)、[三维参数及假设](generated/webots_parameters.md)。
9. [课程对应与导师问题](chapters/course_mapping.md)、[AI 声明](AI_PROVENANCE.md)。

![脚本生成的比赛快照](generated/match_snapshot.png)

模型的权威来源是 `scripts/build_*.m`。基线之后，改模型应改脚本、重建、测试，并把脚本和生成 SLX 一起提交。`robot-soccer-starter/` 是原仓库历史参考，里面的 SLX 不属于这套新生成模型，不拿它们作为本项目可再生模型的输出。

## 4. 干净 clone：按这份手册独立复现

只使用本地 Git，不推送、不拉取远程、不安装依赖。临时 clone 放在任务 worktree 的 build 下，以符合本任务写入范围。使用一个**尚不存在**的目录，失败也保留它。

```bash
cd '/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1'
git clone --no-hardlinks --single-branch --branch ai-migration-baseline . build/clean-room-final
cd build/clean-room-final
./scripts/run_matlab.sh "tdpSetup; reproduce_all;"
```

随后只按照 [手工路径](chapters/handson.md) 操作；无图形自动验收可运行其等价入口 `build_lessons`、`test_lessons`、`test_controller`，并阅读完整状态文字和接线表。GUI 拖放本身仍是组员练习，不把自动生成图冒充人手拖拽。ROS/Webots路径按新增章节实际运行；原生ROS Toolbox、Read Image及生成节点因产品未装记录BLOCKED。每次命令使用新输出目录；不得启动第二个回放clock源去同时驱动Webots。

记录 clone 的 `git rev-parse HEAD`、MATLAB 版本、开始/结束时间、完整 receipt 路径、遇到的手册缺口。干净复现发现的问题须修正文档或代码后再用新 clone 验证；不要悄悄依赖原 worktree 的 build 缓存。源输入目录哈希见 `evidence/0/inputs-before.json`；完工会再生成 after 清单并比较。

进度和续接入口：[PROGRESS.md](PROGRESS.md)。只读输入的来源快照在 reference；详细哈希在 evidence。大轨迹留在 build，提交证据保留 SHA-256，不把“文件存在”当作测试通过。

实际V5闭环轨迹与相机（均由脚本生成）：

![V5实际轨迹与球速](generated/webots_measured.png)

![ROS订阅到的CameraTop](generated/webots_camera.png)
