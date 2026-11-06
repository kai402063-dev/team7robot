#!/usr/bin/env python3
"""Preserve one command, output and wall time per independent manual attempt."""
from pathlib import Path
import subprocess, json, time, datetime, sys
root=Path(__file__).resolve().parents[2]
label=sys.argv[1];cmd=sys.argv[2:]
out=Path(__file__).resolve().parent/label
out.mkdir(exist_ok=False)
record={'command':cmd,'cwd':str(root),'startUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'RUNNING'}
(out/'command.json').write_text(json.dumps(record,indent=2))
start=time.monotonic()
with (out/'stdout.log').open('w') as log:
 result=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
record.update(status='PASS' if result.returncode==0 else 'FAIL',exitCode=result.returncode,endUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),wallSeconds=time.monotonic()-start)
(out/'command.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2));print('Log:',out/'stdout.log')
raise SystemExit(result.returncode)
