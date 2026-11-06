"""Run both committed-model validation shards using independent MATLAB processes and caches."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import time

root = Path.cwd()
command_dir = root / 'build/release-command-01'
out = root / 'evidence/tactics-v1/release-matrix-01'
commit = 'a324545cde4adc35adcb49801888d17459773627'
head = subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert head == commit and not subprocess.check_output(['git','status','--porcelain']).strip()
out.mkdir()
def now():
    return datetime.now(timezone.utc).isoformat()
def run(ms):
    live = command_dir / str(ms)
    live.mkdir()
    prefs = command_dir / f'prefs-{ms}'
    cache_id = f'v1release_{ms}ms'
    env = dict(os.environ,TDP_CACHE_ID=cache_id,TDP_MATLAB_PREFDIR=str(prefs))
    statement = f"tdpSetup; validate_v1_matrix('evidence/tactics-v1/release-matrix-01/matches-{ms}ms',{ms}/1000,1:20);"
    args = ['./scripts/run_matlab.sh',statement]
    receipt = {'status':'RUNNING','revision':head,'cleanAtStart':True,'rebuild':False,'periodSeconds':ms/1000,
               'seeds':list(range(1,21)),'executionRoot':str(root),'startedAtUtc':now(),
               'cacheId':cache_id,'preferencePath':str(prefs),'command':args}
    start = time.monotonic()
    progress = live / 'command.json'
    progress.write_text(json.dumps(receipt,indent=2)+'\n')
    with (live/'matlab.log').open('x') as log:
        rc = subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT).returncode
    receipt.update(status='PASS' if rc == 0 else 'FAIL',exitCode=rc,finishedAtUtc=now(),elapsedSeconds=time.monotonic()-start)
    progress.write_text(json.dumps(receipt,indent=2)+'\n')
    print(ms,receipt['status'],receipt['elapsedSeconds'],flush=True)
    return rc
with ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(run,(50,40)))
raise SystemExit(int(any(results)))
