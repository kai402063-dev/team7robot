"""Qualify paired default/automatic matches and render the teaching table from receipts."""
import argparse
from pathlib import Path

from v1_matrix_evidence import ROOT, read, require, summarize, write_new

ARCHIVE = ROOT / "evidence/tactics-v1/matrix-final-01/summary/receipt.json"
EXTRA = {"v1AutoRecovery", "v1RecoveryHealthySeconds", "v1HealthDropWindow"}


def by_case(report):
    return {(row["period"], row["seed"]): row for row in report["matches"]}


def compare(out):
    policies = ("v1", "recovery")
    summaries = {}
    for policy in policies:
        target = out / (policy + "-summary")
        summarize(target, [out / policy])
        summaries[policy] = read(target / "receipt.json")
    default, experiment = [summaries[k] for k in policies]
    require(default["sourceFingerprint"] == experiment["sourceFingerprint"] and
            default["revision"] == experiment["revision"], "Policies used different sources")
    history, base, auto = [by_case(item) for item in (read(ARCHIVE), default, experiment)]
    require(history.keys() == base.keys() == auto.keys(), "Case keys differ from the frozen matrix")
    pairs = []
    for key in sorted(base):
        dt, seed = key
        rows = [base[key], auto[key]]
        require(all(history[key][k] == rows[0][k] for k in ("traceDigest", "tacticsDigest")),
                f"Default trajectories differ from accepted V1 at {key}")
        records = [read(out / row["receipt"]) for row in rows]
        artifacts = [read((out / row["receipt"]).with_name("artifact.json"))["arrays"] for row in rows]
        require([r["model"] for r in records] == ["tdpV1Match", "tdpRecoveryMatch"], f"Model mismatch {key}")
        p, q = [r["parameters"] for r in records]
        require(q.keys()-p.keys() == EXTRA and p == {k:v for k,v in q.items() if k not in EXTRA}
                and q["v1AutoRecovery"] and q["v1RecoveryHealthySeconds"] == .5
                and all(v == [0,0] for v in q["v1HealthDropWindow"]), f"Unpaired settings {key}")
        steps = round(600 / dt)
        require(all(arr["tactics"]["shape"] == [steps,171] for arr in artifacts)
                and set(artifacts[0]) == {"trace","tactics"}
                and set(artifacts[1]) == {"trace","tactics","recovery"}, f"Log channels {key}")
        health = artifacts[1]["recovery"]
        require(health["finite"] and health["shape"] == [steps,53], f"Recovery array {key}")
        if seed == 1:
            require(records[1]["replay"]["sameRecoveryTrace"], f"Recovery replay {key}")
        stats = records[1]["recovery"]
        require(stats["entries"] == rows[1]["metrics"]["takeoverEntries"], f"Entry count {key}")
        require(all(n-r == int(still) for n,r,still in zip(stats["entries"],stats["returns"],
                stats["stillTakenOverAtEnd"])), f"Handback counts {key}")
        pairs.append({"period":dt, "seed":seed, "defaultEqualsArchived":True,
                      "samePhysicalTraceAcrossPolicies":rows[0]["traceDigest"] == rows[1]["traceDigest"],
                      "sameTacticalTraceAcrossPolicies":rows[0]["tacticsDigest"] == rows[1]["tacticsDigest"],
                      "recoveryDigest":health["sha256LittleEndianDoublesRowMajor"],
                      "handback":stats, "defaultReceipt":rows[0]["receipt"], "experimentReceipt":rows[1]["receipt"]})
    periods = []
    for original, updated in zip(default["periods"],experiment["periods"]):
        dt = original["period"]
        sample = [r for r in pairs if r["period"] == dt]
        totals = {name: [sum(r["handback"][name][i] for r in sample) for i in range(2)]
                  for name in ("returns","entries","mfKicksDuringHandback","cancelSamples","stillTakenOverAtEnd")}
        require(dt == updated["period"] and sum(totals["returns"]) > 0, f"No observed handback at {dt}")
        periods.append({"period":dt,"default":original,"experiment":updated,"automatic":totals,
                        "pairsWithChangedPhysicalTrace":sum(not r["samePhysicalTraceAcrossPolicies"] for r in sample)})
    result = {"status":"PASS","revision":default["revision"],"sourceFingerprint":default["sourceFingerprint"],
              "pairedCases":len(pairs),"historicMatchesReproduced":len(history),"officialMatches":2*len(pairs),
              "totalOfficialSteps":sum(s["totalOfficialSteps"] for s in summaries.values()),
              "additionalFullReplays":sum(s["additionalFullSeedOneReplays"] for s in summaries.values()),
              "periods":periods,"matches":pairs}
    write_new(out / "comparison.json", result)
    return result


def table(data):
    require(data["status"] == "PASS","Only a qualified result can be rendered")
    lines = ["# 同种子整场对照", "", "每个周期各取相同的 20 个种子，每场 600 秒。进球、射门、踢球和接管统计合计两队。接管占比的分母是两队可用的全部比赛时间。", "",
             "| 控制周期 | 策略 | 进球 | 有进球场数 | 射门 | 实际踢球 | 中场接管次数 | 中场接管时间占比 | 自动交还次数 |",
             "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for period in data["periods"]:
        for policy, name in [("default","默认 V1"),("experiment","自动恢复实验")]:
            row = period[policy]
            returns = str(sum(period["automatic"]["returns"])) if policy == "experiment" else "—"
            fraction = sum(row["takeoverSeconds"])/(row["matches"]*600*2)
            lines.append(f'| {row["period"]*1000:.0f} ms | {name} | {sum(row["goals"])} | {row["matchesWithGoal"]} | '
                         f'{sum(row["shots"])} | {sum(row["actualKicks"])} | {sum(row["takeoverEntries"])} | {fraction:.2%} | {returns} |')
    lines += ["", "物理与场地统计按相同观测口径汇总。“白线外”按机器人圆形外缘越线计算，边带属于另一条更宽的边界。受阻比例的分母是请求平移的机器人采样数。", "",
              "| 周期 | 策略 | 首次触球范围（s） | 重叠步数 | 白线外机器人采样 | 边带外机器人采样 | 受阻平移占比 |",
              "|---|---|---:|---:|---:|---:|---:|"]
    for period in data["periods"]:
        for policy, name in [("default", "默认 V1"), ("experiment", "自动恢复实验")]:
            row = period[policy]
            first = row["firstTouchRangeSeconds"]
            touch = "无触球" if not first else f"{first[0]:g}–{first[1]:g}"
            lines.append(f'| {row["period"]*1000:.0f} ms | {name} | {touch} | {row["overlapSteps"]} | '
                         f'{row["outsidePitchRobotSamples"]} | {row["outsideBorderRobotSamples"]} | {row["blockedTranslationRatio"]:.3%} |')
    lines += ["", f'共 {data["officialMatches"]} 场、{data["totalOfficialSteps"]:,} 步，另有 {data["additionalFullReplays"]} 场完整重复回放。'
              f' 默认策略的 {data["historicMatchesReproduced"]} 场物理轨迹和战术记录分别逐场与已验收 V1 的数组哈希一致。', "",
              "“实际踢球”取自二维执行层的出球事件。持续故障、撤销和断线由定向场景另行检验。"
              "这里的得分只描述这组种子。", "",
              "[逐场对照与全部指标](../../evidence/recovery-v1/clean-01/comparison.json) · "
              "[定向场景与读数方法](../chapters/recovery_experiment.md)", ""]
    reader = read(ROOT / "evidence/recovery-v1/reader-01/receipt.json")["executed"]
    require(reader["exit_code"] == 0 and reader["duration_sim_seconds"] == 8, "Incomplete manual example")
    lines += ["## 八秒练习的逐步输出", "", "| 仿真时刻（s） | 接管中 | 追球编号 | 保护中的动作编号 |",
              "|---:|---:|---:|---:|"]
    for row in reader["rows"]:
        lines.append(f'| {row["tSim"]:.2f} | {row["takeover"]} | {row["chaser"]} | {row["protectedId"]} |')
    lines += ["", "最后一行的追球编号为 0，表示这一拍无人获准追球。"
              "[独立读者的原始 MATLAB 输出](../../evidence/recovery-v1/reader-01/example-execution.log)", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("out",type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--render",type=Path)
    group.add_argument("--check",type=Path)
    args = parser.parse_args()
    if args.render or args.check:
        expected = table(read(args.out / "comparison.json"))
        if args.check:
            require(args.check.read_text() == expected, "Manual comparison table differs from receipts")
        else:
            args.render.write_text(expected)
    else:
        compare(args.out)
