"""Generate the team's handoff timelines from the passing model suite log."""
import argparse
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'evidence/tactics-v1/model-tests-02'
DOCS = ROOT / 'docs/generated'
NAMES = {
    'normal-shot': 'ST 正常射门',
    'unavailable-during-preparation': 'ST 准备中不可用',
    'confirmed-execution-failure': 'ST 动作确认失败',
    'mf-shoots': 'MF 接管并射门',
    'return-to-st': 'MF 准备中交还',
    'stop-during-preparation': '准备中停赛',
    'loss-during-preparation': '准备中全队失球',
    'stale-during-preparation': '准备中本机观测过期',
    'no-feedback-core-replay': '单机无反馈超时',
}


def sequence(value):
    if not isinstance(value, list):
        value = [value]
    return ' → '.join(f'{item:.12g}' for item in value)


def documents():
    receipt = json.loads((SOURCE / 'receipt.json').read_text())
    assert all(receipt['passed']) and not any(receipt['incomplete'])
    events = [json.loads(raw) for raw in re.findall(
        r'V1_CASE (\{[^\n]*\})', (SOURCE / 'matlab.log').read_text())]
    expected = {(name, dt) for name in NAMES for dt in (.04, .05)}
    assert {(e['case'], e['dt']) for e in events} == expected and len(events) == len(expected)
    lines = ['# V1 动作交接实测', '',
             '此页由实际 MATLAB 测试日志生成。时间取模型输入 tSim，单位为秒。'
             '一次跨时刻记录用箭头连接，机器人编号为全场编号。', '',
             '| 场景 | 周期 (ms) | 机器人 | tSim | 蓝队授权者 | 有效请求类型 | 请求编号 | 反馈状态 | 实际踢球者 |',
             '|---|---:|---:|---|---|---|---|---|---|']
    for e in events:
        if e['case'] == 'no-feedback-core-replay':
            continue
        label = NAMES[e['case']]
        values = [label, str(round(1000 * e['dt'])), str(e['robot'])]
        values += [sequence(e[k]) for k in ('tSim', 'blueOwner', 'kind', 'requestId', 'status', 'kicker')]
        lines.append('| ' + ' | '.join(values) + ' |')
    lines += ['', '类型 0 为 Stop，2 为 Kick。反馈 1 为 Running，2 为 Done，3 为 Failed。'
              '实际踢球者 0 表示本拍没有对球施加踢球速度。', '',
              '| 无反馈回放周期 (ms) | 请求编号 | 进入 Kick (s) | 进入 Recover (s) | 实际等待 (s) |',
              '|---:|---:|---:|---:|---:|']
    for e in events:
        if e['case'] == 'no-feedback-core-replay':
            values = [str(round(1000 * e['dt']))]
            values.extend(sequence(e[k]) for k in ('requestId', 'kickTime', 'recoverTime', 'elapsedSeconds'))
            lines.append('| ' + ' | '.join(values) + ' |')
    lines += ['', '无反馈场景使用同一个 ControllerCore 库的 tdpReplay 台架。'
              '其余表中事件来自八机器人 tdpV1Match 与真实的二维动作执行层。', '']
    return {'v1_model_events.json': json.dumps(events, indent=2) + '\n',
            'v1_model_events.md': '\n'.join(lines)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, content in documents().items():
        path = DOCS / name
        if args.check:
            assert path.read_text() == content, f'Generated model timeline differs: {name}'
        else:
            path.write_text(content)
