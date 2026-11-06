"""Generate manual animation numbers and figures from a passing GUI receipt."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def generate(artifacts):
    artifacts = Path(artifacts).resolve()
    receipt_path = artifacts / 'receipt.json'
    r = json.loads(receipt_path.read_text())
    assert r['status'] == 'PASS' and all(r['tests']['passed'])
    assert r['pixels']['changed'] and r['closedDuringRun']
    out = ROOT / 'docs/generated'
    values = {
        'source': str(receipt_path.relative_to(ROOT)),
        'testsPassed': sum(r['tests']['passed']),
        'pausedSimulationTime': r['controls']['pausedTime'],
        'frozenSimulationTime': r['controls']['frozenTime'],
        'stoppedFrames': r['controls']['partialFrames'],
        'restartFrames': r['restart']['frames'],
    }
    figures = {}
    for name in ('live-before.png', 'live-after.png'):
        target = out / ('animation-' + name)
        shutil.copyfile(artifacts / name, target)
        figures[target.name] = hashlib.sha256(target.read_bytes()).hexdigest()
    values['figures'] = figures
    launch_dir = ROOT / 'evidence/animation/launch-e2e-01'
    launch = json.loads((launch_dir / 'receipt.json').read_text())
    match = json.loads((launch_dir / 'match-receipt.json').read_text())
    assert launch['status'] == 'PASS' and launch['naturalExitAfterClose']
    assert hashlib.sha256((launch_dir / 'match-receipt.json').read_bytes()).hexdigest() == launch['matchReceiptSha256']
    values.update(launcherSource=str((launch_dir / 'receipt.json').relative_to(ROOT)),
                  launcherFrames=launch['frames'], coldInitializationSeconds=match['initializationSeconds'],
                  launcherElapsedSeconds=launch['elapsedSeconds'])
    (out / 'animation_numbers.json').write_text(json.dumps(values, indent=2) + '\n')
    rows = '\n'.join(f'| {key} | {values[key]:.15g} |' for key in (
        'testsPassed', 'pausedSimulationTime', 'frozenSimulationTime', 'stoppedFrames', 'restartFrames',
        'launcherFrames', 'coldInitializationSeconds', 'launcherElapsedSeconds'))
    text = '# 实际动画验证数值\n\n本页由 `scripts/export_animation_manual.py` 从通过的私有显示回执生成。\n\n'
    text += f'来源：`{values["source"]}`。窗口真实渲染于任务独占的虚拟显示；未操作用户桌面。\n\n'
    text += '| 项目 | 实测值 |\n|---|---:|\n' + rows + '\n\n'
    text += '最后三项来自实跑 `./start_2d.sh` 的单独冷启动；总墙钟包括 MATLAB 启动、编译、Max 比赛和关闭，不是实时倍率或启动时长保证。\n\n'
    text += '前后两帧来自同一次逐步运行；暂停、倍速和停止不改变未加动画的轨迹前缀。\n\n'
    text += '![前帧](animation-live-before.png)\n\n![后帧](animation-live-after.png)\n'
    (out / 'animation_numbers.md').write_text(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('artifacts')
    generate(parser.parse_args().artifacts)
