from pathlib import Path
import subprocess,json,time,datetime,sys
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent/sys.argv[1];out.mkdir(exist_ok=False);cmd=sys.argv[2:]
record={'command':cmd,'cwd':str(root),'startUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'RUNNING'}
start=time.monotonic()
with (out/'stdout.log').open('w') as log:
 p=subprocess.Popen(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT);record['childPid']=p.pid;(out/'command.json').write_text(json.dumps(record,indent=2));code=p.wait()
record.update(status='PASS' if code==0 else 'FAIL',exitCode=code,endUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),wallSeconds=time.monotonic()-start)
(out/'command.json').write_text(json.dumps(record,indent=2));print(json.dumps(record,indent=2));print('Log:',out/'stdout.log');raise SystemExit(code)
