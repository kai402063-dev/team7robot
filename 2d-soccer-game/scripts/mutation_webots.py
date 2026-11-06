"""A real assertion mutation in a task-owned copy of the Webots executor."""
from pathlib import Path
import json
import sys
import re
import shutil
import subprocess
root=Path(__file__).resolve().parents[1]
suffix=sys.argv[1] if len(sys.argv)>1 else ''
assert not suffix or re.fullmatch(r'[A-Za-z0-9_-]+',suffix)
out=root/('build/mutations/'+suffix+'/webots-executor' if suffix else 'evidence/5/mutation-executor-01');out.mkdir(exist_ok=False,parents=True)
clone=root/('build/mutation-webots-v1'+('-'+suffix if suffix else ''))
shutil.copytree(root,clone,ignore=shutil.ignore_patterns('.git','build','evidence','robot-soccer-starter'))
p=clone/'ros2/tdp_webots_bridge/tdp_webots_bridge/motion_executor.py';s=p.read_text();old='        if rid==self.seen_id:\n            return'
assert old in s;s=s.replace(old,'        if False:\n            return',1);p.write_text(s)
result=subprocess.run(['python3','-m','unittest','discover','-s','tests','-p','test_webots.py','-v'],cwd=clone,text=True,capture_output=True)
log=result.stdout+result.stderr;(out/'tests.log').write_text(log)
detected=result.returncode!=0 and 'FAIL: test_duplicate_and_ball_independent_completion' in log and 'ERROR:' not in log
(out/'receipt.json').write_text(json.dumps({'suite':'test_webots.py','mutation':'remove repeated request guard','detected':detected,'exitCode':result.returncode},indent=2)+'\n')
assert detected
