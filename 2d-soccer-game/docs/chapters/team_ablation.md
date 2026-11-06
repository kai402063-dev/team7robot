# 只给一队自动交还，会怎样？

这里比较两队的协调器规则对同一场自对赛的影响。蓝队编号 1–4，攻 +x；红队编号 5–8，攻 −x。两队各固定门将、后卫、中场和前锋。追球授权表示协调器允许该队员在本拍执行主要追球动作。即使无人获准追球，门将和后卫也可以按原规则移动和触球。

|组别|蓝队|红队|数据来源|
|---|---|---|---|
|全默认|V1|V1|此前已验收的 40 场|
|仅红自动|V1|自动交还|本轮第一批 40 场|
|仅蓝自动|自动交还|V1|本轮第二批 40 场|
|全自动|自动交还|自动交还|此前已验收的 40 场|

每组使用相同的 20 个种子、两种控制周期（50 ms 和 40 ms）、600 s 赛长和固定的开球位置。健康持续时间沿用 0.50 s。对照入口以 `[蓝 红]` 的顺序传入两个逻辑值。被选中的球队使用既有自动交还协调器、动作编号保护和回传逻辑。另一队运行显式交还的 V1。两队处于同一物理场景中，由同一个裁判计分。

## 复现

在 MATLAB 中先运行以下短场。第一行配置选择仅红队自动；把两个逻辑值交换就能只给蓝队自动。

```matlab
tdpSetup;
P = tdp.teamRecoveryConfig([false true]);
P.dt = 0.04; P.seed = 11; P.Tmatch = 16;
[trace,tactics,diagnostics] = runMatch(P);
c = v1TraceColumns();
owner = tactics(:,c.chaser);
idx = find([true; any(diff(owner),2)]);
disp(table(tactics(idx,c.time),owner(idx,1),owner(idx,2), ...
    'VariableNames',{'tSim','blueChaser','redChaser'}))
```

完整实验用独立 MATLAB 进程，在工程根目录执行：

```bash
./scripts/run_matlab.sh "tdpSetup; reproduce_team_ablation;"
```

运行器重建实验模型，执行隔离测试、两批 600 s 比赛和每批两个周期的种子 1 重复回放，最后生成报告。默认结果在 `build/team-ablation-时间戳/`。根回执的 `stage` 标出正在执行的步骤。`red-only/`、`blue-only/` 的每个 `dtXX-seedYY/receipt.json` 记录实际模型和参数、射门、比分及对应 MAT 文件的位置；大数组只留在本机的 `build/`。如果归档的旧 MAT 可读，会复用并核对哈希；换台机器时找不到大数组，程序会重跑两个参考组并按归档轨迹摘要验明身份。

## 怎么读这四组

固定蓝队、比较红队从默认改成自动，是红队自身的条件效应。固定红队、比较蓝队从默认改成自动，是蓝队策略对红队的条件效应。两条路径的差如果不同，就有交互作用。也可以把两条路径的变化取平均，给出合计差的一种对称分摊。每个条件都先在相同种子、相同周期内作差。两个周期使用的是同一组种子，比赛固定左右侧和开球初态。

追球授权按比赛实际进行的采样时间分为前锋、中场和无人三类。射门只统计前锋或中场已真正执行、请求速度达到 1.8 m/s 的踢球。比分取裁判记录的整球越线事件。授权、出脚和得分是三个不同的观测量。[模型入口](../../scripts/build_team_recovery_match.m) · [复现脚本](../../scripts/reproduce_team_ablation.m)

## 本轮结果和复核

[实际授权时间、射门、进球与本机耗时](../generated/team_ablation.md)列出所有组别。只切换红队时，红队中场获得追球授权的时间和射门次数都大幅减少。只切换蓝队时，仍使用默认 V1 的红队反而射得更多，却较少把射门转化为得分。逐次接触审计发现，其射门在下一次主动出脚或重开之前，首先碰到蓝方后卫的比例也上升。这里的接触通过同拍的球员和球位置与最后触球队识别；一次接触后球仍可能进门。[逐对成绩与两个周期的效应](../../evidence/team-ablation/clean-01/summary.md) · [红队射门后的首次对手接触](../../evidence/team-ablation/audit-01/shot-followup.json)

两种策略互相影响，切换次序会改变边际差。50 ms 的顺序平均结果偏向红队自身效应，40 ms 下双方相等。还可每次同时删去同一个种子在两个周期的回放，共做 20 次。该检查用于观察有限样本对结论的影响。[从裁判比分独立重算的结果](../../evidence/team-ablation/audit-01/referee-and-seed-check.json)

要核对隔离：新实验模型设为两队都默认、两队都自动，分别在两个周期跑过 600 s，逐一对照归档物理与战术数组哈希。两个自动端点的 53 列诊断数组也一致。归档的首次差异检查覆盖所有单队比赛；发生差异的第一拍都能追溯到被选中队交还，另一些配对与默认轨迹逐步相同。[隔离和故障注入回执](../../evidence/team-ablation/isolation-02/review.md) · [逐场首次差异](../../evidence/team-ablation/clean-01/first-divergences.json)

已有本实验的小型回执时，在工程根目录运行 `python3 scripts/analyze_team_ablation.py evidence/team-ablation/clean-01 --check` 可重算报告并核对逐场计数。要从头重读数值轨迹或重新仿真，使用上面的一键 MATLAB 入口。
