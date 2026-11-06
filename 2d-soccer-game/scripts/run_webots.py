"""Isolated Webots run with an optional actual Simulink controller process."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from private_display import PrivateDisplay,webots_environment
ROOT=Path(__file__).resolve().parents[1]


def run(output,mode):
    out=Path(output).resolve();out.mkdir(parents=True,exist_ok=False)
    c=json.loads((ROOT/'config/webots.json').read_text());processes=[];streams=[]
    def start(name,args,env):
        log=(out/(name+'.log')).open('w');streams.append(log)
        p=subprocess.Popen(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT);processes.append(p);return p
    receipt={'status':'RUNNING','mode':mode};started=time.monotonic()
    display_folder=ROOT/'build'/('w'+str(os.getpid()))
    try:
        with PrivateDisplay(display_folder) as display:
            original_cache=Path(os.environ.get('TDP_WEBOTS_CACHE',str(Path.home()/'.cache/Cyberbotics/Webots')))
            cache=Path(display['XDG_CACHE_HOME'])/'Cyberbotics/Webots'
            if original_cache.is_dir():shutil.copytree(original_cache,cache)
            env=webots_environment(display)
            env.update(TDP_PROJECT_ROOT=str(ROOT),TDP_WEBOTS_OUTPUT=str(out),TDP_WEBOTS_MODE=mode)
            if mode=='closed':
                escaped=str(out).replace("'","''")
                code=("tdpSetup;P=tdp.defaultConfig();P.dt=.04;P.mode=TdpMode.Delayed;"
                      f"P.kickTimeout={c['kickTimeoutSeconds']};P.recoverTime={c['recoverTimeSeconds']};"
                      f"f=zeros({c['controlFrames']},20);[a,q]=runFrameReplay(P,f,true);"
                      f"writeJson('{escaped}/matlab-actions.json',a);writeJson('{escaped}/matlab-quality.json',q);")
                matlab_env=os.environ.copy();matlab_env.update(TDP_CACHE_ID=f'webots{os.getpid()}',TDP_MATLAB_PREFDIR=str(ROOT/'build/matlab-prefs'/f'webots{os.getpid()}'))
                matlab=start('matlab',['./scripts/run_matlab.sh',code],matlab_env)
                proxy=start('proxy',['python3','-m','tdp_webots_bridge.proxy','--count',str(c['controlFrames']),
                                    '--output',str(out/'proxy-records.json')],os.environ.copy())
            observer=start('camera-observer',['python3','-m','tdp_webots_bridge.camera_observer',str(out),'--mode',mode],os.environ.copy())
            webots=start('webots',[env['WEBOTS_HOME']+'/bin/webots-bin','--batch','--mode=fast','--no-rendering',
                                   '--stdout','--stderr',str(ROOT/'webots/worlds/tdp_single.wbt')],env)
            assert webots.wait(timeout=600)==0,'Webots process failed'
            assert observer.wait(timeout=60)==0,'Camera observer failed'
            if mode=='closed':
                assert proxy.wait(timeout=30)==0,'Proxy failed'
                assert matlab.wait(timeout=60)==0,'MATLAB failed'
            assert (out/'webots-receipt.json').is_file(),'No controller receipt'
            r=json.loads((out/'webots-receipt.json').read_text());receipt['controller']=r
            assert r['error'] is None
            receipt['status']=r['status']
    except Exception as exc:
        receipt.update(status='FAIL',error=repr(exc));raise
    finally:
        for p in processes:
            if p.poll() is None:
                p.terminate()
                try:p.wait(timeout=10)
                except subprocess.TimeoutExpired:p.kill();p.wait()
        for log in streams:log.close()
        if (display_folder/'compositor.log').is_file():shutil.copy2(display_folder/'compositor.log',out/'compositor.log')
        receipt['elapsedSeconds']=time.monotonic()-started
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('--mode',choices=['probe','motion','closed'],default='closed');a=p.parse_args();run(a.output,a.mode)
