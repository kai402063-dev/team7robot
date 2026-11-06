# 怎样知道改动真的工作

问题：测试打印了 PASS，是证明了行为，还是只证明程序没有崩溃？本项目同时保存功能断言、随机/边界对照、完整比赛指标和变异检查。变异检查是故意改坏一处，再确认测试会失败；一个只会一直通过的测试没有诊断价值。

## 运行方式

在根目录运行新的批处理进程：

```bash
./scripts/run_matlab.sh "tdpSetup; assertSuccess(runtests('tests/test_controller.m'));"
./scripts/run_matlab.sh "tdpSetup; assertSuccess(runtests('tests/test_manual_numbers.m'));"
```

首次使用或改了建图脚本，先 `tdpSetup;build_all;export_manual`。一键复现已经包含这些步骤。每个 `validate_*` 的输出目录必须新建，不能指向已有尝试目录。failed 与 incomplete 分开：断言不符合是行为失败；解析/编译中断可能使测试根本没走到验证步骤。

| 套件/运行器 | 证明什么 | 不能证明什么 |
|---|---|---|
| test_baseline / validate_stage0 | 首拍、球滚动距离、固定种子完全重放；80 场完整运行 | 原算法正确或物理真实 |
| test_algorithms / validate_stage1 | 每入口 1000 组新旧数值对比，踢球噪声样本相同；screener | 策略好坏、生成独立 ROS 节点 |
| test_actuator | 编号去重、拒绝、失败、取消、有效期、采集时间 | 三维动作成功 |
| test_controller | 实际 Stateflow 完成/失败/拒绝/超时/失球/停赛/迟到反馈、确定性、单机闭环两周期 | 真实相机识别、硬件稳定性 |
| test_match / validate_stage3 | 奇偶仲裁、8 实例短程对照、40 场指标与首处分歧、600 s 几何统计 | 默认噪声轨迹完全等价 |
| test_source_defects | A 原问题和 B 原状态片段的可执行复现 | 完整旧 B 模型的所有行为 |
| test_repairs / validate_repairs | 可选接触与重开修复、ACompat 保留、两周期长跑 | 完整 RoboCup 规则或三维碰撞 |
| test_lessons | 手工闭环的解析序列、平铺状态图序列 | 已由人手拖拽 GUI |
| test_extensions | 五种实际扩展、初态重置、未知参数拒绝、真实核心的延迟回放 | 延迟/噪声已接入所有八机器人比赛 |
| test_ros_adapter | 重复/乱序/未来/过期包、时钟、反馈及实际Core回放 | 原生ROS Toolbox和独立节点 |
| test_camera | 固定BGRA字节的通道、像素、尺寸和错误码 | 识球/定位/原生Read Image |
| test_webots.py | motion去重、有效期、排队、取消、实际场地和motion文件 | 接触是否真的发生；需物理集成验证 |
| validate_ros.py | 实际CLI标量、101帧ROS/在线/离线全动作、诊断主题 | 机器人动力学 |
| reproduce_m2 / analyze_webots | 单V5实际接近和物理球位移、唯一clock、实际相机、录制输入回放 | NAO6实测及多机器人 |
| test_manual_numbers | 生成数字与当前执行结果相同、表格包含这些数字、参数表一致 | 每个说明文字都没有歧义；还需干净阅读复现 |

“每函数 1000 组”包含随机和定制边界：零距离、角度跨界、刚好门线/门柱、重合机器人、准备踢球。结构体和枚举按字段比较，浮点容差 1e-12；离散身份/状态应精确相同。测试注入样本不使用一次随机结果去对比另一次随机结果。

## 变异怎么重跑

历史有效回执按 suite 关联，`python3 scripts/verify_mutations.py` 检查每个 test_*.m 至少有一个实际断言检测到的变异。重新实验可以附加唯一后缀，副本与日志写入 build：

```bash
python3 scripts/mutation_check.py scripts/mutation_match.json lesson01
python3 scripts/mutation_check.py scripts/mutation_repairs.json lesson01
```

不要反过来修改 reference 源输入。变异脚本在独立副本修改代码、启动新 MATLAB；未到达断言的编译失败不计为有效变异。曾有接触变异被收敛保护提前报错、以及控制器旧变异遇到编译问题，均保留 NOT_QUALIFIED 说明，后来换为能到达测试断言的变异。

## 新增一个测试

1. 写明具体失败：例如“编号 9 的 Done 不能结束编号 10 的 Kick”。
2. 固定观测、反馈和 tSim；尽量不要依赖 600 s 比赛碰巧遇到它。
3. 先复现旧行为或让目标断言失败，保存日志；再改行为并单独提交。
4. 在默认和边界周期运行，检查输出、状态和编号；检查无反馈路径。
5. 选择一个相关变异，确认断言会失败。将新的 suite 加到复现流程和变异审计，不只手动执行一次。

指标解释：overlapSteps 是至少一对机器人穿透超过 1e-8 m 的时间步；outsidePitchRobotSamples 计圆盘越比赛区的机器人采样；outsideBorderRobotSamples 计越外缓冲区；blockedTranslationRatio 只统计有平移请求但最终无位移，限速不等于受阻。完整统计定义在 `scripts/matchMetrics.m`。

## M2回归和变异

仅重跑M2时：`./scripts/run_matlab.sh "tdpSetup;reproduce_m2('build/m2-review-01');"`。这仍启动真实ROS/Webots和独立MATLAB子进程，不是mock。完整一键会先完成二维所有门再调用它。子进程使用独立的build缓存和偏好目录，端口29741及域97同时只运行一套实验。

```bash
python3 -m unittest discover -s tests -p test_webots.py -v
python3 scripts/mutation_check.py scripts/mutation_ros_adapter.json review01
python3 scripts/mutation_check.py scripts/mutation_camera.json review01
python3 scripts/mutation_check.py scripts/mutation_manual_m2.json review01
./scripts/run_ros.sh python3 scripts/mutation_ros_integration.py review01
python3 scripts/mutation_webots.py review01
python3 scripts/mutation_webots_trace.py review01
```

最后一个只在明确标注的测试副本里把录制球轨迹固定，保留motion结束；要求物理位移门失败。它不是物理运行数据，不可把变异副本作为成果。手册测试从提交的真实1001帧记录重算数字，并实际重放Core；最终干净复现还会新运行完整物理闭环，不只比较历史回执。

最终审查加强了真值隔离证据：测试先由Observation2D生成并固定观测，再改变世界机器人/球并保持原观测，输出应相同；重新采样改变后的世界时，输出应不同。它还断言Core只有obs、intent、feedback、tSim四个输入。此前仅改变未使用局部truth变量的测试不足以单独支持这个结论，保留旧日志，新增验证另存。

最终验收层还有 `tests/test_validation_receipts.m`：它故意制造相机编码错误、录制动作不一致及筛查阻塞，检查机器可读回执不会把失败写成 PASS。对应变异为 `scripts/mutation_validation_receipts.json`。原始缺陷复现、修复后 8 项测试和实际算法筛查见 `evidence/6/audit-receipts-before-02/`、`evidence/6/audit-receipts-after-01/`；最初因测试目录导致的未完成尝试也保留，不计通过。

## 只验球队 V1

在工程目录执行 `./scripts/run_matlab.sh "tdpSetup; reproduce_v1;"`。该命令重建八机器人模型，在终端给出最终回执路径。`test_v1_tactics` 用镜像输入、阈值边界和错号反馈检查队级分工。`test_v1_model` 在真正的 Stateflow 与执行层之间注入故障，检查从原始意图到真实球运动的过程。`test_v1_matrix` 检查逐场指标如何检出未获授权的请求。每个套件均有只作用于副本的变异测试，能区分测试断言失效和模型未完成编译。[行为章节](tactics_v1_design.md) · [实际动作时间线](../generated/v1_model_events.md)

复现全部比赛后，先看输出目录根部 `receipt.json`，再读 `summary/receipt.json` 的 `periods` 与 `matches`。种子和周期可定位到 `matches/dt…-seed…/receipt.json`，其中 `parameters` 给出完整配置，`violations` 给出首次违反的门、步号与列。大矩阵留在本机 `build/v1-matrix/`，`artifact.json` 同时记录 MAT 文件及数值数组的 SHA-256。接收者用自己生成的数值数组摘要核对轨迹；MAT 容器包含独立生成的元数据。
