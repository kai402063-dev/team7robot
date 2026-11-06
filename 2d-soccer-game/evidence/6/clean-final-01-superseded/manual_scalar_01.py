"""Run the manual's three terminals concurrently; no copied audit script."""
from pathlib import Path
import subprocess, time, json, signal
root=Path.cwd();out=root/'build'/'independent-audit-01'/'scalar-01';out.mkdir(exist_ok=False)
logs=[];children=[];commands=[]
def spawn(name,args):
 cmd=['./scripts/run_ros.sh']+args;commands.append(cmd)
 log=(out/(name+'.log')).open('w');logs.append(log)
 p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,start_new_session=True);children.append(p);return p
try:
 echo=spawn('scalar-node',['python3','-m','tdp_webots_bridge.scalar_echo'])
 subscriber=spawn('subscriber',['ros2','topic','echo','/tdp/scalar_out','std_msgs/msg/Float64','--once'])
 pub=spawn('publisher',['ros2','topic','pub','--once','--wait-matching-subscriptions','1','/tdp/scalar_in','std_msgs/msg/Float64','{data: 3.5}'])
 assert pub.wait(timeout=60)==0
 assert subscriber.wait(timeout=60)==0
 info=spawn('topic-info',['ros2','topic','info','/tdp/scalar_out','--verbose'])
 assert info.wait(timeout=30)==0
 for f in logs:f.flush()
 observed=(out/'subscriber.log').read_text();assert 'data: 4.5' in observed,observed
 (out/'receipt.json').write_text(json.dumps({'status':'PASS','input':3.5,'output':4.5,'commands':commands,'terminalEquivalent':True},indent=2))
finally:
 for p in children:
  if p.poll() is None:
   import os
   os.killpg(p.pid,signal.SIGINT)
   try:p.wait(timeout=15)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=15)
 for f in logs:f.close()
