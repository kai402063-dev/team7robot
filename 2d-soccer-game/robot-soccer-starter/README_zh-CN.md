# 机器人足球仿真入门示例

一个用于学习 MATLAB 和 Simulink 机器人足球仿真的起步项目。

[English README](README.md)

## 示例简介

本项目基于 MathWorks Mobile Robotics Simulation Toolbox，在二维足球场中模拟两支各含三个机器人的队伍，包含机器人运动、球的交互、传感器模型和行为逻辑。可以从这里开始了解模型结构、修改参数，并尝试开发团队策略。

机器人采用简化的二维运动学模型。随附工具箱还包含移动机器人导航、传感器及可视化示例。

Copyright 2018-2019 The MathWorks, Inc. 源文件中保留原有版权声明。

## 软件环境

本示例已在 MATLAB R2026b 环境中验证，当时配置了以下产品：

- Simulink
- Stateflow
- Robotics System Toolbox
- Navigation Toolbox
- Image Processing Toolbox

请使用 MATLAB 桌面界面查看模型和动画。其他 MATLAB 版本的兼容性需要另行检查。工具箱中的其他示例可能需要额外产品，详见 `doc/GettingStarted.mlx`。

## 项目结构

```text
robot-soccer-starter/
├── README.md
├── README_zh-CN.md
├── startMobileRoboticsSimulationToolbox.m
├── examples/soccer/
│   ├── multiRobotSoccer.slx       # 足球仿真主模型
│   ├── robotSoccerParams.m       # 仿真参数
│   ├── datatypes/                # 总线类型与枚举
│   └── utils/                    # 足球辅助函数与机器人库
├── src/                         # 运动学、传感器、可视化、倍速控制
└── doc/                         # 工具箱文档
```

## 在 MATLAB 中打开并运行

1. 将**整个项目文件夹**下载或复制到自己的电脑；如果收到的是 ZIP 文件，请先解压。项目可以存放在任意位置，也可以更改文件夹名称。
2. 打开 MATLAB，在 **Current Folder（当前文件夹）** 中选择项目根目录，也就是同时包含本 README、`startMobileRoboticsSimulationToolbox.m`、`examples` 和 `src` 的文件夹。如果其他项目中同名的 `multiRobotSoccer` 模型已经打开，请先保存需要保留的改动并关闭它。使用新的 MATLAB 会话可以避免混用不同副本的搜索路径。
3. 在 **Command Window（命令窗口）** 中执行以下命令。它会初始化路径、打开模型、设置约 1 倍速播放，并运行 30 秒仿真：

   ```matlab
   run('startMobileRoboticsSimulationToolbox.m');
   open_system(fullfile(pwd, 'examples', 'soccer', 'multiRobotSoccer.slx'));
   soccerRuntimePacing(1);
   set_param('multiRobotSoccer', 'StopTime', '30');
   set_param('multiRobotSoccer', 'SimulationCommand', 'start');
   ```

   启动脚本还会打开 `GettingStarted.mlx` 入门文档。首次运行会先编译模型，再显示足球场动画。这里的 `30` 表示 30 秒仿真时间。
4. 按需使用 Simulink 的 **Pause（暂停）**、**Continue（继续）** 和 **Stop（停止）** 控件。也可以在命令窗口停止仿真：

   ```matlab
   set_param('multiRobotSoccer', 'SimulationCommand', 'stop');
   ```

### 通过 MATLAB 界面打开文件

在 **Current Folder** 中选择项目根目录后：

1. 双击 `startMobileRoboticsSimulationToolbox.m`，在 MATLAB 编辑器中点击 **Run（运行）**。初始化时保持当前文件夹为项目根目录。
2. 进入 `examples/soccer`，双击 **`multiRobotSoccer.slx`**，打开仿真主模型。
3. 在命令窗口输入 `soccerRuntimePacing(1)`，启用约 1 倍速播放。
4. 在 Simulink 模型窗口将 **Stop Time（停止时间）** 设置为 `30`，然后点击 **Run（运行）**。如需持续运行，可将停止时间设置为 `inf`，结束时点击 **Stop（停止）**。

打开模型时会自动执行 `robotSoccerParams.m`。该脚本会清除基础工作区中的变量、加载总线类型及参数，并随机化机器人和球的初始位置。打开模型前，请先保存需要保留的工作区数据。重新初始化参数后，各次运行的起始位置可能不同。

## 调整播放速度

模型打开后，可在 MATLAB 命令窗口使用以下命令：

| 命令 | 作用 |
| --- | --- |
| `soccerRuntimePacing(1)` | 目标约为 1 倍速，即接近实际时间 |
| `soccerRuntimePacing(3)` | 目标为每 1 秒实际时间推进约 3 秒仿真时间 |
| `soccerRuntimePacing(0)` | 取消节奏限制，按计算能力尽快运行 |
| `soccerRuntimePacing('status')` | 查看配置及已有的计时统计 |
| `soccerRuntimePacing('restore')` | 关闭软实时控制，恢复之前的内置节奏设置 |

此函数会自动关闭 Simulink 内置的 **Simulation Pacing（仿真节奏控制）**，使用期间请保持内置选项关闭。实际播放速度受机器负载影响；这是软实时控制，不提供硬实时保证。倍速配置仅在当前 MATLAB 会话中有效，重启 MATLAB 后需要重新启用。

## 建议从哪里开始修改

- **参数：**打开 `examples/soccer/robotSoccerParams.m`，或初始化路径后输入 `edit robotSoccerParams`。可以先查看 `initialPoses`、`initBallPos`、传感器范围及行为阈值。脚本会调用 `randomizeStartingPositions`；如需固定起始位置，请同时查看该调用。
- **行为逻辑：**打开 `multiRobotSoccer.slx`，查看机器人子系统及 Stateflow 逻辑。机器人库文件为 `examples/soccer/utils/soccerRobotLib.slx`。
- **工具箱指南：**初始化路径后输入 `edit GettingStarted`，查看其他示例与说明。

修改前先停止仿真。修改参数脚本后，重新运行 `robotSoccerParams` 加载参数，再启动仿真；此操作也会清除工作区变量。建议复制一份起步项目用于自己的实验。

## 常见问题

如果 MATLAB 找不到函数或总线类型，请在 **Current Folder** 中重新选择项目根目录，并运行启动脚本。如果提示缺少某个产品，可用 `ver` 查看已安装产品。

如果 `soccerRuntimePacing` 报告 `WrongCopy`，请检查实际加载路径：

```matlab
get_param('multiRobotSoccer', 'FileName')
which soccerRuntimePacing -all
which robotSoccerParams -all
```

模型和函数的首个匹配路径应属于同一个项目文件夹。请关闭其他副本的模型后重新初始化本项目，或使用新的 MATLAB 会话。

## 参考资料

- [使用 MATLAB 和 Simulink 仿真移动机器人](https://www.mathworks.com/videos/matlab-and-simulink-robotics-arena-getting-started-with-the-mobile-robotics-simulation-toolbox-1523443253912.html)
- [机器人群体编程](https://www.mathworks.com/videos/matlab-and-simulink-robotics-arena-programming-robot-swarms-1539080970349.html)
- [足球机器人行为编程](https://www.mathworks.com/videos/programming-soccer-robot-behavior-1554386041395.html)
