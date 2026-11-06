# TDP 4v4 二维机器人足球仿真 / TDP 4v4 Robot Football Simulation

在 9 × 6 米的球场上观察两队机器人如何分配追球职责、协作和射门。工程保留了原始 MATLAB 基线，并提供迁移后的算法、Stateflow 控制器、Simulink 二维比赛模型、测试及实验记录。

Watch two teams share responsibility for chasing the ball, coordinate their movements and shoot on a 9 × 6 m pitch. This project includes the original MATLAB baseline, the migrated algorithms, Stateflow controllers, the Simulink 2D match model, tests and recorded results.

## 启动比赛 / Start a match

1. 在 MATLAB 中，将 **当前文件夹** 设为本 README 所在的 `2d-soccer-game/`。项目使用 MATLAB、Simulink 和 Stateflow，在 R2026b 上验证。

   In MATLAB, set **Current Folder** to `2d-soccer-game/`, the folder containing this README. The project uses MATLAB, Simulink and Stateflow and was tested with R2026b.
2. 在下表选择一场比赛，打开对应的 `.m` 文件并点击 **Run ▶**。如果 MATLAB 询问工作目录，选择 **Change Folder**。首次编译可能需要几分钟。球场时钟开始走动时，比赛即已开始。

   Choose a match below, open its `.m` file and click **Run ▶**. If MATLAB prompts for the working folder, choose **Change Folder**. The first compile may take a few minutes. The match has started when the pitch clock begins to advance.

| 比赛 / Match | MATLAB 入口 / MATLAB entry point | 观察重点 / What to watch |
| --- | --- | --- |
| 默认 V1 / Default V1 | [`start_2d.m`](start_2d.m) | 四名球员各有固定角色，金色外圈标出当前获准追球的球员。 / Each player has a fixed role. A gold ring marks the player currently allowed to chase the ball. |
| 自动交还实验 / Striker handback experiment | [`start_2d_recovery.m`](start_2d_recovery.m) | 中场接管后，当恢复条件满足时会把追球职责交还前锋。 / After the midfielder takes over, the striker regains responsibility for chasing the ball once the recovery conditions are met. |

每场默认运行 **600 秒、1 倍速**。蓝队 1–4 号、红队 5–8 号依次是门将、后卫、中场、前锋。可以在球场窗口暂停、继续、调整倍速、停止或重新开赛。

Each match defaults to **600 simulated seconds at 1× speed**. Blue players 1–4 and red players 5–8 are the goalkeeper, defender, midfielder and striker, respectively. Use the pitch window to pause, resume, change speed, stop or restart the match.

### Ubuntu 终端和桌面图标 / Ubuntu terminal and desktop launchers

在有图形显示的终端中，从项目文件夹运行下表命令。脚本会启动独立的 MATLAB 进程，关闭球场窗口即可退出。脚本默认使用原开发机的 MATLAB 安装路径。在其他机器上，将 `MATLAB_BIN` 设为 MATLAB 可执行文件的路径。如果 `matlab` 已在 shell 搜索路径中，可先运行 `export MATLAB_BIN=matlab`。

From a terminal with a graphical display, run one of the commands below in the project folder. The script starts a separate MATLAB process, which exits when you close the pitch window. Its default MATLAB path points to the original workstation. On another machine, set `MATLAB_BIN` to your MATLAB executable, or run `export MATLAB_BIN=matlab` if your shell can already find `matlab`.

| 比赛 / Match | 终端 / Terminal | 原开发机上的桌面图标 / Desktop launcher on the original workstation |
| --- | --- | --- |
| 默认 V1 / Default V1 | `./start_2d.sh` | `START_2D.desktop` |
| 自动交还 / Striker handback | `./start_2d.sh --recovery` | `START_2D_RECOVERY.desktop` |

两个桌面图标指向原开发机的固定项目路径 `/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1`。在该位置可双击启动，首次按 Ubuntu 提示选择“允许启动”。日志窗口无需输入。克隆到其他位置时，请使用上面的 MATLAB 或终端入口。

Both desktop launchers point to the fixed project path shown above. At that location, double-click a launcher and select **Allow Launching** if Ubuntu prompts you. The log window requires no input. For a clone in another location, use the MATLAB or terminal entry points above.

## 复现实验 / Reproduce the experiments

在项目文件夹的 MATLAB 命令窗口运行下表中的一条命令。如果只想观察一次交接，可先跟随[8 秒无画面练习 / 8-second headless handback exercise](docs/chapters/recovery_experiment.md#自己制造一次接管并看逐拍日志)。

Run one of the following commands in MATLAB with the project folder selected. For a short walkthrough of a single handback, start with the 8-second headless exercise linked above.

| 实验 / Experiment | MATLAB 命令 / MATLAB command | 内容 / Coverage |
| --- | --- | --- |
| 综合复现 / Full baseline workflow | `tdpSetup; reproduce_all;` | 重建模型，执行基线验证和当前环境可运行的集成检查。 / Rebuild the models and run baseline verification and the available integration checks. |
| V1 战术 / V1 tactics | `tdpSetup; reproduce_v1;` | 重建模型并测试指定场景，再用 20 个随机种子分别按 50 ms 和 40 ms 周期运行，共 40 场。 / Rebuild the models, test targeted scenarios and run 40 matches across 20 seeds with 50 ms and 40 ms control periods. |
| 自动交还对照 / Striker handback comparison | `tdpSetup; reproduce_recovery;` | 用相同种子对比默认 V1 和实验策略，共 80 场。原开发机从干净克隆运行约 21 分钟。 / Compare default V1 with the experimental policy over 80 matches using matched seeds. A clean clone took about 21 minutes on the original workstation. |

在原开发机上也可从终端无画面运行，例如 `./scripts/run_matlab.sh "tdpSetup; reproduce_all;"`。如需将原策略用作对照，在 MATLAB 中运行 `tdpSetup; runMatch(tdp.defaultConfig());`。

On the original workstation you can also run headless from the terminal, for example with `./scripts/run_matlab.sh "tdpSetup; reproduce_all;"`. To use the original policy as a control, run `tdpSetup; runMatch(tdp.defaultConfig());` in MATLAB.

## 文档与结果 / Documentation and results

以下详细说明以中文编写。开发手册列出了 ROS 2 和 Webots 已验证的功能以及各自的依赖条件。历史工程 `robot-soccer-starter/` 提供结构参考。

The detailed guides below are in Chinese. The developer manual lists the verified ROS 2 and Webots capabilities and their dependencies. The historical starter project is included as a structural reference. [历史入门工程 / Original starter project](robot-soccer-starter/README.md)

| 主题 / Topic | 文档 / Guide | 记录 / Results |
| --- | --- | --- |
| 实时动画 / Live viewer | [动画操作与排错 / Controls and troubleshooting](docs/chapters/live_animation.md) | [动画验收与截图 / Viewer checks and screenshots](docs/generated/animation_numbers.md) |
| V1 战术 / V1 tactics | [场景、参数和判据 / Scenarios, parameters and criteria](docs/chapters/tactics_v1_design.md) | [40 场结果与运行时间 / 40-match results and runtime](docs/generated/v1_results.md) |
| 自动交还 / Striker handback | [交还条件与验证方法 / Handback conditions and verification](docs/chapters/recovery_experiment.md) | [80 场对照结果 / 80-match comparison](docs/generated/recovery_results.md) |
| 工程概览 / Project overview | [开发手册与依赖 / Developer manual and dependencies](docs/DEV_MANUAL.md) | [开发进度 / Development progress](docs/PROGRESS.md) |
