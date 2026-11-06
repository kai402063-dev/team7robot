"""Mutate the scalar node in an isolated copy and require a numerical failure."""
import json
import sys
import re
import shutil
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
suffix=sys.argv[1] if len(sys.argv)>1 else ''
assert not suffix or re.fullmatch(r'[A-Za-z0-9_-]+',suffix)
out = ROOT / ('build/mutations/'+suffix+'/ros-integration' if suffix else 'evidence/4/mutation-integration-01')
out.mkdir(exist_ok=False, parents=True)
clone = ROOT / ('build/mutation-ros-integration-v1'+('-'+suffix if suffix else ''))
shutil.copytree(ROOT, clone, ignore=shutil.ignore_patterns('.git', 'build', 'evidence', 'robot-soccer-starter'))
p = clone / 'ros2/tdp_webots_bridge/tdp_webots_bridge/scalar_echo.py'
s = p.read_text();assert 'msg.data + 1.0' in s
p.write_text(s.replace('msg.data + 1.0', 'msg.data + 2.0'))
with (out / 'launch.log').open('w') as log:
    result = subprocess.run(['./scripts/run_ros.sh', 'python3', 'scripts/validate_ros.py', str(out / 'run')],
                            cwd=clone, stdout=log, stderr=subprocess.STDOUT, timeout=90)
r = json.loads((out / 'run/receipt.json').read_text())
actual = (out / 'run/scalar-echo.log').read_text()
detected = result.returncode != 0 and r['error'] == 'AssertionError()' and 'data: 5.5' in actual
(out / 'receipt.json').write_text(json.dumps({'suite':'ROS integration', 'mutation':'x+1 to x+2',
    'detected':detected, 'exitCode':result.returncode,'reason':'Actual ROS output 5.5 violates expected 4.5'}, indent=2)+'\n')
assert detected
