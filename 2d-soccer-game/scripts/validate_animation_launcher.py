"""Exercise the GUI launcher using local executables, never a real desktop."""
import argparse
import configparser
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def validate(source, output):
    source = Path(source).resolve()
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    (ROOT/'build').mkdir(exist_ok=True)
    fixture = Path(tempfile.mkdtemp(prefix='launcher-check-', dir=ROOT/'build'))
    project = fixture/'project with spaces & symbols'
    project.mkdir()
    launcher = project/'start_2d.sh'
    shutil.copy2(source, launcher)
    launcher.chmod(0o755)
    binary = fixture/'bin'
    binary.mkdir()
    probe = binary/'xdpyinfo'
    probe.write_text('#!/usr/bin/env python3\nimport os,sys\nsys.exit(int(os.environ.get("STUB_DISPLAY_FAIL","0")))\n')
    probe.chmod(0o755)
    matlab = binary/'matlab with spaces & symbols'
    matlab.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
keys=['DISPLAY','WAYLAND_DISPLAY','XAUTHORITY','LD_LIBRARY_PATH','LD_PRELOAD',
      'MATLAB_JAVA','MATLAB_PREFDIR','TDP_MATLAB_PREFDIR','TDP_CACHE_ID',
      'TDP_2D_DURATION','TDP_2D_SPEED','TDP_2D_STRATEGY']
Path(os.environ['STUB_CAPTURE']).write_text(json.dumps({'cwd':os.getcwd(),
    'argv':sys.argv[1:],'environment':{k:os.environ[k] for k in keys if k in os.environ}},indent=2)+'\\n')
sys.exit(int(os.environ.get('STUB_EXIT','0')))
''')
    matlab.chmod(0o755)
    shutil.copy2(matlab, binary/'matlab-stub')
    results = []
    invocation = 0

    def run(arguments=(), overrides=None, remove=()):
        nonlocal invocation
        invocation += 1
        capture = output/f'capture-{invocation:02d}.json'
        env = os.environ.copy()
        env.update(PATH=str(binary)+os.pathsep+env.get('PATH',''), DISPLAY=':tdp-stub',
                   WAYLAND_DISPLAY='wayland-stub', XAUTHORITY=str(fixture/'authority'),
                   MATLAB_BIN=str(matlab), STUB_CAPTURE=str(capture),
                   LD_LIBRARY_PATH='/tdp-test/ros-library', LD_PRELOAD='',
                   MATLAB_JAVA='/tdp-test/unwanted-java', TDP_CACHE_ID='unwanted_cache',
                   MATLAB_PREFDIR='/tdp-test/unwanted-prefs',
                   TDP_MATLAB_PREFDIR='/tdp-test/unwanted-prefs')
        for key in ['STUB_EXIT','STUB_DISPLAY_FAIL','TDP_2D_DURATION','TDP_2D_SPEED']:
            env.pop(key,None)
        if overrides:
            env.update(overrides)
        for key in remove:
            env.pop(key,None)
        command=['/bin/bash',str(launcher),*arguments]
        result = subprocess.run(command,cwd=fixture,env=env,capture_output=True,text=True,timeout=15)
        (output/f'run-{invocation:02d}.log').write_text(result.stdout+result.stderr)
        (output/f'run-{invocation:02d}.json').write_text(json.dumps({
            'command':command,'exitCode':result.returncode,
            'capture':str(capture) if capture.exists() else None},indent=2)+'\n')
        observed=json.loads(capture.read_text()) if capture.exists() else None
        return result,observed

    def case(name, function):
        try:
            function()
            results.append({'name':name,'passed':True,'assertionFailure':False})
        except AssertionError as error:
            results.append({'name':name,'passed':False,'assertionFailure':True,'message':str(error)})
        except Exception as error:
            results.append({'name':name,'passed':False,'assertionFailure':False,'error':repr(error)})

    def help_without_display():
        result,observed=run(['--help'],remove=['DISPLAY'])
        assert result.returncode==0 and 'TDP_2D_DURATION' in result.stdout
        assert observed is None

    def unknown_arguments():
        result,observed=run(['--duration','10'])
        assert result.returncode==2 and 'Unknown arguments' in result.stderr
        assert observed is None

    def missing_display():
        result,observed=run(remove=['DISPLAY'])
        assert result.returncode==2 and 'No DISPLAY' in result.stderr
        assert observed is None

    def unreachable_display():
        result,observed=run(overrides={'STUB_DISPLAY_FAIL':'1'})
        assert result.returncode==2 and 'Cannot connect' in result.stderr
        assert observed is None

    def missing_matlab():
        result,observed=run(overrides={'MATLAB_BIN':str(fixture/'missing matlab')})
        assert result.returncode==2 and 'MATLAB executable is unavailable' in result.stderr
        assert observed is None

    def valid_environment():
        result,observed=run(overrides={'TDP_2D_DURATION':'30','TDP_2D_SPEED':'2'})
        assert result.returncode==0
        assert observed['cwd']==str(project)
        e=observed['environment']
        for key in ['LD_LIBRARY_PATH','LD_PRELOAD','MATLAB_JAVA']:
            assert key not in e, f'{key} must not enter the new MATLAB process'
        assert e['DISPLAY']==':tdp-stub' and e['WAYLAND_DISPLAY']=='wayland-stub'
        assert e['XAUTHORITY']==str(fixture/'authority')
        assert e['TDP_2D_DURATION']=='30' and e['TDP_2D_SPEED']=='2'
        assert re.fullmatch(r'animation_[A-Za-z0-9_]+',e['TDP_CACHE_ID'])
        prefs=Path(e['MATLAB_PREFDIR'])
        assert project/'build' in prefs.parents and prefs.is_dir()
        assert e['TDP_MATLAB_PREFDIR']==str(prefs)
        args=observed['argv']
        assert args[0]=='-logfile' and args[2]=='-batch' and len(args)==4
        assert Path(args[1]).parent==prefs.parent
        assert 'app=start_2d' in args[3] and 'waitfor(app.Figure)' in args[3]
        assert 'rethrow(app.LastError)' in args[3]

    def strategy_selection():
        for arguments, inherited, expected in [([], 'recovery', 'v1'), (['--recovery'], 'v1', 'recovery')]:
            result, observed = run(arguments, overrides={'TDP_2D_STRATEGY': inherited})
            assert result.returncode == 0 and observed['environment']['TDP_2D_STRATEGY'] == expected
        result, observed = run(['--recovery','--recovery'])
        assert result.returncode == 2 and observed is None

    def matlab_failure_exit():
        result,observed=run(overrides={'STUB_EXIT':'7'})
        assert observed is not None and result.returncode==7

    def replay_selection():
        result, observed = run(['--replay'])
        assert result.returncode == 0
        code = observed['argv'][-1]
        assert 'app=replay_2d;' in code
        assert '~isempty(app) && isgraphics(app.Figure),waitfor(app.Figure)' in code
        assert 'start_2d' not in code
        result, observed = run(['--recovery', '--replay'])
        assert result.returncode == 2 and observed is None

    def options_remain_data():
        value='2; $(touch INJECTION_MARKER) `touch INJECTION_MARKER`'
        result,observed=run(overrides={'TDP_2D_DURATION':value,'TDP_2D_SPEED':value})
        assert result.returncode==0
        assert observed['environment']['TDP_2D_DURATION']==value
        assert observed['environment']['TDP_2D_SPEED']==value
        assert value not in observed['argv'][-1]
        assert not (project/'INJECTION_MARKER').exists()

    def sessions_are_isolated():
        first,a=run();second,b=run()
        assert first.returncode==0 and second.returncode==0
        assert a['environment']['TDP_CACHE_ID']!=b['environment']['TDP_CACHE_ID']
        assert a['environment']['MATLAB_PREFDIR']!=b['environment']['MATLAB_PREFDIR']

    def executable_from_path():
        result,observed=run(overrides={'MATLAB_BIN':'matlab-stub'})
        assert result.returncode==0 and observed is not None

    def shell_syntax():
        result=subprocess.run(['/bin/bash','-n',str(source)],capture_output=True,text=True)
        assert result.returncode==0,result.stderr

    def desktop_entry():
        names=set()
        for file, arguments in [('START_2D.desktop', []), ('START_2D_RECOVERY.desktop', ['--recovery']),
                                ('REPLAY_2D.desktop', ['--replay'])]:
            assert os.access(ROOT/file, os.X_OK), f'{file} must be executable'
            p=configparser.ConfigParser(interpolation=None)
            p.read(ROOT/file)
            entry=p['Desktop Entry']
            assert entry['Type']=='Application' and entry['Terminal']=='true'
            command=shlex.split(entry['Exec'])
            target=Path(command[0])
            assert target.is_absolute() and target.name=='start_2d.sh' and target.is_file()
            assert command[1:]==arguments and entry['Path']==str(target.parent)
            assert entry['Name'] not in names
            names.add(entry['Name'])
            validator=shutil.which('desktop-file-validate')
            if validator:
                result=subprocess.run([validator,str(ROOT/file)],capture_output=True,text=True)
                (output/(file+'.validate.log')).write_text(result.stdout+result.stderr)
                assert result.returncode==0,result.stderr

    started=time.monotonic()
    for function in [help_without_display,unknown_arguments,missing_display,
                     unreachable_display,missing_matlab,valid_environment,
                     matlab_failure_exit,options_remain_data,sessions_are_isolated,
                     executable_from_path,shell_syntax,desktop_entry,strategy_selection,replay_selection]:
        case(function.__name__,function)
    passed=all(row['passed'] for row in results)
    receipt={'status':'PASS' if passed else 'FAIL','source':str(source),'fixture':str(fixture),
             'scope':'Stub execution only: no user desktop or real MATLAB process opened',
             'elapsedSeconds':time.monotonic()-started,'results':results,
             'passed':sum(row['passed'] for row in results),'total':len(results)}
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))
    return passed


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',default=str(ROOT/'start_2d.sh'))
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    sys.exit(0 if validate(args.source,args.output) else 1)
