"""Prove the bootstrap regression detects removal of first-frame retransmission."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
suffix=sys.argv[1] if len(sys.argv)>1 else ''
assert not suffix or re.fullmatch(r'[A-Za-z0-9_-]+',suffix)
out=root/('build/mutations/'+suffix+'/ros-bootstrap' if suffix else 'evidence/6/ros-bootstrap-race-mutation-01')
out.mkdir(parents=True,exist_ok=False)
clone=root/('build/mutation-ros-bootstrap'+('-'+suffix if suffix else ''))
shutil.copytree(root,clone,ignore=shutil.ignore_patterns('.git','build','evidence','robot-soccer-starter'))
source=clone/'ros2/tdp_webots_bridge/tdp_webots_bridge/bootstrap.py'
original=source.read_text();old='            publish_camera(image)\n'
assert original.count(old)==1
source.write_text(original.replace(old,'            # Mutation: omit frozen image retransmission.\n',1))
result=subprocess.run(['python3','-m','unittest','discover','-s','tests','-p','test_webots.py','-v'],cwd=clone,text=True,capture_output=True)
log=result.stdout+result.stderr;(out/'tests.log').write_text(log)
detected=result.returncode!=0 and 'FAIL: test_bootstrap_delayed_discovery' in log and 'FAIL: test_bootstrap_lost_first_images' in log and 'ERROR:' not in log
receipt={'suite':'test_webots.py','mutation':'omit frozen camera retransmission while keeping clock publication',
         'detected':detected,'exitCode':result.returncode,'originalSHA256':hashlib.sha256(original.encode()).hexdigest(),
         'mutatedSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),
         'scope':'deterministic transport boundary assertions; actual DDS/Webots integration is separate'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt));assert detected
