# 实时二维动画与一键启动

## 1. 要解决什么问题

完整测试能输出轨迹和指标，但组员还需要亲眼看机器人怎样接近球、转向和踢球。这个入口把所选比赛模型的逐步输出显示为一块实时更新的球场：蓝队攻右侧，红队攻左侧；圆形代表机器人，短线表示朝向，白色小圆代表球。

在独立 X11 显示上，真实 MATLAB 窗口已完成逐步绘图、暂停/继续、速度切换、停止、重开和运行中关窗验证。带动画的 50 ms、40 ms 轨迹分别与同配置无动画运行对照。查看[实际前后帧及数值](../generated/animation_numbers.md)和[运行回执](../../evidence/animation/display-02/artifacts/receipt.json)。按钮回调由验证脚本触发，未操作用户桌面；原封不动的 `./start_2d.sh` 也已在独占显示上启动实际 MATLAB，确认球场窗口可见、关闭后进程正常退出；见[端到端回执](../../evidence/animation/launch-e2e-01/receipt.json)。本机每个独立启动进程用隔离缓存，冷启动准备可能需要数分钟；同窗口 Restart 可复用本局模型缓存。

动画展示的是二维圆形代理。看到球移动不等于完成 NAO6 步态、足球接触或实机模型验证；本入口也不改变 ROS 2、Webots 各自的验收状态。

## 2. 先启动一场比赛

先在文件管理器进入工程文件夹。双击 `START_2D.desktop` 看默认 V1；双击 `START_2D_RECOVERY.desktop` 看自动交还实验。桌面首次询问时，选择“信任并启动”或右键“允许启动”。已经打开 MATLAB 的组员可以在工程的当前文件夹双击打开 `start_2d.m` 或 `start_2d_recovery.m`，再点编辑器绿色 Run。冷启动时请等窗口时钟开始走动。

喜欢终端的组员也可运行以下命令，实验版在最后一行后加 ` --recovery`。

```bash
cd '/home/fayne/Documents/Robotics & AI/Robotics TDP/2d-soccer-game/tdp-migrated-r1'
./start_2d.sh
```

它启动新的 MATLAB 进程。默认使用 `tdp.v1Config()` 和 `tdpV1Match`。比赛时长 `P.Tmatch=600` s、仿真周期 `P.dt=0.05` s，显示速度默认 1 倍。首次编译模型时，窗口显示 `Compiling model...`，场上对象暂时不动；初始化完成后自动开赛，无需再点 Restart。编译和机器负载都会影响实际等待时间，不把首次等待算作仿真时间。

启动终端会先打印 MATLAB 日志路径。这个进程使用自己的偏好目录与缓存标识，不连接用户已经打开的 MATLAB 桌面。比赛结束后窗口保留，便于查看结果和重开；关闭球场窗口会停止当前比赛，写运行记录，再结束这个新进程。

两个桌面图标的 `Exec` 和 `Path` 指向 README 列出的本机安装位置。工程搬家或新 clone 后，在 MATLAB 中打开新目录的对应启动文件点 Run 即可。本机已从两个图标各自的真实启动命令进入独占 X11 显示（独立的图形会话），看到球场窗口可见、八个机器人和球有位移，并在关窗后正常退出。文件管理器首次信任提示由组员在本机处理。[默认入口回执](../../evidence/recovery-v1/default-window-01/receipt.json) · [实验入口回执](../../evidence/recovery-v1/experiment-window-02/receipt.json) · [MATLAB 编辑器无参入口验收](../../evidence/recovery-v1/editor-window-01/receipt.json)

## 3. 按钮怎样使用

| 控件 | 操作与预期现象 | 先检查什么 |
|---|---|---|
| Pause / Resume | Pause 发出请求，状态栏先显示 `Pausing...`；确认冻结后按钮变为 Resume | 初始化尚未完成时按钮不可用；暂停后不应继续累积比赛时钟 |
| Speed | 选择慢放或倍速，改变仿真相对墙钟的目标推进速度 | 较快倍速受 CPU 和绘图能力限制，不保证达到目标值 |
| Max | 关闭实时节奏限制，按本机能力尽快运行 | 显示会跳过部分中间绘制，完整仿真记录仍逐步保存 |
| Stop | 结束本场，保留已经完成的轨迹和最后场面 | 它不同于 Pause；要继续观察原场应使用 Pause/Resume |
| Restart | 比赛结束或停止后，从初始配置重新开一场 | 比赛运行中禁用；沿用本窗口参数和随机种子，结果写新目录 |
| 关闭窗口 | 请求停止，完成记录后释放窗口 | 由 shell 启动时，随后退出对应的独立 MATLAB 进程 |

`1x` 表示目标是每经过一秒墙钟时间，推进一秒仿真时间。“墙钟时间”就是人在终端外实际等候的时间；它只用于显示节奏，不作为控制器计时来源。按下 Pause 时记录请求时刻，引擎处理请求后会在仿真步边界冻结。看到 `Paused` 后读取停帧和比赛时刻。请求与确认的间隔取决于调度，15 秒仍未确认会退出该次运行并报告 `TDP:AnimationControlTimeout`。等待期间可以停止比赛或关窗。暂停、继续和倍速不修改 `P.dt`，控制器仍读取仿真输入 `tSim`。显示读取记录，不向机器人状态或球速回写。

窗口下方状态栏会报告编译、运行、暂停、结束或失败。发生失败时先查看状态信息和本次回执；不要把停住的画面直接判断成战术错误。

## 4. 改时长、速度和仿真周期

短时间观察可以通过环境变量设置，变量值以数据传入 MATLAB 并由入口校验：

```bash
TDP_2D_DURATION=30 TDP_2D_SPEED=2 ./start_2d.sh
```

这条命令请求 30 s 仿真、初始 2 倍速；它是一个可选配置示例，不是测试已测得的耗时。`TDP_2D_SPEED=Inf` 对应 Max。速度必须为正数，也可传入其他正的自定义倍速；窗口应显示实际选择的数值。时长必须为正且是控制周期的整数倍；例如默认周期下可用 30 s，不用 NaN 或特殊标志代替未知值。

其他 MATLAB 安装位置可通过 `MATLAB_BIN` 指定：

```bash
MATLAB_BIN='/path/to/MATLAB/bin/matlab' ./start_2d.sh
```

路径可以带空格。这里只替换已有可执行文件路径，不安装产品。`./start_2d.sh --help` 可以不启动 MATLAB 就查看用法。

如果希望在 MATLAB 内修改配置，先把当前目录切到工程根目录：

```matlab
app=start_2d;
```

该函数自动开始比赛，运行期间由窗口按钮交互，停止或结束后命令返回。此路径使用当前 MATLAB 进程，并通过 `tdpSetup` 设置本进程搜索路径与生成缓存；不调用 `savepath`。希望保持已有工作会话隔离时，使用前面的 shell 入口。

控制周期由参数决定，与动画速度无关。下面以 40 ms 周期运行：

```matlab
tdpSetup;
P=tdp.v1Config();
P.dt=0.04;
app=start_2d(P,1);
```

`P.dt=0.05` 是二维默认周期，`0.04` 是面向 Webots 20 ms 基础步长的对齐选项；本入口并不因此启动 Webots。改变周期属于重新配置仿真，必须重新开始比赛；切换 Speed 只调整墙钟节奏。不要修改原始项目 A 的 `simParams.m` 来控制这个入口。

动画 runner 当前要求 `P.observationDelay=0`、`P.observationNoise=0`。已实现的观测延迟/噪声实验仍按 `sensorReplay` 路径操作，不能仅改这两个参数就宣称动画已接入对应传感器适配。

## 5. 结果在哪里，怎样看

每场比赛建立一个新的 `build/animation-时间戳/` 目录；同一窗口重开也不会覆盖前一次。目录包括：

- `trace.mat`：实际收集到的逐步轨迹 `trace` 和配置 `P`。
- `receipt.json`：完成、用户停止或失败状态，以及本次可用的统计和按钮事件。

MATLAB 入口返回后，可查看 `app.RunDirectory`、`app.Trace` 和 `app.LastError`。正常结束为 `COMPLETED`；主动停止为 `STOPPED_BY_USER`；`FAIL` 时应查看保存的错误。运行过程中每一列的定义仍以 [接口契约](interfaces.md) 和 `MatchRecord` 源码为准，不把动画帧率当作控制采样率。

shell 的启动日志和偏好目录另放在 `build/animation-launcher/animation_时间戳_PID/`，包含 `matlab.log` 与 `preferences/`。`TDP_CACHE_ID` 给这次进程分配独立名称；Simulink 缓存与生成文件位于 `build/cache/` 和 `build/codegen/` 的对应子目录。启动器清除继承的 `LD_LIBRARY_PATH`、`LD_PRELOAD`、`MATLAB_JAVA`，保留显示连接所需环境，减少终端 ROS 环境对 MATLAB 启动的影响。

## 6. 原理与源码入口

| 源码 | 责任 | 修改后应验证什么 |
|---|---|---|
| [`start_2d.sh`](../../start_2d.sh) | 检查图形连接、隔离新 MATLAB 进程、等待窗口关闭 | 环境隔离、含空格路径、无显示错误、退出码 |
| [`start_2d.m`](../../start_2d.m) | 读取配置，创建窗口，自动启动 | 默认/自定义参数、错误输入、函数返回后的状态 |
| [`LiveViewer2D.m`](../../environment/LiveViewer2D.m) | 绘制球场、机器人和球，处理按钮，保存每场记录 | 坐标与朝向、暂停/继续、速度显示、停止/重开/关窗 |
| [`runAnimatedMatch.m`](../../scripts/runAnimatedMatch.m) | 运行正常模式 Simulink 仿真，订阅记录输出，控制节奏 | 与无动画轨迹一致、两个控制周期、异常清理 |
| [`test_animation.m`](../../tests/test_animation.m) | 自动验证显示数据和仿真行为 | 读取断言及本次测试回执，失败时保留原始日志 |

一个周期仍由模型推进控制器和环境状态，然后产生 `MatchRecord`。显示监听器读取该记录，更新画面；它不参与模型的代数计算，也不替换原来的 Unit Delay。控制器和物理的正确性由原有测试与新增轨迹对比验证，画面是否流畅是另一项检查。

测试入口包括 `scripts/validate_animation.m`、`scripts/validate_animation_display.py` 和启动器验证脚本。它们分别覆盖 MATLAB 行为、独立图形环境以及 shell 契约；真实执行的范围必须由回执确认。启动器替身验证可单独运行，输出目录应使用尚未存在的名字：

```bash
python3 scripts/validate_animation_launcher.py --output build/launcher-check-manual
python3 scripts/validate_animation_launcher_mutation.py --output build/launcher-mutation-manual
```

第二条命令在临时副本上故意破坏环境清理规则，检查测试能否发现；不会修改正式启动器。它成功表示测试捕获了预定缺陷，不表示真实图形窗口已验证。

## 7. 不同时先查什么

| 现象 | 排查与处理 |
|---|---|
| 提示 `No DISPLAY` | 当前终端没有图形显示连接。到本机图形桌面终端运行；不要手动猜一个 DISPLAY 值来绕过检查 |
| 提示无法连接 DISPLAY | 检查当前桌面会话和显示访问权限；启动器已在 MATLAB 启动前停止 |
| 找不到 MATLAB | 使用 `MATLAB_BIN` 指向现有 MATLAB 可执行文件，并确认当前用户可执行 |
| 窗口出现但还没有运动 | 看状态栏是否仍在首次编译；查看本次 `matlab.log`，不要连续重开进程 |
| 用 `run_matlab.sh` 看不到窗口 | 这个脚本用于无画面验证，会清除 DISPLAY；可见动画应使用 `start_2d.sh` |
| 已有同名模型或模型正在运行 | 保存当前工作，优先改用独立 shell 入口。动画会拒绝不同路径的同名模型和已运行的 `tdpMatch` |
| Speed 与时钟推进感觉不一致 | 先区分编译等待、绘图刷新和仿真时间；高倍速可能受本机算力限制 |
| 画面定住并显示失败 | 查看本次 `receipt.json` 的错误；无新记录超时与主动 Pause 是不同情况 |
| 停止后想继续同一场 | Stop 已结束本场；Restart 从初始状态重来。以后需暂时查看时使用 Pause |
| 搬家后双击入口失效 | 修正 `.desktop` 的 `Exec`/`Path`，或从新目录直接执行 `./start_2d.sh` |

完成后应能解释：为什么 2 倍速不改变机器人速度参数；为什么暂停时不能用墙钟替代 `tSim`；为什么运行日志与画面要分开验收；为什么这场二维比赛无法证明 NAO6 实机动力学正确。

开发期间还实际遇到两类 MATLAB 问题：R2026b 的 `Interruptible` 返回 `OnOffSwitchState` 枚举，断言字符值前要显式转 `char`；嵌套 `onCleanup` 在函数退出时读取已经销毁的共享变量会报警，runner 已改为捕获对象的独立清理函数。对应失败日志保留在 `evidence/animation/matlab-01/`、`display-01/` 和 `mutation-01/`；最后一项含无关断言失败，因此明确标为不合格变异回执，不用于验收。

V1 窗口的金色外圈跟随本队实际追球授权。蓝队本地 1–4 号和红队本地 1–4 号分别固定为 GK、DF、MF、ST。未授权期间该队没有金色外圈。`trace.mat` 中的 `tactics` 保存相位、请求、反馈和执行层事件。用 `start_2d(tdp.defaultConfig(),1)` 可运行旧策略供复核。金色外圈与两种周期的 V1 动画轨迹也有独立验证。当前默认入口在五个仿真秒内产生了机器人和球的实际位移，冷启动所需时间与球移动距离见[本次 V1 实测](../generated/v1_results.md)。
