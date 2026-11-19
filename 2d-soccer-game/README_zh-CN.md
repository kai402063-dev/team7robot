# 2D 足球战术仿真

[English](README.md)

本工程使用 MATLAB、Simulink 和 Stateflow 运行 4 对 4 足球仿真，包含实时比赛、战术配置、比赛回放和离线行为统计。

## 在 MATLAB 中启动

将 MATLAB 的「当前文件夹」切换到仓库中的 `2d-soccer-game/`，然后在命令窗口运行下表中所需的命令。也可以打开对应的 `.m` 文件，点击编辑器工具栏中的「运行」。

| 用途 | MATLAB 命令 | Ubuntu 桌面快捷方式 |
| --- | --- | --- |
| 观看默认 V1 比赛 | `start_2d` | `START_2D.desktop` |
| 观察中场接管并交还追球权 | `start_2d_recovery` | `START_2D_RECOVERY.desktop` |
| 选择并回放已保存的比赛 | `replay_2d` | `REPLAY_2D.desktop` |

实时比赛默认运行 **600 仿真秒、1 倍速**。蓝队为 1–4 号，红队为 5–8 号，两队依次为门将、后卫、中场和前锋。金色外圈标出当前获准追球的队员。比赛窗口支持暂停、继续、切换倍速、停止和重开。首次编译模型可能需要几分钟。

桌面快捷方式使用本机绝对路径。使用前核对其中的 `Exec` 和 `Path` 是否指向你的工程目录。如果 Ubuntu 提示需要信任启动器，可在确认路径后选择「信任并启动」或「允许启动」。快捷方式会新开一个 MATLAB 进程，关闭对应窗口即可退出该进程。

[8 秒无画面追球权交还练习](docs/chapters/recovery_experiment.md#自己制造一次接管并看逐拍日志) · [动画操作、记录与排错](docs/chapters/live_animation.md) · [动画截图与验证结果](docs/generated/animation_numbers.md)

## 从终端启动

在 Ubuntu 图形会话中，从工程目录运行以下任一命令。若启动器找不到 MATLAB，可用 `MATLAB_BIN` 指定 MATLAB 可执行文件。

```bash
./start_2d.sh
./start_2d.sh --recovery
./start_2d.sh --replay
```

## 复现与开发

[中文开发手册](docs/DEV_MANUAL.md)介绍依赖、干净克隆中的短时比赛，以及完整复现所需的验证回执。[开发进度](docs/PROGRESS.md)记录了二维仿真及 ROS 2 / Webots 的验证范围。本工程含冻结的 A 基线、MATLAB 算法、Stateflow 控制器、二维环境和测试。

运行无画面批处理前，确认 `scripts/run_matlab.sh` 使用的是你的 MATLAB 安装路径。

| 复现范围 | 命令 |
| --- | --- |
| 完整流程 | `./scripts/run_matlab.sh "tdpSetup; reproduce_all;"` |
| V1 战术验证 | `./scripts/run_matlab.sh "tdpSetup; reproduce_v1;"` |
| 自动交还追球权对照实验 | `./scripts/run_matlab.sh "tdpSetup; reproduce_recovery;"` |

- V1 验证会重建模型，测试指定场景，并用 20 个种子和两种步长运行 40 场比赛。可用 `runMatch(tdp.defaultConfig())` 运行原策略作对照。[战术设计](docs/chapters/tactics_v1_design.md) · [40 场结果](docs/generated/v1_results.md)
- 自动交还实验对比同种子下的默认 V1 和实验策略。本机曾在干净克隆中用约 21 分钟完成。[对照方法](docs/chapters/recovery_experiment.md) · [80 场结果](docs/generated/recovery_results.md)
- 单队对照检验自己切换策略和对手切换策略各自的影响。[实验方法](docs/chapters/team_ablation.md) · [追球授权、射门与进球结果](docs/generated/team_ablation.md)

原 3v3 MATLAB/Simulink 教学示例见[归档说明](../Archive/robot-soccer-starter/README_zh-CN.md)。
