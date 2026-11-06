"""Audit the four paired team policies and render the Chinese match report."""
import argparse
from hashlib import sha256
from pathlib import Path

import numpy as np
from scipy.io import loadmat

from v1_matrix_evidence import ROOT, file_hash, read, require, write_new


ARCHIVE = ROOT / "evidence/recovery-v1/clean-01"
POLICIES = ("default", "redOnly", "blueOnly", "both")
TEAMS = ("blue", "red")
LABELS = dict(default="双方默认", redOnly="仅红自动", blueOnly="仅蓝自动", both="双方自动")
# The configuration uses [blue, red], while the report names the changed side.
MASKS = dict(default=[False, False], redOnly=[False, True], blueOnly=[True, False], both=[True, True])
MODELS = dict(default="tdpV1Match", redOnly="tdpTeamRecoveryMatch",
              blueOnly="tdpTeamRecoveryMatch", both="tdpRecoveryMatch")
PERIODS = (50, 40)
SEEDS = range(1, 21)
TEAM_FIELDS = ("liveMs", "midfielderMs", "strikerMs", "unassignedMs", "takeoverMs",
               "midfielderShots", "strikerShots", "shots", "goals", "entries", "returns")


def cases():
    for period in PERIODS:
        for seed in SEEDS:
            yield period, seed, f"dt{period}-seed{seed:02d}"


def checked_worker(directory):
    run = read(directory / "receipt.json")
    require(run["status"] == "PASS_SHARD" and run["completedMatches"] == 40
            and set(run["seeds"]) == set(SEEDS) and set(run["periods"]) == {.05, .04},
            f"Incomplete 40-match campaign: {directory}")
    expected = {case for _, _, case in cases()}
    found = {p.parent.name for p in directory.glob("dt*-seed*/receipt.json")}
    require(expected == found, f"Unexpected or missing cases: {directory}")
    for side in ("before", "after"):
        manifest = read(directory / f"source-{side}.json")
        require(manifest["fingerprint"] == run["sourceFingerprint"] and
                manifest["revision"] == run["revision"], f"Source drift: {directory}")
    return run


def archived_policy(policy):
    return "v1" if policy == "default" else "recovery"


def small_receipt_check(out, data):
    """Compare portable matched counts with per-match referee and command receipts."""
    for row in data["pairs"]:
        for policy in POLICIES:
            if policy in ("default", "both"):
                directory = ARCHIVE / archived_policy(policy)
            else:
                directory = out / ("red-only" if policy == "redOnly" else "blue-only")
            folder = directory / row["case"]
            game = read(folder / "receipt.json")
            artifact = read(folder / "artifact.json")
            stored = row["policies"][policy]
            require(stored["arraySha256"] == {k: v["sha256LittleEndianDoublesRowMajor"]
                    for k, v in artifact["arrays"].items()}, f"Digest mismatch: {folder}")
            require(game["status"] == "PASS" and game["model"] == MODELS[policy] and
                    game["parameters"]["seed"] == row["seed"] and
                    game["parameters"]["dt"] == row["periodMs"] / 1000, f"Wrong case: {folder}")
            for index, team in enumerate(TEAMS):
                counts = stored["teams"][team]
                metrics = game["metrics"]
                require(all(counts[k] == metrics[k][index] for k in ("goals", "shots", "midfielderShots"))
                        and counts["entries"] == metrics["takeoverEntries"][index] and
                        0 < counts["liveMs"] <= 600000 and counts["takeoverMs"] <= counts["liveMs"] and
                        counts["entries"] - counts["returns"] in (0, 1), f"Count mismatch: {folder}")
                if not MASKS[policy][index]:
                    require(counts["returns"] == 0, f"Unexpected default return: {folder}")


def team_counts(trace, tactics, period, params, team):
    active = tactics[:, 13] == 1
    owner = tactics[:, 5 + team]
    mf, st = 3 + 4 * team, 4 + 4 * team
    require(np.isin(owner, [0, mf, st]).all() and np.all(owner[~active] == 0),
            "Invalid chaser or granted during stoppage")
    takeover = tactics[:, 167 + team]
    require(np.isin(takeover, [0, 1]).all(), "Invalid takeover flag")
    transitions = np.diff(takeover, prepend=0)
    kicker = tactics[:, 14]
    shots = [(kicker == i) & (tactics[:, 158 + i] >= params["shotSpeed"]) for i in (mf, st)]
    for i, event in zip((mf, st), shots):
        require(np.all(active[event] & (owner[event] == i)), "Shot occurred without a live grant")
    require(np.array_equal(np.cumsum(shots[0] | shots[1]), trace[:, 65 + team]),
            "Physical shot events differ from referee shot counter")
    score = trace[:, 61 + team]
    require(np.isin(np.diff(score, prepend=0), [0, 1]).all(), "Invalid goal counter")
    return {
        "liveMs": int(active.sum()) * period,
        "midfielderMs": int(np.count_nonzero(active & (owner == mf))) * period,
        "strikerMs": int(np.count_nonzero(active & (owner == st))) * period,
        "unassignedMs": int(np.count_nonzero(active & (owner == 0))) * period,
        "takeoverMs": int(np.count_nonzero(active & (takeover == 1))) * period,
        "midfielderShots": int(shots[0].sum()), "strikerShots": int(shots[1].sum()),
        "shots": int(trace[-1, 65 + team]), "goals": int(score[-1]),
        "entries": int(np.count_nonzero(transitions == 1)),
        "returns": int(np.count_nonzero(transitions == -1)),
    }


def audit_game(policy, directory, worker, case, period, seed, frozen_params):
    folder = directory / case
    game = read(folder / "receipt.json")
    metrics = game["metrics"]
    require(game["status"] == "PASS" and metrics["passed"] and not game["violations"] and
            game["revision"] == worker["revision"] and
            game["sourceFingerprint"] == worker["sourceFingerprint"] and
            game["model"] == MODELS[policy], f"Unqualified model or case: {folder}")
    expected_params = frozen_params.copy()
    if policy in ("redOnly", "blueOnly"):
        expected_params["v1AutoRecoveryTeams"] = MASKS[policy]
    params = game["parameters"]
    require(params == expected_params and params["Tmatch"] == 600 and params["seed"] == seed and
            params["dt"] == period / 1000, f"Unexpected parameter or team mask: {folder}")
    if seed == 1:
        replay = game["replay"]
        require(replay["steps"] == 600000 // period and replay["samePhysicalTrace"] and
                replay["sameTacticalTrace"] and (policy == "default" or replay["sameRecoveryTrace"]),
                f"Replay differs: {folder}")
    artifact = read(folder / "artifact.json")
    path = Path(worker["executionRoot"]) / game["artifact"]
    require(file_hash(path) == artifact["sha256"], f"MAT checksum differs: {path}")
    widths = {"trace": 98, "tactics": 171}
    if policy != "default":
        widths["recovery"] = 53
    require(set(artifact["arrays"]) == set(widths), f"Unexpected logged arrays: {path}")
    arrays = loadmat(path, variable_names=list(widths))
    digest_key = "sha256LittleEndianDoublesRowMajor"
    digests = {}
    for name, width in widths.items():
        matrix = np.ascontiguousarray(arrays[name], dtype="<f8")
        dimensions = [600000 // period, width]
        digest = sha256(memoryview(matrix).cast("B")).hexdigest()
        meta = artifact["arrays"][name]
        require(list(matrix.shape) == meta["shape"] == dimensions and meta["finite"] and
                np.isfinite(matrix).all() and meta[digest_key] == digest, f"Array differs: {path}/{name}")
        digests[name] = digest
    if policy in ("default", "both"):
        original = archived_policy(policy)
        reference = read(ARCHIVE / original / case / "artifact.json")
        require(all(digests[k] == reference["arrays"][k][digest_key] for k in widths),
                f"Reference does not reproduce archived endpoint: {case}/{policy}")
    trace, tactics = arrays["trace"], arrays["tactics"]
    time = np.arange(1, len(tactics) + 1, dtype=float) * params["dt"]
    require(np.allclose(tactics[:, 0], time, atol=1e-9, rtol=0) and
            np.array_equal(trace[:, 60], tactics[:, 0]) and np.isin(tactics[:, 13], [0, 1]).all(),
            f"Invalid clock or gameRunning: {path}")
    teams = {}
    for index, team in enumerate(TEAMS):
        counts = team_counts(trace, tactics, period, params, index)
        require(counts["shots"] == metrics["shots"][index] and counts["goals"] == metrics["goals"][index]
                and counts["midfielderShots"] == metrics["midfielderShots"][index]
                and counts["entries"] == metrics["takeoverEntries"][index], f"Receipt differs: {path}")
        if not MASKS[policy][index]:
            require(counts["returns"] == 0, f"Unexpected default-team handback: {path}/{team}")
        teams[team] = counts
    return {"teams": teams, "artifactSha256": artifact["sha256"], "arraySha256": digests}


def audit(out, reference):
    paths = dict(default=reference / "v1", redOnly=out / "red-only",
                 blueOnly=out / "blue-only", both=reference / "recovery")
    workers = {key: checked_worker(path) for key, path in paths.items()}
    require(workers["redOnly"]["finishedAtUtc"] <= workers["blueOnly"]["startedAtUtc"],
            "The red-only campaign must precede the blue-only campaign")
    for left, right in (("default", "both"), ("redOnly", "blueOnly")):
        require(all(workers[left][field] == workers[right][field]
                    for field in ("sourceFingerprint", "revision")), "Different sources within campaign")
    snapshot = {key: {k: w[k] for k in ("revision", "sourceFingerprint", "startedAtUtc", "finishedAtUtc")}
                for key, w in workers.items()}
    paired = []
    for period, seed, case in cases():
        frozen = {p: read(ARCHIVE / p / case / "receipt.json")["parameters"] for p in ("v1", "recovery")}
        games = {}
        for policy in POLICIES:
            params = frozen["v1" if policy == "default" else "recovery"]
            games[policy] = audit_game(policy, paths[policy], workers[policy], case, period, seed, params)
        paired.append({"case": case, "periodMs": period, "seed": seed, "policies": games})
    return {"sources": snapshot, "pairs": paired}


def effects(y):
    # Signed changes in red goals with the other policy held fixed.
    red_at_v1 = y["redOnly"] - y["default"]
    red_at_auto = y["both"] - y["blueOnly"]
    blue_at_v1 = y["blueOnly"] - y["default"]
    blue_at_auto = y["both"] - y["redOnly"]
    return {"redChangeBlueDefault": red_at_v1, "redChangeBlueAuto": red_at_auto,
            "blueChangeRedDefault": blue_at_v1, "blueChangeRedAuto": blue_at_auto,
            "interaction": red_at_auto - red_at_v1, "delta": y["both"] - y["default"],
            "redOrderAverage": (red_at_v1 + red_at_auto) / 2,
            "blueOrderAverage": (blue_at_v1 + blue_at_auto) / 2}


def aggregate(rows):
    totals = {}
    zero_shot_matches = {}
    for policy in POLICIES:
        totals[policy] = {}
        zero_shot_matches[policy] = {}
        for team in TEAMS:
            frames = [r["policies"][policy]["teams"][team] for r in rows]
            for record in frames:
                require(all(isinstance(record[k], int) and record[k] >= 0 for k in TEAM_FIELDS) and
                        record["liveMs"] == sum(record[k] for k in ("midfielderMs", "strikerMs", "unassignedMs")) and
                        record["shots"] == record["midfielderShots"] + record["strikerShots"],
                        "Invalid signed-off time or shot split")
            totals[policy][team] = {k: sum(r[k] for r in frames) for k in TEAM_FIELDS}
            zero_shot_matches[policy][team] = sum(r["shots"] == 0 for r in frames)
    require(all(totals[p][t]["returns"] > 0 for p in POLICIES for i, t in enumerate(TEAMS) if MASKS[p][i]),
            "No handback observed for an automatic team in this group")
    red = {p: totals[p]["red"]["goals"] for p in POLICIES}
    contrasts = effects(red)
    require(contrasts["redOrderAverage"] + contrasts["blueOrderAverage"] == contrasts["delta"],
            "Order averages do not add up")
    signs = {}
    for key in ("redChangeBlueDefault", "redChangeBlueAuto", "blueChangeRedDefault", "blueChangeRedAuto"):
        deltas = [effects({p: r["policies"][p]["teams"]["red"]["goals"] for p in POLICIES})[key] for r in rows]
        signs[key] = {"fewer": sum(x < 0 for x in deltas), "equal": sum(x == 0 for x in deltas),
                      "more": sum(x > 0 for x in deltas)}
    return {"pairs": len(rows), "totals": totals, "zeroShotMatches": zero_shot_matches,
            "redGoalEffects": contrasts, "withinPairRedGoalChanges": signs}


def summarize(data):
    require([(r["periodMs"], r["seed"], r["case"]) for r in data["pairs"]] == list(cases()),
            "Incomplete or unordered paired seed/period set")
    return {"status": "PASS", "pairSets": 40, "uniqueSeeds": 20, "newFullMatches": 80,
            "totalFullMatches": 160, "totalControlSteps": 2160000,
            "teamMaskOrder": list(TEAMS), "automaticTeams": MASKS,
            "all": aggregate(data["pairs"]),
            "byPeriodMs": {str(dt): aggregate([r for r in data["pairs"] if r["periodMs"] == dt])
                           for dt in PERIODS}}


def signed(value):
    return f"{value:+g}" if value else "0"


def table(group):
    lines = ["|策略|队伍|有效比赛时间（s）|中场授权|前锋授权|无人授权|中场射门|前锋射门|总射门|零射门场次|进球|",
             "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for policy in POLICIES:
        for team, label in zip(TEAMS, ("蓝", "红")):
            r = group["totals"][policy][team]
            rates = [r[k] / r["liveMs"] for k in ("midfielderMs", "strikerMs", "unassignedMs")]
            lines.append(f'|{LABELS[policy]}|{label}|{r["liveMs"]/1000:.2f}|{rates[0]:.2%}|{rates[1]:.2%}|'
                         f'{rates[2]:.2%}|{r["midfielderShots"]}|{r["strikerShots"]}|{r["shots"]}|'
                         f'{group["zeroShotMatches"][policy][team]}|{r["goals"]}|')
    return lines


def render(result, data):
    all_games = result["all"]
    e = all_games["redGoalEffects"]
    counts = [all_games["totals"][p]["red"]["goals"] for p in POLICIES]
    if e["redOrderAverage"] < e["blueOrderAverage"]:
        verdict = "红队自己的交还策略对红队总进球下降的平均影响更大。"
    elif e["blueOrderAverage"] < e["redOrderAverage"]:
        verdict = "蓝队的交还策略对红队总进球下降的平均影响更大。"
    else:
        verdict = "按两种切换顺序平均，两队策略对红队总进球的影响相等。"
    lines = ["# 红队和蓝队分别自动交还的配对比赛", "",
             f"红队总进球为双方默认 **{counts[0]}**、仅红自动 **{counts[1]}**、仅蓝自动 **{counts[2]}**、双方自动 **{counts[3]}**。{verdict}", "",
             f'固定蓝队使用默认 V1，单独切换红队，红队进球变化 {signed(e["redChangeBlueDefault"])}，'
             f'固定蓝队使用自动交还，切换红队，变化 {signed(e["redChangeBlueAuto"])}。'
             f'固定红队使用默认 V1，单独切换蓝队，红队进球变化 {signed(e["blueChangeRedDefault"])}，'
             f'固定红队使用自动交还，切换蓝队，变化 {signed(e["blueChangeRedAuto"])}。', "",
             f'两条切换顺序各占一半时，红队策略对应 {signed(e["redOrderAverage"])} 球、'
             f'蓝队策略对应 {signed(e["blueOrderAverage"])} 球，两项合计 {signed(e["delta"])} 球。'
             f'交互项为 {signed(e["interaction"])} 球（双方自动 − 仅红自动 − 仅蓝自动 + 双方默认）。'
             '平均数描述这批配对比赛的总进球差。非整数来自平均两条顺序。', "",
             "同一周期内每个种子配齐四种策略，每场 600 s。先完成仅红自动的 40 场，再完成仅蓝自动的 40 场。"
             "全默认和全自动的物理、战术轨迹逐场核对归档数组哈希。所有场次共享开球站位、场地、踢球噪声与普通参数，"
             "自动队沿用 0.50 s 恢复阈值。双方颜色和开球方向固定，20 个种子在两个周期各重复使用一次。策略会改变实际出脚的次数和时刻，同种子的踢球噪声序列随实际出脚依次使用。", "",
             "## 两队追球授权、射门和进球", "",
             "每队的分母是该队比赛进行时的时间，以每拍控制周期换算秒数汇总。"
             "中场、前锋、无人授权是逐拍互斥的三类。无人授权时，守门员和后卫仍可按站位移动。"
             "射门按实际出脚且请求速度达到 1.8 m/s 计，并逐拍核对裁判计数器。进球取比赛比分。", ""]
    lines.extend(table(all_games))
    lines += ["", "## 固定另一方后，红队进球在哪些配对改变", "",
              "|切换哪一方|另一方策略|红队少进球的配对数|相同|多进球的配对数|总进球变化|",
              "|---|---|---:|---:|---:|---:|"]
    for changed, other, key in (("红队", "蓝队默认", "redChangeBlueDefault"),
                                ("红队", "蓝队自动", "redChangeBlueAuto"),
                                ("蓝队", "红队默认", "blueChangeRedDefault"),
                                ("蓝队", "红队自动", "blueChangeRedAuto")):
        signs = all_games["withinPairRedGoalChanges"][key]
        lines.append(f'|{changed}|{other}|{signs["fewer"]}|{signs["equal"]}|{signs["more"]}|{signed(e[key])}|')
    lines += ["", "## 两个周期各自的变化", "",
              "|控制周期|双方默认红球|仅红自动红球|仅蓝自动红球|双方自动红球|红方顺序平均变化|蓝方顺序平均变化|交互项|",
              "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for dt in PERIODS:
        group = result["byPeriodMs"][str(dt)]
        vals = [group["totals"][p]["red"]["goals"] for p in POLICIES]
        ef = group["redGoalEffects"]
        lines.append(f'|{dt} ms|' + '|'.join(map(str, vals)) +
                     f'|{signed(ef["redOrderAverage"])}|{signed(ef["blueOrderAverage"])}|{signed(ef["interaction"])}|')
    for dt in PERIODS:
        lines += ["", f"### {dt} ms，各配置 20 场", ""]
        lines.extend(table(result["byPeriodMs"][str(dt)]))
    lines += ["", "## 各配对的比分和射门", "",
              "每格先列蓝红比分，再列蓝红射门。逐场授权时长、实际交还次数和原始 MAT 的哈希保存在 [paired-runs.json](paired-runs.json)。"
              "分周期汇总以及单侧切换后红队进球减少、持平、增加的配对数见 [analysis.json](analysis.json)。", "",
              "|控制周期|种子|双方默认|仅红自动|仅蓝自动|双方自动|", "|---:|---:|---|---|---|---|"]
    for r in data["pairs"]:
        scores = []
        for p in POLICIES:
            teams = r["policies"][p]["teams"]
            b, red = teams["blue"], teams["red"]
            scores.append(f'{b["goals"]}∶{red["goals"]}，{b["shots"]}∶{red["shots"]}')
        lines.append(f'|{r["periodMs"]} ms|{r["seed"]}|' + '|'.join(scores) + '|')
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--reference", type=Path, default=ARCHIVE)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Rebuild summary from signed-off counts; no MAT files needed")
    mode.add_argument("--render", type=Path, help="Render a new Markdown file from signed-off counts")
    args = parser.parse_args()
    paired = args.out / "paired-runs.json"
    result_file = args.out / "analysis.json"
    page = args.out / "summary.md"
    if args.check or args.render:
        data = read(paired)
        small_receipt_check(args.out, data)
        result = summarize(data)
        text = render(result, data)
        require(read(result_file) == result, "Stored analysis differs from paired audit counts")
        if args.check:
            require(page.read_text() == text, "Markdown and paired counts differ")
        else:
            with args.render.open("x") as stream:
                stream.write(text)
        return
    require(not any(p.exists() for p in (paired, result_file, page)), "Use a new analysis output")
    data = audit(args.out, args.reference)
    small_receipt_check(args.out, data)
    result = summarize(data)
    text = render(result, data)
    write_new(paired, data)
    write_new(result_file, result)
    with page.open("x") as stream:
        stream.write(text)
    print(f"Audited {result['totalFullMatches']} full matches, four policies, 40 paired seed/period cases.")


if __name__ == "__main__":
    main()
