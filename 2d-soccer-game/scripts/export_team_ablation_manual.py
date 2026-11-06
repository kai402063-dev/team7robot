"""Publish or check the short manual table using the checked four-policy report."""
from argparse import ArgumentParser

from analyze_team_ablation import ROOT, read, require, signed, table

RUN = ROOT / "evidence/team-ablation/clean-01"
PAGE = ROOT / "docs/generated/team_ablation.md"


def render():
    result = read(RUN / "analysis.json")
    run = read(RUN / "receipt.json")
    require(result["status"] == run["status"] == "PASS", "The full comparison must pass first")
    group = result["all"]
    impact = group["redGoalEffects"]
    lines = ["# 只给一队自动交还的实测结果", "",
             f'同样的 {result["uniqueSeeds"]} 个种子各跑 50 和 40 ms。'
             f'每组 {result["pairSets"]} 场，每场 600 s。干净克隆完成全部验证用时 '
             f'{run["elapsedSeconds"]/60:.1f} 分钟，其中包括独立重复回放和轨迹核对。', ""]
    lines += table(group)
    lines += ["", "中场、前锋和无人获准追球三项百分比均按比赛有效时间加权。蓝队固定攻 +x，红队固定攻 −x。", "",
              f'固定蓝队默认，红队切换后其进球变化为 {signed(impact["redChangeBlueDefault"])}；'
              f'固定蓝队自动，变化为 {signed(impact["redChangeBlueAuto"])}。'
              f'固定红队默认，蓝队切换后红队进球变化为 {signed(impact["blueChangeRedDefault"])}；'
              f'固定红队自动，变化为 {signed(impact["blueChangeRedAuto"])}。', "",
              "[两周期分表、逐场比较和归因方法](../../evidence/team-ablation/clean-01/summary.md) · "
              "[运行方法](../chapters/team_ablation.md)", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        require(PAGE.read_text() == render(), "Manual differs from the measured results")
    else:
        PAGE.write_text(render())
