"""Render the verified team tactics match, viewer and legacy receipts for the manual."""
from argparse import ArgumentParser
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'evidence/tactics-v1'
TARGET = ROOT / 'docs/generated/v1_results.md'


def read(path):
    return json.loads(path.read_text())


def team(values, fmt=',d'):
    return ' / '.join(format(x, fmt) for x in values)


def render():
    suite = EVIDENCE / 'matrix-final-01'
    result = read(suite / 'receipt.json')
    summary = read(suite / 'summary/receipt.json')
    assert result['status'] == 'PASS' and summary['status'] == 'PASS_40_V1_MATCHES'
    assert result['totalOfficialSteps'] == summary['totalOfficialSteps'] == 540000
    periods = summary['periods']
    assert [(p['period'], p['matches']) for p in periods] == [(.05, 20), (.04, 20)]
    legacy = read(EVIDENCE / 'legacy-01/receipt.json')
    launcher = read(EVIDENCE / 'launcher-02/receipt.json')
    assert legacy['status'] == 'PASS' and launcher['status'] == 'PASS'
    live = read(EVIDENCE / 'launcher-02/recorded-motion.json')
    match = read(EVIDENCE / 'launcher-02/match-receipt.json')
    case = read(EVIDENCE / 'outcome-review-01/receipt.json')['review']
    controls = read(EVIDENCE / 'viewer-02/artifacts/receipt.json')
    assert controls['status'] == 'PASS' and controls['pixels']['changed']
    assert controls['controls']['pausedTime'] == controls['controls']['frozenTime']
    samples = controls['controls']['samples']
    tests = read(suite / 'tests.json')
    assert all(tests['passed']) and not any(tests['failed']) and not any(tests['incomplete'])
    rows = []
    for p in periods:
        dt = p['period']
        values = [f"{dt * 1000:.0f}", str(p['matches']), f"{p['steps']:,}", team(p['goals']),
                  str(p['matchesWithGoal']), team(p['shots']), team(p['actualKicks']),
                  team(p['midfielderShots']), str(p['distinctTraces'])]
        rows.append('| ' + ' | '.join(values) + ' |')
    lines = [
        '# 球队 V1 二维整场验收', '',
        f"独立 MATLAB 进程在提交 `{summary['revision'][:12]}` 的全新本地克隆中从空白重建控制器和八机器人模型。"
        f"{len(tests['passed'])} 项战术、模型与指标测试通过。MATLAB 内重建、测试、比赛及额外回放合计耗时 "
        f"{result['elapsedSeconds']:.1f} 秒（{result['elapsedSeconds']/60:.1f} 分钟）。[一键回执](../../evidence/tactics-v1/matrix-final-01/receipt.json)", '',
        '双方均用同一 V1 策略，各队共四人。每场 600 仿真秒，蓝队攻 +x。下表双数的顺序均为蓝 / 红。“有进球场数”指双方至少一方得分的场次。“射门”按实际执行且达到射门速度的踢球计数。', '',
        '| 周期 ms | 场数 | 采样步 | 进球 | 有进球场数 | 射门 | 实际踢球 | 其中 MF 射门 | 不同物理轨迹 |',
        '|---:|---:|---:|---:|---:|---:|---:|---:|---:|', *rows, '',
        '| 周期 ms | 首次触球范围 s | 无触球场数 | 中场接管累计 s | 接管时间占各队比赛时间 | 重叠步数 | 机器人越比赛线采样 | 机器人越外缓冲界采样 | 完全受阻平移请求 |',
        '|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
    ]
    for p in periods:
        seconds = p['steps'] * p['period']
        times = p['firstTouchRangeSeconds']
        first = '–'.join(f'{v:.2f}' for v in times) if times else '未发生'
        values = [f"{p['period']*1000:.0f}", first, str(p['matchesWithoutTouch']),
                  team(p['takeoverSeconds'], ',.2f'), team([s/seconds for s in p['takeoverSeconds']], '.2%'),
                  str(p['overlapSteps']), f"{p['outsidePitchRobotSamples']:,}", f"{p['outsideBorderRobotSamples']:,}",
                  f"{p['blockedTranslationSamples']:,} / {p['translationRequests']:,}（{p['blockedTranslationRatio']:.3%}）"]
        lines.append('| ' + ' | '.join(values) + ' |')
    lines.extend([
        '', '越线以机器人外缘为准，逐机器人逐拍计数。重叠按两身体穿透超过 10⁻⁸ m 计步。完全受阻指请求了平移、该拍实际位移仍小于等于 10⁻¹⁰ m。每场的进球、请求与反馈编号、实际踢球者、几何指标和轨迹哈希可从汇总回执追溯。[逐场证据索引](../../evidence/tactics-v1/matrix-final-01/summary/receipt.json)', '',
        f"两个周期各对种子 1 额外重放完整 600 秒，物理轨迹和战术日志分别逐元素相同。40 场共 {summary['totalOfficialSteps']:,} 步，均通过固定角色、单一追球授权、踢球时效、动作编号去重和实际射门计数核对。实际踢球与同拍球位移共同出现的次数在 50 ms、40 ms 下分别为 {periods[0]['physicalKickStepsWithBallMotion']:,} 和 {periods[1]['physicalKickStepsWithBallMotion']:,}。", '',
        '故障后中场保留 MF 身份。默认比赛关闭人工恢复窗口，因此一次匹配的 ST 执行失败可以让中场持续接管到终场。定向实验另外验证了收到显式恢复后的撤权与交接。[真实交接时间线](v1_model_events.md)', '',
        f"图形入口在独立显示器上运行了 {launcher['frames']} 帧，首次编译与初始化耗时 {match['initializationSeconds']:.1f} 秒。八台机器人全部移动，球累计移动 {live['ballTravelMetres']:.3f} m，发生 {live['actualKickSteps']} 次实际踢球。窗口响应关窗并正常退出。旧 ACompat 另跑了 {legacy['matches']} 场，同 A 的进球、射门、首次触球全部一致。零踢球噪声最大逐元素误差为 {legacy['zeroNoiseMaximumDifference']:.5g}。默认噪声的轨迹分歧按场保存。[动画回执](../../evidence/tactics-v1/launcher-02/receipt.json) · [旧行为回归](../../evidence/tactics-v1/legacy-01/receipt.json)", '',
        f"下图是 V1 窗口继续比赛后的实际画面。两队各自的金圈跟随追球授权。点击暂停后，引擎在第 {samples['confirmed']['frame']} 帧确认暂停；间隔 {samples['held']['wallSecondsSinceConfirmation']:.3f} 墙钟秒再次取样，引擎时刻仍为 {samples['held']['engineTime']:.2f} 仿真秒。继续到第 {samples['resumed']['frame']} 帧时，引擎已恢复运行。该段全部物理采样与无动画比赛逐元素一致。[暂停与继续回执](../../evidence/tactics-v1/viewer-02/artifacts/receipt.json)", '',
        '![V1 实时比赛继续后的实测画面](v1-live.png)', '',
        f"50 ms、种子 1 打成 0∶0，蓝队 {case['shotsBlueRed'][0]} 次射门在下一次踢球前首次接触的对手均为红队 6 号后卫。球从射点到这次接触的中位位移为 {case['displacementToFirstOpponentContactMetres']['median']:.3f} m，中位用时 {case['secondsUntilFirstOpponentContact']['median']:.2f} s。此处逐次检查仅覆盖这一场。[逐次碰撞复算](../../evidence/tactics-v1/outcome-review-01/README.md)", '',
        '本组实验覆盖同策略、既定开球与初始站位下的二维比赛。更换开球、互换场向、引入其它对手或上三维平台，需要分别设计实验。二维射门速度和滚动减速度沿用现有参数，实机得分率和接触动力学仍待测。', '',
    ])
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    rendered = render()
    image = (EVIDENCE / 'viewer-02/artifacts/live-after.png').read_bytes()
    image_path = TARGET.with_name('v1-live.png')
    if args.check:
        if TARGET.read_text() != rendered or image_path.read_bytes() != image:
            raise SystemExit('The generated V1 results differ from the verified receipts')
        print('V1 match results match the verified receipts')
    else:
        TARGET.write_text(rendered)
        image_path.write_bytes(image)
