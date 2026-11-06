"""Real scalar CLI and ROS vs local Simulink replay; never installs software."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]

def run(out):
    out.mkdir(exist_ok=False, parents=True)
    processes, streams = [], []
    def start(name, command, env=None):
        stream = (out / (name + '.log')).open('w');streams.append(stream)
        p = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        processes.append(p);return p
    receipt = {'status': 'RUNNING', 'nativeRosToolbox': 'BLOCKED: not installed',
               'generatedNode': 'BLOCKED: Coders not installed'}
    start_time = time.monotonic()
    try:
        echo = start('scalar-node', ['python3', '-m', 'tdp_webots_bridge.scalar_echo'])
        reader = start('scalar-echo', ['ros2', 'topic', 'echo', '/tdp/scalar_out', 'std_msgs/msg/Float64', '--once'])
        time.sleep(2)
        result = subprocess.run(['ros2', 'topic', 'pub', '--once', '--wait-matching-subscriptions', '1',
                                 '/tdp/scalar_in', 'std_msgs/msg/Float64', '{data: 3.5}'],
                                text=True, capture_output=True, timeout=30)
        (out / 'scalar-pub.log').write_text(result.stdout + result.stderr)
        assert result.returncode == 0
        assert reader.wait(timeout=20) == 0
        assert 'data: 4.5' in (out / 'scalar-echo.log').read_text()
        receipt['scalar'] = {'input': 3.5, 'output': 4.5, 'communication': 'PASS'}
        echo.terminate();echo.wait(timeout=10)
        escaped = str(out).replace("'", "''")
        code = ("tdpSetup;build_ros_adapter;P=tdp.defaultConfig();P.dt=.04;P.mode=TdpMode.Delayed;"
                "f=makeBridgeFrames(P,101);"
                f"writeJson('{escaped}/frames.json',f);"
                "[a,q]=runFrameReplay(P,f);"
                f"writeJson('{escaped}/offline-actions.json',a);writeJson('{escaped}/offline-quality.json',q);"
                "[b,r]=runFrameReplay(P,f,true);"
                f"writeJson('{escaped}/online-actions.json',b);writeJson('{escaped}/online-quality.json',r);"
                "assert(isequal(a,b));assert(isequal(q,r));")
        matlab_env=os.environ.copy();matlab_env.update(TDP_CACHE_ID=f'ros{os.getpid()}',TDP_MATLAB_PREFDIR=str(ROOT/'build/matlab-prefs'/f'ros{os.getpid()}'))
        matlab = start('matlab', ['./scripts/run_matlab.sh', code],matlab_env)
        proxy = start('proxy', ['python3', '-m', 'tdp_webots_bridge.proxy', '--count', '101',
                                '--output', str(out / 'proxy-records.json')])
        deadline = time.monotonic() + 180
        while not (out / 'frames.json').is_file():
            if matlab.poll() is not None:raise RuntimeError('MATLAB failed before exporting frames')
            if time.monotonic() > deadline:raise TimeoutError('Frame export')
            time.sleep(0.2)
        driver = start('driver', ['python3', '-m', 'tdp_webots_bridge.replay_driver',
                                  '--frames', str(out / 'frames.json'), '--output', str(out)])
        for name, proc in [('driver', driver), ('proxy', proxy), ('matlab', matlab)]:
            assert proc.wait(timeout=300) == 0, name + ' failed'
        local = json.loads((out / 'offline-actions.json').read_text())
        online = json.loads((out / 'online-actions.json').read_text())
        ros = json.loads((out / 'ros-actions.json').read_text())
        assert local == online == ros
        receipt.update(status='PASS_PROXY_ONLINE_AND_COMMUNICATION', frames=len(local),
                       actionsExactlyEqual=True, extraTopic='PASS: /tdp/diagnostics/action_age',
                       clockPublishers=1, modelValidation='NOT_ESTABLISHED: transport and controller replay only')
    except Exception as exc:
        receipt.update(status='FAIL', error=repr(exc))
        raise
    finally:
        for proc in processes:
            if proc.poll() is None:
                proc.terminate()
                try:proc.wait(timeout=10)
                except subprocess.TimeoutExpired:proc.kill();proc.wait()
        for stream in streams:stream.close()
        receipt['elapsedSeconds'] = time.monotonic() - start_time
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')

if __name__ == '__main__':
    p = argparse.ArgumentParser();p.add_argument('output');args = p.parse_args()
    run(Path(args.output).resolve())
