# 已交付：红蓝单队对照

在冻结提交 `3c2d7dc` 的干净克隆中，先完成仅红队自动的 40 场，再完成仅蓝队自动的 40 场，另有 4 场整场重复回放。复用原有 80 场参考回放并在分析时逐场核对其哈希。20 个种子分别在 50/40 ms 下运行各 600 s。调度、参数、校验与运行方法见[单队对照章节](chapters/team_ablation.md)。

- 双方默认、仅红自动、仅蓝自动、双方自动的红队总进球分别为 14、1、3、0。按两种顺序平均，红队策略对应少 8 球，蓝队策略对应少 6 球，交互项为 +10 球。50 ms 时红队影响略大，40 ms 时双方相同。[两队授权、射门和进球](generated/team_ablation.md)
- 只改红队，红队射门降到 228；只改蓝队，红队射门升到 2,263，但先碰蓝方后卫的比例升到 98.67%。这两条路径都能大幅降低得分。逐场结果、单侧授权与首次触球口径均有独立核对。
- 边界模型、混合时的故障隔离、错号反馈与变异均通过。只读输入 14 组 818 个文件的开工/完工 SHA-256 相同。实验覆盖固定左右侧的二维自对赛。小组可以据此决定是否另做阈值、站位或换边实验。

# 已交付：独立的自动交还实验与双击入口

打开 [README 的图形启动说明](../README.md)。球队 V1 仍是默认选择。自动交还是基于 V1 的小组实验，有独立图标与 MATLAB 编辑器入口。历史标签 `baseline-2d-v1`、`baseline-v1` 继续标记原迁移交付。本轮在相同本地分支上追加提交。

- 原始行为复现 `ba985b7`，仿真代码与模型 `703099d`，编辑器快捷入口及独立读者起点 `0c22951`。正式新克隆中 54 项测试、80 场各 600 秒、另外 4 次全长重复回放通过。40 场默认 V1 的物理和战术数组均与冻结参考逐场一致。
- 实验 128 次自然接管全部交还。两队合计的中场接管时间占比从 51.61% 降至 0.15%，相同种子下总进球从 22 降至 7。两种策略第一次出现轨迹差异的时刻都在首次中场接管之后。常规整场未出现交还时的中场在途出脚或同编号取消，该分支另由 32 个定向场景覆盖。[比赛结果及重叠、越界、受阻数据](generated/recovery_results.md)
- 两个图标的真实启动命令和 MATLAB 实验无参入口均在独占显示中开窗并关闭。首次实验图标验收在并发冷编译时达到看护时限，保留失败回执；原时长和采样数复验通过。[图形操作和回执](chapters/live_animation.md)
- 新增三套测试各有变异检出证据。只读输入开工和完工 14 组、818 个文件的 SHA-256 一致。实验范围为二维。实机执行器如何提供可靠的 ready/终态反馈、以及是否采用自动交还，留给小组和导师决定。原 M2 的 ROS Toolbox 和 Coder 依赖阻塞继续记录在[开发手册](DEV_MANUAL.md)。

## 之前交付记录

# 球队 V1 和实时二维比赛已交付

从 `./start_2d.sh` 可以直接观看 V1。完整复现用 `./scripts/run_matlab.sh "tdpSetup; reproduce_v1;"`。正式干净克隆用时约 14 分 35 秒。战术实现 `ca87cb1`，含暂停修复的最终可执行提交 `a324545`，分支 `ai-migration-baseline`。原 M2 与二维基线标签分别为 `baseline-v1` 和 `baseline-2d-v1`。[十秒上手](chapters/tactics_v1_design.md#无窗口运行十秒并找到日志)

- 25 项定向测试、20 个种子 × 两种控制周期 × 600 秒均通过，540,000 步共 6,727 次实际踢球。12 场有进球，共 22 球。首场 109 次蓝方射门均遇到红方后卫的接触。[整场成绩与限制](generated/v1_results.md)
- 两个周期都验证了同种子整场回放。发布代码从另一个干净克隆再跑相同 40 场，80 对物理和战术数组逐元素完全相同。旧 ACompat 另跑 40 场，三项兼容指标全部复现，保留默认噪声轨迹差异说明。
- 新读者独立完成两个十秒实验并从逐场文件重建正式汇总。9 项手册校验全过。真实窗口的启动、暂停确认、继续、重开和关闭通过。重现过早显示暂停的变异只触发对应测试失败。
- 14 组共 818 个只读输入文件的开工和完工 SHA-256 一致。未安装产品，提交只保存在本地分支。此前原生 ROS Toolbox 和两个 Coder 的门仍为 BLOCKED。球队 V1 的范围止于二维，NAO6 动作和接触参数仍待实测。
- 待小组决定的战术问题是用什么可观测信号确认 ST 已恢复。当前配置需要显式恢复；常规比赛中的 MF 接管可能持续到终场。中线滞回和自由球条件可按[参数表](generated/v1_contracts.md)调整后重新验证。

## 之前交付记录

# 已交付：M2 可用基线与开发手册

本地交付标签 baseline-v1；二维冻结标签 baseline-2d-v1。分支 ai-migration-baseline，工作目录为本文件所在工程。验证的可执行代码是1f52c4c；其后只有文档和证据更新。没有安装产品，没有push或PR。

- 最终全新clone完整一键通过，墙钟2429.332秒；12条成功手工命令合计638.053秒。最终汇总 evidence/6/FINAL_RECEIPT.json，独立审计 evidence/6/clean-final-03/final-manual/independent-audit-03/FINAL_AUDIT.json。
- 阶段0/1/2通过；阶段3零噪声容差内、默认噪声轨迹有已记录分歧，40场进球/射门/首次触球一致。修复、教学、数值及变异验证通过。
- ROS标准消息代理与单V5 Webots可用门通过，1001帧回放精确、相机ErrorCode0、唯一clock、一次物理踢球和真实球位移均有证据。原生ROS Toolbox/Read Image/独立生成节点仍BLOCKED。
- 14组818个只读输入文件的开工/完工哈希完全一致。任务实验进程/ROS daemon/29741端口已清理；可能被用户MATLAB共用的ServiceHost/Monitor保留。
- 未验证：GUI拖放动作、持续clock下的异步NoNew看门狗、NAO6实机动力学/感知识别；二维/三维物理参数仍需标定。阶段5只含单机器人。

组员从 docs/DEV_MANUAL.md 开始复现；需要小组/导师确认的规则、理想观测/集中协调、V5/真值定位可接受范围、实测参数及今后产品安装授权见 docs/chapters/course_mapping.md。后续工作需单独确定这些范围；当前已授权的可用交付工作完成。

## 开发、暂停和续接历史

# 最终手工路径续接中

用户已继续。代码仍为1f52c4c，根分支检查点c2aec7f，完整一键/API/标量已通过。第二次续接的ros-online-02未写结束回执且协调器/validator进程已不存在，原因未知；不能算PASS或行为FAIL。保留原RUNNING记录，解释见evidence/6/resume-interruption-02/receipt.json。

新的独立复现 manual_final_resume 已接手，只按clean-final-03手册在新目录完成剩余ROS/Webots手工路径。域97/端口29741独占，不修改源码、不重复完整一键。等待最终回执后归档、末次14根输入哈希、完成文档和baseline-v1。禁止安装/push/PR。

## 续接历史

# 已恢复：完成剩余手工路径及最终交付

用户已明确继续，第二次暂停撤销。代码目标仍为1f52c4c；c2aec7f是文档/证据检查点。final_manual_reproduction在build/clean-final-03续接，使用新尝试目录重新运行被中断的手工ROS在线回放，随后完成Webots手工路径。已通过的完整一键、手工API、构建和标量回环不重复。

随后汇总最终证据、更新手册实际耗时/状态、末次14根只读输入哈希、本地最终提交与baseline-v1。缺产品门仍BLOCKED；不安装、不push/PR。旧暂停和失败记录保持原样。

## 第二次暂停记录（历史）

# 已按用户要求暂停

2026-11-05，用户要求尽快暂停。不得自动继续或启动新测试；等待用户明确继续。

- 最新可执行代码提交：1f52c4c6903e80817d2f80bce5795cab2dcda4d7；分支 ai-migration-baseline。
- 最终全新 clone build/clean-final-03 的完整 reproduce_all 已通过，墙钟2429.332秒；证据 evidence/6/clean-final-03/artifacts、command.json、matlab.log。全部可用M2门通过，依赖阻塞与默认噪声轨迹差异仍明确保留。
- 独立手工 API 路径通过，墙钟181.211秒：函数与变异、自建延迟/平铺/层级图、自建回放及半超时影响验证、controller8/lessons3/adapter5均通过。GUI拖放未执行。
- 手工ROS构建与标量3.5→4.5已通过；在线回放 ros-online-01 按用户要求中断，记PAUSED（原命令exit -2是SIGINT，不是行为失败）。后续Webots手工实验均未启动。任务子进程已全部退出，remainingOwnedLivePids=[]；详见 evidence/6/pause-02/receipt.json 和 clean-final-03/independent-audit/PAUSE_STOP_RECORD.json。
- 继续后先读暂停回执并核对进程/手工pipeline状态；只完成剩余手工路径，不重复已通过的一键流程（除非新增代码修复或新失败确有需要）。随后归档独立最终审计、末次14根输入SHA-256、更新手册耗时/状态、本地阶段6提交和baseline-v1。
- baseline-2d-v1已存在；baseline-v1尚未创建。完工输入哈希尚未执行。保持不安装、不push/PR；原生ROS Toolbox/Read Image/生成节点BLOCKED，V5不代表NAO6模型验证。

## 暂停前进度（历史）

# 最终一键复现已通过，独立手工路径验收中

代码目标 1f52c4c6903e80817d2f80bce5795cab2dcda4d7；build/clean-final-03 全新clone零缓存完整 reproduce_all 已通过。2026-11-05 22:16:25→22:56:54 UTC，墙钟2429.332秒，流程内部2375.581秒（最终以command.json/receipt.json原值为准）。证据已归档 evidence/6/clean-final-03/artifacts 与 matlab.log、command.json。

- 阶段0/1/2通过；阶段3完整40场，零噪声容差内、默认噪声轨迹分歧如原记录，所有进球/射门/首次触球一致；修复、教学、手册与验收回执测试通过。
- M2真实ROS、motion201帧和闭环1001帧、实际相机ErrorCode0、精确动作回放通过。轨迹SHA与之前成功试验一致，启动修复未改变物理轨迹。
- final_manual_reproduction 继续新MATLAB进程手工API路径及ROS/Webots手工命令；尚未写最终手工PASS。域97/端口29741留给该复现，不启动竞争实验。
- 之后：归档独立最终审计；末次14根输入SHA-256；更新入口/耗时/状态；本地阶段6提交和baseline-v1。不安装，不push/PR。
- 原生ROS Toolbox / Read Image / 两Coder生成节点仍BLOCKED；V5不是NAO6验证，异步NoNew看门狗未验证；默认噪声轨迹非完全等价。已有baseline-2d-v1，baseline-v1仍未创建。

## 本轮验收历史

# 启动竞态已修复，最终复现重新执行中

当前分支 ai-migration-baseline；已有 baseline-2d-v1。最终 baseline-v1 尚未创建，不得把本次失败写成全量通过。

最新代码 1f52c4c6903e80817d2f80bce5795cab2dcda4d7。独立复现已在 build/clean-final-03 零缓存全量复现，2026-11-05 22:16:25 UTC 开始，exec session 85960，日志 build/clean-final-03/build/independent-audit-03/matlab.log。独立缓存 M2 预检已通过，exit0、440.865497 s：evidence/6/m2-bootstrap-01/receipt.json 与 artifacts。motion201帧、闭环1001帧、物理球位移/唯一clock/相机ErrorCode0/回放一致；闭环轨迹SHA与前次成功试验完全相同。域97/端口29741已释放供最终clone使用。

- 最终目标 3334d3c 在 build/clean-final-02 完整运行至 M2 motion，2026-11-05 22:07:57 UTC 失败（总墙钟 1923.331 s）。阶段0/1/2通过；阶段3完整40场指标一致、默认噪声轨迹分歧如记录；修复/教学/手册/回执测试和ROS101帧通过。
- 失败归档 evidence/6/clean-final-02-failed/artifacts。motion 0帧/0动作，报 No ROS graph evidence receipt；观察器未收到第一帧图像。实际相机buffer已有，但不是ROS接收成功。
- 源码显示首次volatile相机publish后即等待graph-ready；该回执又依赖观察器收到首帧。DDS发现慢导致首帧丢失是证据支持的启动竞态判断。delivery_audit 正先加可控延迟发现复现测试，再修 bootstrap 重发同stamp图像/clock，保留物理时间和控制逻辑。
- 启动握手回归已完成：Python 9/9 通过，旧策略两个断言失败，删掉相机重发的源码变异有效；evidence/6/ros-bootstrap-race-after-02 与 mutation-02。新增两项墙钟参数已由脚本生成进参数表。绘图缓存也已明确隔离到 build/matplotlib，两个生成器验证通过。
- 下一步：专门修复提交→并行开始新clone全量及M2预检（各自缓存，ROS运行错开）→手工路径→末次14根输入SHA→最终文档与baseline-v1。失败日志永久保留，不缩短全量。
- ROS Toolbox / Simulink Coder / MATLAB Coder 禁止安装，相关原生块、Read Image、独立生成节点仍 BLOCKED。连续clock的NoNew看门狗未验证；不push/PR。

## 历史进度

# 继续执行最终验收

状态：ACTIVE。用户已要求继续。暂停回执保留；M2使用新目录重跑，随后完成最终独立干净复现、末次输入哈希及baseline-v1。

工作区：`/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1`；分支 `ai-migration-baseline`。
已存在标签：`baseline-2d-v1`（187bdaf）。阶段4提交b8d4b6e，阶段5提交5662406。

## 当前成果与限制

- 阶段0–3及二维独立干净复现已通过；默认噪声轨迹有已披露分歧，40场指标一致。
- 阶段4：真实标准ROS标量/101帧原Core在线离线一致、年龄处理、变异通过。
- 阶段5：真实单V5接近/物理踢球、1001帧离线回放完全一致；实际相机自定义ErrorCode=0；唯一clock、去重、动作结束/球移动分别验证。
- ROS Toolbox及两个Coder未装、禁止安装；原生在线块/Read Image/生成节点BLOCKED。没有NAO6实机或动力学验证。
- M2手册/数字/配图已生成，5项手册测试通过；M2数字变异检出。
- 完整M2组合第一轮因ROS CLI发现不足失败，已归档。第二轮 `build/m2-integrated-02` 到Webots阶段；用户要求立即暂停，未完成验收不能记PASS。中断回执：`evidence/6/PAUSE_RECEIPT.json`。

## 续接顺序

1. 先查看暂停回执及 `build/m2-integrated-02/receipt.json`、`evidence/6/m2-integrated-02/matlab.log`，不得覆盖现有尝试；新运行用新目录。
2. 完整M2组合：`./scripts/run_matlab.sh "tdpSetup;reproduce_m2('build/m2-integrated-03');"`。ROS CLI已统一3s发现并保留最多3次查询。
3. 私有Wayland已禁用不必要的DBus门户自动激活，display-05 OpenGL通过；清理了旧任务目录的失效FUSE挂载，记录在evidence/6/portal-cleanup-01.json。若仍有挂载只处理本任务build路径，绝不操作用户/run/user/1000/doc。
4. 完成后归档M2证据，提交review目标。启动新的无上下文读者，只读docs/DEV_MANUAL.md，在build下全新clone，用新的MATLAB进程运行完整reproduce_all及手工路径；二维约30分钟，M2另计。最终独立M2全量clone尚未启动。
5. 修复独立读者发现的问题，写入手册与真实耗时。最后重算14个只读输入根SHA-256，与evidence/0/inputs-before.json比较；完工哈希尚未执行。
6. 最终提交阶段6，打baseline-v1；不安装、不push、不PR。

运行缓存/偏好均在build。新ROS/Webots子MATLAB进程已分配独立cache ID/prefs。模型权威是scripts/build_*.m；M2数字权威是manualM2Measurements和真实录制。三维球滚动衰减不足已在手册明确，不把可运行仿真写成实机模型验证。

---

以下保留此前开发记录：

# 迁移进度

阶段 0–3、第一次阶段 6 已完成；baseline-2d-v1 已创建（187bdaf）。正在执行阶段 4。

- 基线 e87bcbb；算法 4596ec5；单机 3456e7b；兼容 48cc9d6；原缺陷 d1afab9；修复 4e98da7；手册/示例 be3fc7c；边界失败 ae03d77；接口与手搭外壳修订 31e82e0。
- 独立无上下文复现固定 be3fc7c，位于 build/clean-room-01；完整一键 1805.77 s（墙钟1834 s）通过。第二新 clone 31e82e0 的24项针对性测试通过；自建7状态14转换的图回放通过，原库未改。首次API删图审计错误保留，重试63.7 s通过。证据归档 evidence/6/clean-room-01、02。
- 修订修复了转换条件不能复制、测试名错误、手搭图未明确接入回放；新增 myKickReplay 外壳和自身图修改影响输出的测试。
- 边界修复：未知空参数显式报错；无效障碍物采集时间被忽略。18 项扩展/控制器回归通过；有有效变异。
- 下一步：阶段 4 标准消息回环、纯适配和复用 Core 的在线代理；原生 ROS Toolbox/独立生成仍 BLOCKED。

## M2 的只读预研记录（均不是运行通过）

- ROS Toolbox / Simulink Coder / MATLAB Coder 未装，ALLOW_INSTALL=否。原生 ROS Toolbox 在线路径和生成独立节点保留 BLOCKED。可先做标准消息的 CLI/Python 回环和数据年龄适配测试。
- 待实施方案：Python rclpy 标准消息代理通过本地同步 socket 向新的 Simulink 外层模型提供输入，复用原 ControllerCore；与同一输入的离线外层模型比较。不得把这种替代传输写成已验证原生 ROS Toolbox 或生成节点。
- Webots 本机只提供远程/缓存 Nao.proto，版本最高 V5。缓存原文在 /home/fayne/.cache/Cyberbotics/Webots/assets/0c0592a6f184181e38bc205eeb8db16c9c128167；只读，不写原缓存。正式试验应隔离 XDG 缓存/配置到 build。
- 已读实际 motion：Shoot 结束时刻 4.800 s；Forwards 2.600 s。三维超时需独立明确配置，不能沿用二维 1 s 后误判。
- 无 Xvfb / Xvnc / weston；已有 gnome-shell 支持 --headless --virtual-monitor，Webots 自带 Wayland 平台插件。可尝试任务私有 DBus + 无窗口虚拟 Wayland；不替换用户窗口管理器，不用 --replace。不同思路仍失败三次则记录 BLOCKED。
- 场地必须从 reference/kidsize_pitch.wbt 派生，写 basicTimeStep=20 ms，控制40 ms；只建一个球与一台 NAO V5。GPS/Supervisor 仅读真值，严禁写球速。球质量仍未知，若要运行必须在参数文件显式选择教学假设并保留待测状态。
- 只有一个 /clock 发布者；相机默认160×120、bgra8。motion结束与球真实位移分别记录；V5结果不称NAO6验证。

不安装、不推送、不开 PR。结束前仍须重算14个只读输入根的SHA-256，与 evidence/0/inputs-before.json 比较。

## 阶段 4 当前工作

新增 BridgeDecode / tdpFrameReplay / tdpRosProxy，以20双精度观测帧经标准 Float64MultiArray 复用原 Core。原生 ROS Toolbox 和独立生成不解阻。第一次沙箱 MATLAB 无输出退出，第二次发现模板结构体不支持编译期增字段，已改固定结构构造；第三次实际测试运行中。Python标准消息代理、CLI标量回环和101帧在线/离线对比脚本已写，尚待实际运行。所有尝试在 evidence/4。

阶段4完成：5项适配测试通过，101帧真实ROS/在线Simulink/离线动作完全一致，CLI标量3.5→4.5，诊断主题逐项通过，/clock发布者1。新包colcon构建成功；年龄变异真实断言失败已检出。回执 evidence/4/FINAL_RECEIPT.json。下一步阶段5，尚未启动Webots或改其用户配置。

## 阶段5运行进度

阶段4提交b8d4b6e。私有GNOME Wayland + Webots实际二进制（启动脚本强制xcb）成功，证据display-04；其前沙箱/路径编码/强制xcb失败均保留。相机probe-02通过。closed-01完整1001帧：request438在19.44接受，20.78开始Shoot，25.58结束，球移动0.19289373 m，额外重复投递154次只执行1次，全部直立。CLI首次clock查询发现延迟返回Unknown，虽然每拍API计数均1，正在补--no-daemon/发现等待与graph-ready同步。motion-01手工原地单动作路径、camera-01实际ROS解码、相机变异运行中。下一步closed-02复验CLI证据，运行analyze_webots和validate_webots_replay，补M2手册/一键/最终新clone/输入末次哈希。

阶段5已完成可用门：closed-02 CLI clock发布者1、1001帧40ms、真实物理踢球；离线回放1001帧动作完全一致；实际ROS图像ErrorCode0（自定义解码，原生BLOCKED）；motion-02原地Shoot结束但球不动；3类变异检出。原事件球位移0.1928937307m，随后25.6s观测0.1955281822m，严格分别记。最新配置仅把相同常数显式放进JSON，unit-02通过，最终新clone将全流程再验。下一步第二次阶段6：reproduce_m2、生成M2数字图表/参数表、manual_numbers校验、最终无上下文新clone、末次14根输入哈希、baseline-v1。

## 第二次阶段6

阶段5提交5662406。M2手册生成器manualM2Measurements从提交的真实录制重算并重放Core，5项手册测试通过；把球位移数字改成999的变异真实失败。新增reproduce_m2接入reproduce_all；MATLAB子进程用独立缓存ID和prefs。首个完整组合在ROS CLI的1s发现等待失败，证据evidence/6/m2-integrated-01/artifacts；已统一3s+最多3次原文保存。第二次build/m2-integrated-02正在运行，session36524。当前新代码/生成M2图表/手册尚未提交，未打baseline-v1。通过后应提交review目标并新启无上下文手册代理，只读docs/DEV_MANUAL.md在build新clone跑完整一键（约30min二维+M2），验证手工M2路径。末次输入14根哈希还未执行。
