from pathlib import Path
import datetime,json,os,subprocess,time
root=Path.cwd()
out=root/'build/shipped-command-01'
env=os.environ.copy()
env['TDP_CACHE_ID']='prebuilt_v1_matrix'
env['TDP_MATLAB_PREFDIR']=str(root/'build/prebuilt-prefs')
cmd=['./scripts/run_matlab.sh',"tdpSetup; addpath(fullfile(pwd,'build','shipped-command-01')); check_prebuilt;"]
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
clean=not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
assert clean and head=='ca87cb149cf7b71e5ad5ae1ea7396dd64f981b2c'
info={'status':'RUNNING','commit':head,'cleanAtStart':clean,'command':cmd,
      'cacheId':env['TDP_CACHE_ID'],'executionRoot':str(root),'rebuild':False,
      'startedAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
with (out/'command.json').open('x') as f:json.dump(info,f,indent=2)
start=time.monotonic()
with (out/'matlab.log').open('x') as log:
 row=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
info.update(status='PASS' if row.returncode==0 else 'FAIL',exitCode=row.returncode,
            elapsedSeconds=time.monotonic()-start,finishedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(out/'command.json').write_text(json.dumps(info,indent=2)+'\n')
print(json.dumps(info));raise SystemExit(row.returncode)
