"""Negative-control mutation: a completed motion with a frozen recorded ball."""
import hashlib
import json
import sys
import re
from pathlib import Path
import shutil
from analyze_webots import analyze
root=Path(__file__).resolve().parents[1]
suffix=sys.argv[1] if len(sys.argv)>1 else ''
assert not suffix or re.fullmatch(r'[A-Za-z0-9_-]+',suffix)
source=root/'evidence/5/closed-02';target=root/('build/mutation-webots-trace-v1'+('-'+suffix if suffix else ''))
shutil.copytree(source,target)
p=target/'webots-records.json';rows=json.loads(p.read_text())
for row in rows:row['ball'][:2]=[0.0,0.0];row['ballVelocity'][:2]=[0.0,0.0]
p.write_text(json.dumps(rows)+'\n')
detected=False;reason=''
try:analyze(target)
except AssertionError as exc:reason=str(exc);detected=reason=='Ball displacement gate'
receipt={'suite':'Webots closed-loop gate','mutation':'Freeze only the recorded ball while retaining completed-motion evidence',
         'detected':detected,'reason':reason,'originalTraceSHA256':hashlib.sha256((source/'webots-records.json').read_bytes()).hexdigest(),
         'mutatedFixtureSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'note':'Synthetic mutation fixture; never presented as a physical run'}
out=root/('build/mutations/'+suffix+'/webots-trace' if suffix else 'evidence/5/mutation-trace-01');out.mkdir(exist_ok=False,parents=True)
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');assert detected
