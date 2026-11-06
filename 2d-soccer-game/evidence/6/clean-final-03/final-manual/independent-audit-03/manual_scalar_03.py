"""Manual three-terminal scalar round trip with preserved discovery/cleanup logs."""
from pathlib import Path
import subprocess,json,signal,os,time,re,traceback
out=Path.cwd()/'build/independent-audit-03/scalar-01';out.mkdir(exist_ok=False)
logs=[];children=[];commands=[];communication=False;error=None;cleanup_errors=[]
def spawn(name,args):
 cmd=['./scripts/run_ros.sh']+args;commands.append(cmd)
 log=(out/(name+'.log')).open('w');logs.append(log)
 p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,start_new_session=True);children.append((name,p));return p
try:
 echo=spawn('scalar-node',['python3','-m','tdp_webots_bridge.scalar_echo']);time.sleep(2)
 subscriber=spawn('subscriber',['ros2','topic','echo','/tdp/scalar_out','std_msgs/msg/Float64','--once']);time.sleep(3)
 ready=False
 for attempt in range(1,4):
  assert echo.poll() is None and subscriber.poll() is None,'Scalar node or subscriber exited before discovery'
  path=out/f'discovery-{attempt:02d}.log';cmd=['./scripts/run_ros.sh','ros2','topic','info','/tdp/scalar_out','--verbose'];commands.append(cmd)
  with path.open('w') as log:result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=15)
  observed=path.read_text()
  if result.returncode==0 and re.search(r'^Publisher count:\s*1\s*$',observed,re.M) and re.search(r'^Subscription count:\s*1\s*$',observed,re.M):ready=True;break
  time.sleep(2)
 assert ready,'Output subscriber discovery not confirmed; no publication attempted'
 publisher=spawn('publisher',['ros2','topic','pub','--once','--wait-matching-subscriptions','1','/tdp/scalar_in','std_msgs/msg/Float64','{data: 3.5}'])
 assert publisher.wait(timeout=60)==0;assert subscriber.wait(timeout=60)==0
 info=spawn('topic-info',['ros2','topic','info','/tdp/scalar_out','--verbose']);assert info.wait(timeout=30)==0
 for f in logs:f.flush()
 observed=(out/'subscriber.log').read_text();assert re.search(r'^data:\s*4\.5\s*$',observed,re.M),observed
 communication=True
except Exception:
 error=traceback.format_exc()
finally:
 for name,p in children:
  try:
   for sig in [signal.SIGINT,signal.SIGTERM,signal.SIGKILL]:
    if p.poll() is not None:break
    try:os.killpg(p.pid,sig)
    except ProcessLookupError:break
    try:p.wait(timeout=5);break
    except subprocess.TimeoutExpired:continue
   if p.poll() is None:cleanup_errors.append(name+': process did not exit')
  except Exception:cleanup_errors.append(name+': '+traceback.format_exc())
 for f in logs:f.close()
 try:
  with (out/'daemon-cleanup.log').open('w') as log:
   result=subprocess.run(['./scripts/run_ros.sh','ros2','daemon','stop'],stdout=log,stderr=subprocess.STDOUT,timeout=30)
  if result.returncode!=0:cleanup_errors.append('ROS CLI daemon stop exit '+str(result.returncode))
 except Exception:cleanup_errors.append('ROS CLI daemon stop: '+traceback.format_exc())
receipt={'status':'PASS' if communication and not cleanup_errors else 'FAIL','communicationPassed':communication,'input':3.5,'output':4.5 if communication else None,'commands':commands,'terminalEquivalent':True,'error':error,'cleanupErrors':cleanup_errors}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2));raise SystemExit(0 if receipt['status']=='PASS' else 1)
