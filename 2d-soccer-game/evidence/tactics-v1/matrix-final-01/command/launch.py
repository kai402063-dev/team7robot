import datetime
import json
import os
from pathlib import Path
import subprocess
import time
root=Path.cwd()
out=root/'build/v1-clean-command-01'
info=out/'command.json'
assert not info.exists()
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
status=subprocess.check_output(['git','status','--porcelain'],text=True)
assert head=='ca87cb149cf7b71e5ad5ae1ea7396dd64f981b2c' and not status
env=os.environ.copy()
env['TDP_CACHE_ID']='v1_clean_matrix_01'
env['TDP_MATLAB_PREFDIR']=str(root/'build/v1-clean-matlab-prefs')
cmd=['./scripts/run_matlab.sh',"tdpSetup; reproduce_v1('evidence/tactics-v1/matrix-final-01');"]
r={'status':'RUNNING','sourceCommit':head,'cleanAtStart':True,'command':cmd,
   'executionRoot':str(root),'cacheId':env['TDP_CACHE_ID'],'preferences':env['TDP_MATLAB_PREFDIR'],
   'startedAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
info.write_text(json.dumps(r,indent=2)+'\n')
started=time.monotonic()
try:
 with (out/'matlab.log').open('x') as log:
  job=subprocess.run(cmd,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
 r.update(status='PASS' if job.returncode==0 else 'FAIL',exitCode=job.returncode)
finally:
 r['elapsedSeconds']=time.monotonic()-started
 r['finishedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 info.write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r));raise SystemExit(r['exitCode'])
