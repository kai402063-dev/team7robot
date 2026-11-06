"""Run probe.m on a private authenticated X server from the installed worktree."""
import json
import os
from pathlib import Path
import secrets
import select
import subprocess
import sys
import tempfile
import time

directory=Path(__file__).resolve().parent
root=directory.parents[2]
sys.path.insert(0,str(root/'scripts'))
from validate_live_launcher import XVFB, set_cookie, stop_child

receipt={'invocation':"eval(fileread('evidence/recovery-v1/editor-window-01/probe.m'))",
         'scope':'New MATLAB process and private authenticated Xvfb; bare call as from editor.'}
started=time.monotonic()
server=None
try:
    with tempfile.TemporaryDirectory(dir=root/'build',prefix='recovery-editor-x11-') as temporary:
        private=Path(temporary)
        auth=private/'Xauthority'
        auth.touch(mode=0o600)
        cookie=secrets.token_hex(16)
        set_cookie(auth,':9999',cookie)
        env=os.environ.copy()
        for key in ('DISPLAY','WAYLAND_DISPLAY','XAUTHORITY','LD_LIBRARY_PATH','LD_PRELOAD',
                    'MATLAB_JAVA','MATLABPATH','DBUS_SESSION_BUS_ADDRESS','SESSION_MANAGER'):
            env.pop(key,None)
        prefs=private/'preferences'
        prefs.mkdir()
        env.update(XAUTHORITY=str(auth),XDG_SESSION_TYPE='x11',XDG_RUNTIME_DIR=str(private),
                   TDP_CACHE_ID='editor_recovery_01',MATLAB_PREFDIR=str(prefs),TDP_MATLAB_PREFDIR=str(prefs),
                   TDP_2D_DURATION='5',TDP_2D_SPEED='Inf',TDP_2D_STRATEGY='v1')
        rd,wr=os.pipe()
        try:
            with (directory/'xvfb.log').open('x') as xlog:
                server=subprocess.Popen([XVFB,'-displayfd',str(wr),'-screen','0','1400x1000x24',
                                         '-nolisten','tcp','-auth',str(auth)],env=env,pass_fds=(wr,),
                                        start_new_session=True,stdout=xlog,stderr=subprocess.STDOUT)
        finally:
            os.close(wr)
        try:
            assert select.select([rd],[],[],15)[0]
            display_number=os.read(rd,32).decode().strip()
            assert display_number.isdecimal()
        finally:
            os.close(rd)
        env['DISPLAY']=':'+display_number
        set_cookie(auth,env['DISPLAY'],cookie)
        with (directory/'matlab.log').open('x') as log:
            result=subprocess.run(['/home/fayne/Applications/MATLAB/R2026b/bin/matlab','-batch',
                                   receipt['invocation']],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,
                                  timeout=600)
        receipt.update(matlabExitCode=result.returncode,display=env['DISPLAY'])
        result.check_returncode()
        receipt.update(json.loads((directory/'matlab-checks.json').read_text()))
except Exception as error:
    receipt.update(status='FAIL',error=repr(error))
finally:
    stop_child(server)
    receipt.update(elapsedSeconds=time.monotonic()-started,
                   privateServerExited=server is None or server.poll() is not None)
    with (directory/'receipt.json').open('x') as file:
        json.dump(receipt,file,indent=2)
        file.write('\n')
print(json.dumps(receipt))
raise SystemExit(receipt['status']!='PASS')
