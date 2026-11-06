# 二维手册首次阅读与独立复算

从 `docs/DEV_MANUAL.md` 进入「十秒无图形实验」，使用本机已有 MATLAB、Simulink 与 Stateflow。在任务树首次创建 `build/v1-reader-01`，仅从已提交的本地 Git 建立运行副本。代码提交为 `ca87cb149cf7b71e5ad5ae1ea7396dd64f981b2c`，运行前副本没有已有 build、Git 工作区干净。阅读的是外层正在编写的手册，运行使用克隆的模型与函数。本次没有操作用户桌面、安装产品或推送。

## 从手册到第一次踢球

```bash
# 起始位置是外层工程根目录。
git clone --no-local . build/v1-reader-01
cd build/v1-reader-01
TDP_CACHE_ID=reader01host TDP_MATLAB_PREFDIR="$PWD/build/reader-prefs-host" ./scripts/run_matlab.sh "tdpSetup; P=tdp.v1Config(); P.Tmatch=10; tdpRun(P);"
```

原文的自动目录版本保存至副本 `build/run-20261106-092308-825/trace.mat`。最初沙箱中的独立 MATLAB 无输出退出 1，留下空日志、起止时间与退出码。随后使用独立主机 MATLAB，单独的副本内偏好、Simulink 加速缓存和代码生成目录；首次成功命令退出 0。两份日志在同一拍采样，50 ms、种子 1 的十秒比赛是 200 行，对应 98 列物理量和 171 列战术量。逐行核对了固定身份、本地与全局追球者换算、时间一致性、每一次实际踢球者与同拍授权、有效请求及匹配反馈。九次实际踢球，比分 0∶0。

3.75 s，蓝队处于 ATTACK，承担追球任务的全局 4 号仍是固定 ST。意图、个人原始和实际放行请求均为 Kick，执行器返回 4 号自己 #76 的 Running，球静止。3.95 s，第 79 行出现同号 Done，战术 `kicker=4`，物理第 97 列由 0 变 1，球从 (0,0) m 移至约 (0.02893,−0.00197) m，实际球速从 0 增至 0.58 m/s。请求速度为 0.6 m/s，低于此工程的射门阈值。这里可以逐项区分身份、临时追球权、开始准备、真正出脚、射门和比分。从 `first-run.json` 可以查完整数字、全部 9 次出脚和数组哈希。

## 核对修订后的操作

首次阅读曾发现，自动命名批跑命令后只给 40 ms 对应的 250 行，且没有独立的批跑产物路径和加载示例。修订版写明默认 50 ms 为 200 行、40 ms 为 250 行，分别解释 `build/animation-…`、`build/run-…` 和自选目录，并把球队 V1 验证同阶段综合复现区分开。另一独立 MATLAB 进程按修订版的固定目录重新执行、加载原变量、显示尺寸与首踢。其终端输出见 `named-host.log`，同一目录不宜再次使用；代码会拒绝覆盖。40 ms 说明另外与 `../handson-01/receipt.json` 中十秒 250 行的实际存盘回执核对。

```bash
# 从读者的副本根目录执行。若此前运行过，换一个尚不存在的目录。
TDP_CACHE_ID=reader01named TDP_MATLAB_PREFDIR="$PWD/build/reader-prefs-named" ./scripts/run_matlab.sh "tdpSetup; P=tdp.v1Config(); P.Tmatch=10; tdpRun(P,'build/my-v1-ten-seconds'); tdpSetup; game=load('build/my-v1-ten-seconds/trace.mat','trace','tactics','P'); disp(version); disp(size(game.trace)); disp(size(game.tactics)); c=v1TraceColumns(); k=find(game.tactics(:,c.kicker)>0,1); disp([game.trace(k,61),game.tactics(k,c.kicker)]); assert(isequal(size(game.trace),[200,98])&&isequal(size(game.tactics),[200,171])&&~isempty(k));"
```

## 复核整场记录

手册入口提供 `./scripts/run_matlab.sh "tdpSetup; reproduce_v1;"`，会重建模型。老师或组员要重建时，可按手册的干净 clone 流程在单独副本操作，每次使用新输出目录并保留失败记录。本次读者只重复十秒比赛，对其他干净克隆已运行的 40 场重新计算证据汇总，未再次启动 40 场仿真。下列步骤核对 40 个种子/周期组合、逐场 MAT 文件 SHA-256、采样长度、无违例和每周期种子 1 的复跑项，按比赛回执重建汇总；与正式汇总逐字节相同。重新从 MATLAB 仿真复现、从已有 MAT 重新计算数值、按回执汇总是不同操作。使用归档的分场回执重算汇总时，须能访问其 executionRoot 下保留的原 MAT 文件。

```bash
# 从外层工程根目录执行。summarize 的目标目录必须是新的。
python3 build/v1-reader-01/scripts/v1_matrix_evidence.py summarize build/v1-reader-01/build/verify-official-evidence evidence/tactics-v1/matrix-final-01/matches
cmp build/v1-reader-01/build/verify-official-evidence/receipt.json evidence/tactics-v1/matrix-final-01/summary/receipt.json
python3 evidence/tactics-v1/reader-01/read_run.py build/v1-reader-01/build/run-20261106-092308-825/trace.mat docs/generated/v1_columns.json
```

读者据手册可以找到图形入口、十秒变量、暂停与继续、局部与全局编号、金色追球外圈和保存位置。本次实际使用无图形路径。图形窗口行为另有同版本独立显示测试，实际 NAO6 与三维均不在这次读者验证范围内。
