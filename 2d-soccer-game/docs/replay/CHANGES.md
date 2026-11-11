# 修改记录

基线：提交 `68276f3`（“Checkpoint saved match selection and replay controls”）。工作分支：`replay-mvp`（验收后本地提交，未推送；提交号见 `git log`）。**没有修改**：机器人运动、战术规则、Stateflow、球物理、计分、控制/导航、`LiveViewer2D`、仿真输出格式、`build/animation-*` 里的任何记录。

`git diff --stat`：3 个已有文件共 +229/−11（`environment/MatchReplay2D.m` 占绝大部分，另有 `replay_2d.m`、`scripts/listReplayMatches.m`）；新增 6 个脚本和 3 个测试文件。

## C1 统一载入与校验：`scripts/loadReplayRecording.m`；`replay_2d.m` 改用它

- **改了什么**：新函数读取 `trace.mat`，先用 `whos('-file')` 查变量，再只载入需要的变量；校验 `trace`（N×98、实数、有限、时间严格递增）和 `P`（含 `dt`、`Tmatch`）；`tactics` 尺寸/时间不一致时降级并写入 `Warnings`。`replay_2d.m` 的 `load(match.file,'P','trace')` 换成这个函数，并把 `tactics` 传给播放器。
- **为什么**：原来的回放根本没载入已经保存的 171 列战术记录；坏文件的错误信息也不具体。
- **备选**：在 `MatchReplay2D` 内部载入——否决：播放器应只接收数据，便于导出和测试复用。
- **文件**：`scripts/loadReplayRecording.m`（新），`replay_2d.m`（3 行）。
- **测试**：`testLoaderOpensRealRecordings`、`testLoaderRejectsBadFilesWithClearErrors`、`testInconsistentTacticsAreDroppedWithWarning`、端到端 `phaseB/picker_end_to_end.log`。
- **未解决**：只处理 `P`、`trace`、`tactics`；`recovery` 变量不读取。

## C2 列号与枚举名的单一来源：`replayColumns.m`、`replayEnumName.m`

- **改了什么**：`replayColumns` 给出 98 列的列号表；`replayEnumName` 从工程的 `Tdp*` 枚举类取名字，未知值回退为数字文本。
- **为什么**：避免在多处硬编码列号和“1=Goto”；枚举类改了，回放自动跟随。
- **备选**：在回放里复制一张枚举表——否决（会不同步）。
- **测试**：`testColumnMapMatchesGeneratedSchema` 把 `replayColumns` 与 `docs/generated/trace_schema.json` 逐列比对。
- **未解决**：`replayColumns` 仍是 `MatchRecord.m` 顺序的手工副本，靠这一个测试保持同步。

## C3 事件：`scripts/replayEvents.m`

- **改了什么**：从矩阵检测 11 类事件（`goal` `referee` `kick` `phase` `chaser` `takeover` `recovering` `gameRunning` `intent` `request` `feedback`，均为“记录值的变化”，`source = 'recorded'`）和 1 类推断事件（`chaserStationary`，`source = 'inferred'`）。每个事件带 `evidence`（依据的列）。
- **为什么**：需求要求区分“直接记录”和“推断”，并能在时间线上定位战术转折。
- **备选**：在仿真里新增事件日志——否决（约束：不改输出格式）；更多推断规则（如“前锋在等待”）——否决（推断多了会被误读成记录）。
- **开发中修正的两处**：(a) 一开始 `kick` 用上升沿，漏掉相邻两步分别由两个机器人踢的情况（122 对 126），改为逐行；(b) 静止区间一开始要求“与上一行追球者相同”才算起点，导致追球者换人那一行被漏掉，改为“游程在追球者换人时断开、新一段从换人那一行开始”。(c) 后来增加了 `intent` 事件，因为“为什么前锋在等”取决于意图（Stop）而不是请求。
- **测试**：`test_replay_events.m`（9 个），含与独立 numpy 计数的比对（phase 22、chaser 44、kick 126、takeover 1、referee 1、intent 107）。
- **未解决**：事件只说明“字段变了”，没有原因（记录里没有）；阈值 0.02 m/s 与 1 s 是我定的，没有依据课程要求。

## C4 检查器文字：`scripts/replayInfoText.m`

- **改了什么**：纯函数，把一行记录变成分组文字（记录真值 / 决策 / 请求 / 反馈）。
- **为什么**：需求要求区分五层信息；纯函数可直接断言。
- **测试**：`testInspectorTextShowsRecordedValuesOnly`、`testInspectorAndEventListShowRecordedValues`。
- **未解决**：用等宽字体手工对齐列，窗口缩放后可能错位（未测）。

## C5 播放器扩展：`environment/MatchReplay2D.m`

- **改了什么**：
  1. 新增可选第 5 个参数 `tactics`；旧的 4 参数调用不变。
  2. 返回结构体增加函数句柄：`State`、`Pause`、`Resume`、`SeekFrame`、`SeekTime`、`Step`、`SetRate`、`Restart`、`JumpToEvent`，以及 `Events`。
  3. 新增检查器文本框、事件列表、单帧步进按钮、“跳到 t(s)”输入框、键盘快捷键；窗口 1120×800 → 1600×800，原有控件只是移动位置。
  4. 时钟显示 `00:00.05` 两位小数加 `帧 k / N`（原来只有一位小数，0.05 s 的步长会显示成 `00:00.1`）。
  5. 把原来嵌套在回调里的逻辑抽成可复用函数（`pausePlayback`、`seekFrame`、`applyRate` 等），行为不变。
- **为什么**：P0（跳转到指定仿真时间、重来、结尾处理）与 P1（战术可观察、事件时间线）。
- **备选**：改 `LiveViewer2D`（否决，见 ARCHITECTURE §8）；新建第二个播放器类（否决：重复）。
- **测试**：`test_replay_player.m`（16 个），含“原有控件”测试 `testOnScreenControlsStillWork`；速率测试覆盖全部六个档位。
- **未解决**：在窗口管理器缩小窗口后的布局只在一台机器上看过；快捷键、鼠标操作未做人工测试。

## C6 起始时钟（原有缺陷 B2）

- **改了什么**：`set(fig,'Visible',visible)` 之后加 `drawnow`，再开始计时（`MatchReplay2D.m` 一处）。
- **为什么**：见 TESTING §6 B2：首次绘制耗时数秒，期间回放时钟已经在走。
- **备选**：把 `play()` 放到第一次 timer 回调里——否决（更复杂）。
- **测试**：只有真实显示器上的脚本 `phaseB/startup_clock_before_after.m`（旧 7.0 s，新 3.3 s）；**没有自动化回归测试**（隐藏窗口里无法复现首次绘制）。
- **未解决**：新窗口首次绘制总体更慢（L1）。

## C7 按时间跳转的容差

- `SeekTime` 用 `times <= s + 1e-6`。原因：`166.6` 对应的记录时间是 `166.60000000000002`，不加容差会落到前一行。测试 `testSeekFrameAndTimeSnapToRecordedRows`。

## C8 `scripts/listReplayMatches.m`（原有缺陷 B1）

- **改了什么**：`sort(sortKeys,'descend')` → `sort(string(sortKeys),'descend')`，两行（含一行注释）。
- **为什么**：R2026b 不接受对 cellstr 带 `'descend'`，选择窗口无法打开，原有 `test_replay_catalog` 3 个测试出错。
- **测试**：`test_replay_catalog`（3/3）；对真实 `build/` 列出 18 场并排序。
- **未解决**：无。

## C9 视频导出：`scripts/exportReplayVideo.m`

- **改了什么**：选行 → 用 `MatchReplay2D` 隐藏窗口逐行渲染 → `getframe` → PNG → `ffmpeg`（libx264、yuv420p）→ MP4，并写 `.map.csv`/`.map.json`。不覆盖已有文件；失败时清理临时目录且不留视频。
- **为什么**：P1 视频导出，且需要“视频时间—仿真时间”对照与区间选择。
- **备选**：`VideoWriter('MPEG-4')`（本机没有该档）；`print`（拒绝含 UI 的窗口）；屏幕录制（会录入无关窗口且时间对照不精确）。
- **测试**：`test_replay_export.m`（6 个）；两段演示视频用 `ffprobe` 与完整解码检查。
- **未解决**：约 1.3 s/帧（L2）；画面是整个窗口，不能只导出球场；只在隐藏窗口上测过。

## C10 测试与文档

- 新增 `tests/test_replay_events.m`、`test_replay_player.m`、`test_replay_export.m`；`docs/replay/` 下 8 个文档。
- 工程之外：`replay-mvp-evidence/`（脚本、日志、截图、视频、分析）。

## 没有做（P2）

状态重建、状态转换回放、时间线标注、多相机、两个版本的对比；事件摘要导出；长记录的进一步加速。
