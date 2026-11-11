# 验证与复现

所有结果来自 2026-11-10 在本机的实际运行。下文 `<evidence>` 指 `~/Documents/Robotics & AI/Robotics TDP/replay-mvp-evidence/`（在工程之外）。**自动化**指 `runtests`/脚本执行；**人工 GUI**指有人用鼠标键盘操作真实窗口——后者**没有做**。凡未实际执行的项目都标 NOT TESTED。

## 1. 实际环境

| 项 | 值 |
|---|---|
| 系统 | Ubuntu 24.04.5 LTS，内核 7.0.0-42-generic，KDE，X11 `:0`（3840×2160） |
| MATLAB | R2026b，26.2.0.3386108（`-batch`，隐藏图窗；无 GPU 加速，使用软件渲染，MATLAB 会打印 “Graphics acceleration hardware is unavailable”） |
| FFmpeg | 6.1.1-3ubuntu5（含 libx264） |
| Python | 3.12.3，numpy 1.26.4，scipy 1.11.4（只用于独立核对） |
| 机器 | 12 核，31 GB 内存 |
| Git | 分支 `replay-mvp`（从 `ai-migration-baseline` 的 68276f3 切出）；验收通过后**本地提交，未推送**（提交号见 `git log`） |
| 测试使用的 MATLAB 偏好目录 | 工程外的临时目录（避免写入 `build/`）；测试不调用 `tdpSetup`，所以不会在 `build/cache` 创建文件 |

## 2. 运行命令

在工程根目录执行。`MATLAB_PREFDIR` 与 `TMPDIR` 请用**短路径**（`TMPDIR` 过长会使 MATLAB 启动崩溃，见 README 常见问题）。

```bash
env -u LD_LIBRARY_PATH -u LD_PRELOAD -u DISPLAY -u MATLAB_JAVA \
  MATLAB_PREFDIR="$HOME/.cache/tdp-prefs" \
  matlab -batch "r=runtests({'tests/test_replay_events.m','tests/test_replay_player.m','tests/test_replay_export.m','tests/test_replay_catalog.m'}); disp(table(r)); exit(double(any([r.Failed])||any([r.Incomplete])))"
```

`test_replay_catalog.m` 自己不加路径；单独运行前先 `addpath('scripts','environment')`。独立计数：

```bash
python3 -I <evidence>/phaseC/independent_counts.py build/animation-20261106-151829-226/trace.mat
```

## 3. 使用的输入记录

| 记录 | 行数 | 用途 |
|---|---|---|
| `build/animation-20261106-151829-226/trace.mat` | 12000（600 s），含 `tactics` | 长记录、事件计数、导出区间 |
| `build/animation-20261106-105233-827/trace.mat` | 100（5 s），含 `tactics`、`recovery` | 短记录 |
| 测试中现场构造的合成矩阵 | 20–4000 | 事件规则、坏文件、状态机 |

`build/` 在 `.gitignore` 中，真实记录在新克隆里不存在；依赖它们的测试在缺失时用 `assume` 跳过，而不是失败。

## 4. 自动化结果

提交前验收运行（日志：`<evidence>/tests/acceptance_test_run.log`）：**34 个测试，34 通过，0 失败，0 未完成，57 s**（此前的开发期运行见 `final_test_run.log`，同为 34/34，75 s）；运行结束后 18 份原始 `trace.mat` 的 SHA-256 与开发前一致。

| 文件 | 通过/总数 | 覆盖 |
|---|---|---|
| `test_replay_events.m` | 9/9 | 列号表与 `trace_schema.json` 逐列一致；合成矩阵上事件恰好出现在预期行并带正确 `source`；常量记录无事件；快速/暂停时不报“追球者不动”；真实记录事件计数与独立 Python 计数一致；无 `tactics` 时不编造机器人号；检查器文字与记录值一致 |
| `test_replay_player.m` | 16/16 | 载入真实记录；6 种坏文件与不一致 `tactics`；载入+回放前后文件字节不变；显示位置/比分/时钟；`SeekTime` 的浮点容差与夹取；暂停不前进；0.5×、4× 速率；重新开始与结尾；单帧与事件跳转；**原有控件**（滑块、速度菜单、暂停、从头播放）；检查器与 `[R]/[I]` 标记；键盘、输入框、事件列表回调；畸形输入且不泄漏窗口；不修改输入；600 s 记录的响应 |
| `test_replay_export.m` | 6/6 | `ffprobe`：h264、yuv420p、帧数、帧率、偶数宽高、时长；对照 CSV/JSON 逐行比对；`Stride`/`FrameRate`/倍速关系；真实记录区间；参数错误不产生文件；不覆盖已有文件；编码器失败有清晰错误且不留视频 |
| `test_replay_catalog.m`（原有） | 3/3 | 修复 `sort` 之后通过（此前 3 个全部出错，见 §6） |

### 对照任务要求的 12 项

| # | 要求 | 结果 |
|---|---|---|
| 1 | 保存的比赛能打开 | VERIFIED（自动化 + `replay_2d` 选择窗口端到端，真实显示 `:0`） |
| 2 | 画面位置与记录时间一致 | VERIFIED（`testShownFrameMatchesRecordedState`） |
| 3 | 跳转显示正确的记录状态 | VERIFIED |
| 4 | 暂停不推进仿真时间 | VERIFIED |
| 5 | 速度调整有效 | VERIFIED：六个档位都测了。自动化（`testPlaybackRateScalesSimulationTime`，1.2 s 墙钟）仿真时间/墙钟比：0.25×→0.21、0.5×→0.46、1×→0.95、2×→2.00、4×→3.92、8×→7.71；真实显示器上通过速度菜单（2 s 墙钟）：0.25×→0.25、1×→0.94、2×→2.00（时钟每 40 ms 才更新一次，短窗口内有约 0.05 s 的粒度） |
| 6 | 重新开始回到起始帧 | VERIFIED |
| 7 | 无效文件被安全处理 | VERIFIED |
| 8 | 战术信息与记录值一致 | VERIFIED（对合成与真实行逐字段） |
| 9 | 事件时间与源记录一致 | VERIFIED（事件时间 = `trace(frame,61)`；计数与独立 numpy 一致：phase 22、chaser 44、kick 126、takeover 1、referee 1、goal 0、intent 107） |
| 10 | 视频有效可播放 | VERIFIED（`ffprobe` 与 `ffmpeg -f null` 完整解码无错误；两段演示视频同样检查；`ffplay` 在 `:0` 上实际播放 S2 退出码 0；对照 CSV 用独立 Python 对 `trace.mat` 逐行核对，两段共 122 行 0 处不符；S1 第 7 帧与重新渲染的第 3326 行在时钟文字与检查器区域差异最小，但差距不大，主要证据仍是对照表） |
| 11 | 原有记录不变 | VERIFIED（18 份 SHA-256 前后一致） |
| 12 | 原有回放功能仍可用 | VERIFIED（原有控件的自动化回调测试；原有 `test_replay_catalog` 通过） |

## 5. 人工验证

| 项 | 状态 |
|---|---|
| 真实显示器上窗口出现、可播放；选择窗口 → 播放 → 回放窗口 | **已做**（脚本驱动；窗口短暂出现在桌面，`phaseB/picker_end_to_end.log`） |
| 真实显示器上的冒烟测试：暂停、输入时间跳转、单帧按钮、`→` 键、`[` `]` 事件导航、点选事件、滑块、速度菜单、从头播放（18 步全部 PASS） | **已做，但是脚本触发**：通过控件自己的回调和 `WindowKeyPressFcn`，不是操作系统级鼠标/键盘事件。`acceptance/gui_smoke.{m,log}` |
| 真人用鼠标拖动滑块、点击按钮和列表、在输入框键入、按键盘快捷键 | **NOT TESTED**（需要你亲手做） |
| 窗口在你的屏幕分辨率下的布局（1600×800，窗口管理器可能缩小，本机实测为 1536×799） | NOT TESTED（仅本机一种配置） |
| 导出在**可见**窗口上的行为 | NOT TESTED（只测隐藏窗口） |
| 视频在你常用播放器里的观感、暂停/拖动 | 部分：`ffplay` 在 `:0` 播放 S2 成功退出（未观看画面）；暂停/拖动 NOT TESTED |
| `replay_2d` 选择窗口的双击/回车/Esc | NOT TESTED |
| 非 V1（旧策略）的记录、`build/run-*` 与 `build/match-*.mat` | NOT TESTED |
| Windows / macOS | NOT TESTED |

建议你亲手做的 5 分钟检查：打开最新一场 → 暂停 → 在输入框键入 `166.55` 回车 → 用 `→` 走到 166.85 → 对照检查器与 `<evidence>/phaseC/BEHAVIOUR_ANALYSIS.md` 的 §2。

## 6. 已知问题与复现

| 编号 | 问题 | 状态 | 复现 |
|---|---|---|---|
| B1 | **原有缺陷**：`listReplayMatches` 在 R2026b 对 cellstr 调用 `sort(...,'descend')` 报 `MATLAB:sort:TooManyInputs`，所以 `replay_2d` 选择窗口在这个 MATLAB 版本上**一定出错**，原有 `test_replay_catalog` 3 个测试全部出错 | 已修复（一行，改用 string 数组） | 在 68276f3 上 `addpath('scripts','environment'); runtests('tests/test_replay_catalog.m')`；日志 `phaseA/bug_listReplayMatches_before_fix.log` / `…after_fix.log` |
| B2 | **原有缺陷**：回放时钟在窗口第一次绘制完成**之前**就开始走。本机首次绘制要约 4–5 s，所以用户看到窗口时，回放已经走过 4–5 s | 已修复（先 `drawnow` 再计时） | `phaseB/startup_clock_before_after.m`（`VARIANT=old/new`，需要真实显示）：旧代码构造返回后 3 s 的时钟读数 7.0 s，新代码 3.3 s（读数与窗口可见的时间一致）。日志 `startup_clock_before_after.log` |
| B3 | 开发中发现：`SeekTime(166.6)` 因 `166.60000000000002` 落到前一行 | 已修复（1 µs 容差） | `testSeekFrameAndTimeSnapToRecordedRows` |
| B4 | 开发中发现：无战术时按上升沿数踢球会漏掉相邻两步由不同机器人踢的情况（122 对 126） | 已修复（逐行计数） | `testNoTacticsStillListsKicksWithoutInventingRobots` |
| L1 | 新窗口首次绘制比旧窗口慢：本机可见窗口构造约 9.2 s，旧版约 5.1 s（单次测量，未调查原因，怀疑新增控件） | 未解决 | `startup_clock_before_after.log` |
| L2 | 导出约 1.3 s/帧 | 未优化 | 见 §7 |

## 7. 测量（单机、单次或少次，不是基准）

| 量 | 结果 | 来源 |
|---|---|---|
| 读取 600 s 记录（`load`） | 0.03–0.16 s | Phase A / 事件探针 |
| 构造 600 s 回放窗口（隐藏） | 0.2–1.3 s；测试里 0.7–0.8 s | 多次运行 |
| 事件计算（12000 行，701 个事件） | 0.2 s | `evsmoke` |
| `SeekFrame`（含检查器重绘） | 5.9–11.1 ms/行（4 次运行的范围） | `testLongRecordingIsResponsive` 等 |
| 导出渲染 | 41 帧 51.3 s；81 帧 104.9 s；41 帧 56.5 s；5 帧 10.6–12.1 s（约 1.25–1.4 s/帧，含首次 `getframe` 的数秒） | 本机，软件渲染 |
| 导出编码 | 0.25–1.06 s | 同上 |
| 文件大小 | 81 帧 0.5× 视频 318 KB；41 帧 4× 视频 213 KB | `videos/` |
| 回放对仿真的开销 | **不适用**：回放不运行仿真 | — |

没有测量“录制屏幕对实时仿真的影响”：本方案不录屏。

## 8. 证据文件位置

证据目录：`~/Documents/Robotics & AI/Robotics TDP/replay-mvp-evidence/`（工程之外）。

| 路径 | 内容 | 来源记录 |
|---|---|---|
| `phaseA/probe_existing_replay.{m,log}` | 修改**前**的回放：播放、暂停、跳转、8×、结尾、重来、畸形输入 | `…105233-827`、`…151829-226` |
| `phaseA/existing_replay_frame_t0.05_unmodified.png` | 修改前的回放画面 | `…151829-226` |
| `phaseA/traces.sha256.before` | 18 份原始 `trace.mat` 的 SHA-256 | 全部 |
| `phaseA/bug_listReplayMatches_*.log`、`listReplayMatches_original_68276f3.m` | B1 前后 | — |
| `phaseB/*.png` | 新回放窗口的 5 个关键帧、真实显示截图 | `…151829-226` |
| `phaseB/picker_end_to_end.{m,log}`、`startup_clock_before_after.{m,log}`、`make_demo.m` | 端到端、B2、演示生成脚本 | `…151829-226` |
| `videos/…S1_…mp4`、`…S2_…mp4` 及 `.map.csv/.map.json` | 演示视频与时间对照 | `…151829-226` |
| `tests/final_test_run.log` | 最终测试日志 | — |
| `phaseC/` | 独立计数、分析脚本与 JSON、事件 CSV、`BEHAVIOUR_ANALYSIS.md` | `…151829-226` |
| `acceptance/` | 提交前验收：GUI 冒烟脚本与日志、视频帧与重新渲染行的比对 | `…151829-226` |

## 9. 复现要点

- 先跑 `python3 -I independent_counts.py`，再跑 MATLAB 测试；二者必须给出同样的计数。
- 任何修改后都用 `sha256sum build/animation-2026*/trace.mat | diff - phaseA/traces.sha256.before` 确认记录未变。
- 修改 `MatchReplay2D` 的布局后，重新生成一帧截图并人工看一遍；自动测试看不出“字叠在一起”。
