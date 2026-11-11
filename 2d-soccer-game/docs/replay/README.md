# 二维比赛回放与行为分析（Replay MVP）

## 1. 这套工具做什么

回放读取**已经保存的**比赛记录（`build/animation-*/trace.mat`），逐行显示当时记录下来的机器人和球的位置，并把**战术日志**（球队阶段、追球授权、个人意图、请求、执行反馈）显示在旁边。它**不重新运行**仿真，也不重新运行战术控制器；所以它只能回答“记录里写了什么”，不能回答“如果当时这样做会怎样”。

| 能力 | 入口 | 状态（见 [TESTING.md](TESTING.md)） |
|---|---|---|
| 打开保存的比赛、播放/暂停、拖动、0.25×–8× 速度、重新开始、结尾处理 | `replay_2d` | 自动化已验证；真实桌面窗口已启动并驱动过，鼠标/键盘的人工操作**未验证** |
| 单帧步进、跳到指定仿真秒、事件列表与上/下一个事件 | 窗口按钮、`←/→`、`[` `]` | 回调已自动化验证；人工操作**未验证** |
| 检查器：位置、速度、角色、意图、目标、请求、反馈、球队阶段、追球者 | 窗口右上 | 已验证（与记录值逐项比对） |
| 事件时间线（`[R]` 记录值的变化，`[I]` 规则推断） | 窗口右下 | 已验证 |
| 导出 MP4（可选时间区间，附“视频时间—仿真时间”对照表） | `exportReplayVideo` | 已验证（ffprobe 检查、对照表逐行比对） |

## 2. 前置条件

- MATLAB R2026b（本次在 26.2.0.3386108 上验证）。回放窗口只用基础 MATLAB 与工程自带枚举类（枚举类继承 `Simulink.IntEnumType`，所以运行环境需要 Simulink，这与工程其余部分一致）。
- 导出视频另需 `ffmpeg`（含 libx264）。本机为 FFmpeg 6.1.1。导出函数用 `env -u LD_LIBRARY_PATH -u LD_PRELOAD` 调用它，避免 MATLAB 自带库干扰。
- 至少一份保存的比赛。仓库的 `build/` 被 `.gitignore` 忽略，新克隆里没有记录，需要先在 `start_2d.sh` 里跑一场（`TDP_2D_DURATION=30 ./start_2d.sh` 只需 30 秒仿真）。

## 3. 怎样打开回放

三种等价入口：

```bash
# 终端（图形桌面内）
./start_2d.sh --replay
```

- 文件管理器双击 `REPLAY_2D.desktop`。
- 已打开的 MATLAB 里，当前文件夹设为工程根目录，运行 `replay_2d`。

出现“比赛回放”选择窗口后，双击一行或点“播放”。列表按开始时间从新到旧排序，只列出状态为已完赛或提前停止、并且 `trace.mat` 与 `receipt.json` 都能读取的比赛。

直接用代码打开（不经选择窗口）：

```matlab
addpath('scripts','algorithms','interfaces','environment');   % 在工程根目录
rec = loadReplayRecording('build/animation-20261106-151829-226');
p   = MatchReplay2D(rec.P, rec.Trace, '我的回放', 'on', rec.Tactics);
p.SeekTime(166.6);          % 跳到 166.60 s
p.State()                   % Frame, Time, Playing, Rate, LastFrame
```

## 4. 播放控制

| 操作 | 做法 | 说明 |
|---|---|---|
| 暂停 / 继续 | 按钮，或空格 | 暂停后仿真时间不再前进 |
| 拖动 | 球场下方的滑块 | 单位是记录行（帧）；拖动后保持原来的播放/暂停状态 |
| 跳到指定时刻 | 右下“跳到 t(s)”输入框 + 回车 | 显示**不晚于**该时刻的最近一行；非数字被忽略 |
| 单帧步进 | “◀ 单帧”“单帧 ▶”，或 `←` `→` | 先暂停再移动一行 |
| 速度 | 速度下拉框 | 0.25×、0.5×、1×、2×、4×、8×；换速不跳时间 |
| 从头播放 | “从头播放” | 回到第 1 行并开始播放 |
| 事件导航 | 事件列表点选，或 `[`（上一个）`]`（下一个） | 跳到事件所在行并暂停 |

顶部时钟显示 `分:秒.百分位 / 总时长 | 帧 当前 / 总数`。记录的第一行时间是 0.05 s（第一个控制周期之后），不是 0。

## 5. 检查器与事件列表怎么读

检查器把同一时刻的信息按**来源层次**分开，不要混为一谈：

| 分组 | 含义 | 来源列 |
|---|---|---|
| recorded state | 真值位置、速度（`hypot(vxw,vyw)`） | 98 列物理记录 |
| decision | 球队阶段、追球者、个人**意图**与意图目标、Stateflow 技能阶段 | 171 列战术记录 |
| request | 授权之后**实际发出**的请求种类与编号 | 同上 |
| feedback | 执行层报告的状态与对应编号 | 同上 |

事件列表每行形如 `166.85s [R] T1 R3 chaser ...`：`[R]` 表示某个**被记录的字段**在这一帧变了；`[I]` 表示由[规则推断](TRACE_FORMAT.md#6-直接记录的信息与推断的信息)，不是记录值。`[R]` 只说明“变了”，不说明“为什么变”：记录里没有阶段切换的原因。

## 6. 导出视频

```matlab
addpath('scripts','algorithms','interfaces','environment');
r = exportReplayVideo('build/animation-20261106-151829-226', ...
        '/some/folder/clip.mp4', struct('StartTime',166,'EndTime',170,'FrameRate',10));
```

可选项：`StartTime`、`EndTime`（仿真秒）、`Stride`（每隔几行取一行）、`FrameRate`（视频帧率，默认 `1/(dt·Stride)`，即实时）、`CRF`（画质，默认 18）、`Overwrite`。输出 `clip.mp4`，同目录还有 `clip.mp4.map.csv`（逐帧：视频帧号、视频秒、记录行号、仿真秒）和 `clip.mp4.map.json`（来源文件及其 SHA-256、速度等）。关系式：

```text
视频第 k 帧显示记录行 rows(k)
视频时间 = (k-1) / FrameRate            仿真时间 = trace(rows(k), 61)
播放倍速 = dt · Stride · FrameRate        （1 表示实时）
```

画面里本身也画着仿真时钟与帧号。**成本**：本机无 GPU 加速时每帧渲染约 1.3 s（81 帧 105 s），编码不到 2 s，所以长片段用 `Stride` 降采样。已有输出文件不会被覆盖，除非给 `Overwrite`。

## 7. 常见问题

| 现象 | 原因与处理 |
|---|---|
| 选择窗口提示“还没有可回放的比赛” | `build/` 里没有已完赛的 `animation-*` 或 `run-*` 记录。先跑一场 |
| MATLAB 启动即崩溃，提示 `TEMPDIR name is too long` | 环境变量 `TMPDIR` 指向了很长的路径。改用短路径（如 `~/.cache/x`）或不设 |
| 导出报“找不到可运行的 ffmpeg” | 安装 ffmpeg，或用 `opts.FFmpeg` 指向可执行文件 |
| 导出报“输出文件已存在” | 这是保护。换文件名，或显式 `Overwrite` |
| 窗口比屏幕宽 | 窗口 1600×800 像素；窗口管理器可能缩小它。其他控件按比例排布 |
| 没有战术信息，只有位置 | 这份记录没有 `tactics`（旧版/非 V1 策略），或它与 `trace` 不一致已被忽略；终端会有 `TDP:ReplayLoad` 警告 |
| 战术阶段变了但不知道为什么 | 记录里没有原因（见 [TRACE_FORMAT.md](TRACE_FORMAT.md#7-缺失或有歧义的信息)） |

## 8. 已知限制

- 只能回放**已保存的**行；不能回放中间状态之外的任何东西，也不能比较两个版本（P2，未做）。
- 位置是仿真真值，不是机器人自己的观测；二维圆形代理不代表 NAO6 步态或接触动力学。
- 回放按墙钟推进、按“不晚于当前时间的最近一行”显示：高倍速时会跳过中间行。需要逐行检查请用单帧步进。
- 导出画面包含整个回放窗口（球场、检查器、事件列表、按钮），不能单独导出球场。
- 目前只在 Linux/X11、MATLAB R2026b 上测试。
- 其他文档：[ARCHITECTURE](ARCHITECTURE.md) · [TRACE_FORMAT](TRACE_FORMAT.md) · [IMPLEMENTATION_GUIDE](IMPLEMENTATION_GUIDE.md) · [TESTING](TESTING.md) · [CHANGES](CHANGES.md) · [独立复现清单](REPRODUCTION_CHECKLIST.md)
