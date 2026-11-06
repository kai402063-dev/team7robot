"""Exercise the unmodified launcher on a private X11 server and close its window."""
import argparse
import configparser
import ctypes
import ctypes.util
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import select
import signal
import shlex
import subprocess
import tempfile
import time

import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]
XVFB = Path('/home/fayne/Applications/MATLAB/R2026b/sys/Xvfb/bin/glnxa64/Xvfb')
WINDOW_TITLE = 'TDP Football - Live 2D'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def x11_output(command, env):
    return subprocess.check_output(command, env=env, stderr=subprocess.STDOUT,
                                   text=True, timeout=8)


def stop_child(child):
    if child is None or child.poll() is not None:
        return
    os.killpg(child.pid, signal.SIGTERM)
    try:
        child.wait(timeout=8)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=8)


def set_cookie(authority, display, cookie):
    # Keep the generated cookie out of process arguments and retained logs.
    subprocess.run(['xauth', '-q', '-f', str(authority)], check=True,
                   input=f'add {display} . {cookie}\n', text=True,
                   capture_output=True, timeout=8)


def send_close(display, window):
    # ICCCM WM_PROTOCOLS ClientMessage containing WM_DELETE_WINDOW.
    class ClientMessage(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong),
                    ('send_event', ctypes.c_int), ('display', ctypes.c_void_p),
                    ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                    ('format', ctypes.c_int), ('data', ctypes.c_long * 5)]

    class Event(ctypes.Union):
        _fields_ = [('client', ClientMessage), ('pad', ctypes.c_long * 24)]

    x11 = ctypes.CDLL(ctypes.util.find_library('X11'))
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                              ctypes.c_long, ctypes.POINTER(Event)]
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    connection = x11.XOpenDisplay(display.encode('ascii'))
    if not connection:
        raise RuntimeError('Cannot open the private X11 display for close request')
    try:
        event = Event()
        event.client.type = 33  # ClientMessage
        event.client.display = connection
        event.client.window = window
        event.client.message_type = x11.XInternAtom(connection, b'WM_PROTOCOLS', 1)
        event.client.format = 32
        event.client.data[0] = x11.XInternAtom(connection, b'WM_DELETE_WINDOW', 1)
        if not event.client.message_type or not event.client.data[0]:
            raise RuntimeError('Window manager protocol atoms are missing')
        if not x11.XSendEvent(connection, window, 0, 0, ctypes.byref(event)):
            raise RuntimeError('XSendEvent did not send the close request')
        x11.XSync(connection, 0)
    finally:
        x11.XCloseDisplay(connection)


def wait_for_receipt(process, log, preexisting, startup_timeout):
    deadline = time.monotonic() + startup_timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'Launcher exited before waitfor: {process.returncode}')
        match = re.search(r'^TDP animation: (.+/receipt\.json)$',
                          log.read_text(errors='replace'), re.MULTILINE)
        if match:
            path = Path(match.group(1)).resolve()
            if (path.parent.parent != ROOT / 'build' or
                    not path.parent.name.startswith('animation-') or path in preexisting):
                raise RuntimeError('Launch log did not point to a new match receipt')
            return path
        time.sleep(0.25)
    raise TimeoutError('Timed out waiting for the launcher to complete a match')


def find_window(env, output):
    tree = x11_output(['xwininfo', '-root', '-tree'], env)
    (output / 'window-tree.log').write_text(tree)
    ids = re.findall(r'^\s*(0x[0-9a-fA-F]+) "[^"]*' + re.escape(WINDOW_TITLE)
                     + r'[^"]*"', tree, re.MULTILINE)
    visible = []
    for window in ids:
        details = x11_output(['xwininfo', '-id', window], env)
        properties = x11_output(['xprop', '-id', window, 'WM_PROTOCOLS'], env)
        if 'Map State: IsViewable' in details and 'WM_DELETE_WINDOW' in properties:
            visible.append((window, details, properties))
    if len(visible) != 1:
        raise RuntimeError(f'Expected one mapped and closable pitch window; found {len(visible)}')
    window, details, properties = visible[0]
    (output / 'pitch-window.log').write_text(details + properties)
    return window


def verify_match(path, expect_recovery):
    result = json.loads(path.read_text())
    data = loadmat(path.parent / 'trace.mat', variable_names=['trace', 'tactics','recovery'])
    trace = data['trace']
    if (result['status'] != 'COMPLETED' or result['frames'] != 100 or
            result['parameters']['Tmatch'] != 5 or result['parameters']['dt'] != .05 or
            trace.shape != (100, 98) or not np.isfinite(trace).all()):
        raise ValueError('Match receipt or saved trace did not meet the 5 s / 100-frame check')
    tactics = data['tactics']
    if (result['parameters'].get('v1Enabled') is not True or
            tactics.shape != (100, 171) or not np.isfinite(tactics).all() or
            not np.all(trace[:, 48:56] == np.array([1, 3, 5, 2, 1, 3, 5, 2]))):
        raise ValueError('The default launcher must run the fixed-role V1 model')
    auto = result['parameters'].get('v1AutoRecovery', False)
    if auto is not expect_recovery or ('recovery' in data) != expect_recovery:
        raise ValueError('Unexpected recovery strategy or diagnostic trace in selected launcher')
    if auto:
        extra = data['recovery']
        if (extra.shape != (100, 53) or not np.isfinite(extra).all() or
                not np.array_equal(extra[:, 0], trace[:, 60]) or
                result['parameters']['v1RecoveryHealthySeconds'] != .50):
            raise ValueError('Experimental recovery diagnostic does not match the physical records')
    robot_travel = np.hypot(np.diff(trace[:, :8], axis=0), np.diff(trace[:, 8:16], axis=0)).sum(axis=0)
    ball_travel = float(np.linalg.norm(np.diff(trace[:, 56:58], axis=0), axis=1).sum())
    if not (np.all(robot_travel > 1e-6) and ball_travel > .01 and np.any(tactics[:, 14] > 0)):
        raise ValueError('Expected visible robot motion, ball motion and an actual kick')
    if not any(event['event'] == 'started' and event['speed'] == 'Max'
               for event in ([result['events']] if isinstance(result['events'], dict)
                             else result['events'])):
        raise ValueError('The receipt did not record a start at Max speed')
    return dict(status=result['status'], frames=result['frames'], traceShape=list(trace.shape),
                tacticsShape=list(tactics.shape), fixedRoles=True, autoRecovery=auto,
                recoveryShape=list(data['recovery'].shape) if auto else None,
                numericalSha256={key: hashlib.sha256(np.ascontiguousarray(data[key], dtype='<f8').tobytes()).hexdigest()
                                 for key in (('trace','tactics','recovery') if auto else ('trace','tactics'))},
                ballTravelMetres=ball_travel, robotsMoving=int(np.count_nonzero(robot_travel>1e-6)),
                actualKickSteps=int(np.count_nonzero(tactics[:, 14])),
                matchReceipt=str(path.relative_to(ROOT)), traceSha256=digest(path.parent/'trace.mat'),
                matchReceiptSha256=digest(path), lastSimulationTime=float(trace[-1, 60]))


def main(destination, recovery=False, desktop=False, startup_timeout=300):
    output = Path(destination).resolve()
    output.mkdir(parents=True, exist_ok=False)
    (ROOT / 'build').mkdir(exist_ok=True)
    start = time.monotonic()
    script = ROOT / 'start_2d.sh'
    command = ['./start_2d.sh'] + (['--recovery'] if recovery else [])
    menu_file = ROOT / ('START_2D_RECOVERY.desktop' if recovery else 'START_2D.desktop')
    if desktop:
        definition = configparser.ConfigParser(interpolation=None)
        definition.read(menu_file)
        item = definition['Desktop Entry']
        command = shlex.split(item['Exec'])
        if (Path(command[0]) != script or command[1:] != (['--recovery'] if recovery else []) or
                Path(item['Path']) != ROOT):
            raise ValueError('Desktop launcher does not target the selected local worktree and strategy')
    result = dict(status='RUNNING', command=shlex.join(command), duration=5, speed='Inf',
                  startupTimeoutSeconds=startup_timeout,
                  desktopExecSource=menu_file.name if desktop else None,
                  desktopSha256=digest(menu_file) if desktop else None,
                  desktopScope='Exec and Path verified; shell directly executes entry argv, no file-manager click',
                  scope='Private authenticated Xvfb; one target window; real default MATLAB',
                  launcherSha256=digest(script))
    (output / 'command.json').write_text(json.dumps(result, indent=2) + '\n')
    server = launcher = None
    try:
        with tempfile.TemporaryDirectory(dir=ROOT/'build', prefix='launcher-e2e-x11-') as private:
            private = Path(private)
            env = os.environ.copy()
            for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'XAUTHORITY', 'DBUS_SESSION_BUS_ADDRESS',
                         'SESSION_MANAGER', 'MATLAB_BIN', 'LD_LIBRARY_PATH', 'LD_PRELOAD'):
                env.pop(name, None)
            authority = private / 'Xauthority'
            authority.touch(mode=0o600)
            cookie = secrets.token_hex(16)
            set_cookie(authority, ':9999', cookie)
            env.update(XAUTHORITY=str(authority), XDG_SESSION_TYPE='x11', XDG_RUNTIME_DIR=str(private),
                       TDP_2D_DURATION='5', TDP_2D_SPEED='Inf')
            read_fd, write_fd = os.pipe()
            with (output / 'xvfb.log').open('w') as log:
                try:
                    server = subprocess.Popen([XVFB, '-displayfd', str(write_fd),
                                               '-screen', '0', '1400x1000x24', '-nolisten', 'tcp',
                                               '-auth', str(authority)], env=env, pass_fds=(write_fd,),
                                              start_new_session=True, stdout=log, stderr=subprocess.STDOUT)
                finally:
                    os.close(write_fd)
                try:
                    if not select.select([read_fd], [], [], 15)[0]:
                        raise TimeoutError('Private X server did not announce a display')
                    number = os.read(read_fd, 32).decode().strip()
                finally:
                    os.close(read_fd)
                if not number.isdecimal():
                    raise RuntimeError('Private X server returned no display number')
                env['DISPLAY'] = ':' + number
                set_cookie(authority, env['DISPLAY'], cookie)
                result.update(display=env['DISPLAY'], privateServerPid=server.pid)
                preexisting = set((ROOT/'build').glob('animation-*/receipt.json'))
                console = output / 'launcher.log'
                with console.open('w') as launch_log:
                    launcher = subprocess.Popen(command, cwd=ROOT, env=env, stdout=launch_log,
                                                start_new_session=True, stderr=subprocess.STDOUT)
                    result['launcherPid'] = launcher.pid
                    match = wait_for_receipt(launcher, console, preexisting, startup_timeout)
                    result.update(verify_match(match, recovery))
                    (output / 'match-receipt.json').write_bytes(match.read_bytes())
                    window = find_window(env, output)
                    result.update(window=window, windowTitle=WINDOW_TITLE, windowViewable=True)
                    # Only this harness process needs to find the cookie for XOpenDisplay.
                    previous_authority = os.environ.get('XAUTHORITY')
                    os.environ['XAUTHORITY'] = str(authority)
                    try:
                        send_close(env['DISPLAY'], int(window, 16))
                    finally:
                        if previous_authority is None:
                            del os.environ['XAUTHORITY']
                        else:
                            os.environ['XAUTHORITY'] = previous_authority
                    result.update(closeEvent='WM_DELETE_WINDOW', exitCode=launcher.wait(timeout=45))
                    if result['exitCode'] != 0:
                        raise RuntimeError('MATLAB launcher returned a nonzero exit status')
                    result['naturalExitAfterClose'] = True
            if result['launcherSha256'] != digest(script):
                raise RuntimeError('Launcher contents changed during execution')
            result['status'] = 'PASS'
    except Exception as error:
        result.update(status='FAIL', error=repr(error))
    finally:
        stop_child(launcher)
        stop_child(server)
        result.update(ownedLauncherExited=launcher is None or launcher.poll() is not None,
                      ownedServerExited=server is None or server.poll() is not None,
                      elapsedSeconds=time.monotonic() - start)
        (output / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
    return result['status'] == 'PASS'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--recovery', action='store_true')
    parser.add_argument('--desktop', action='store_true')
    parser.add_argument('--startup-timeout', type=int, default=300,
                        help='Maximum wall-clock seconds for MATLAB cold startup, compile and 5 s play')
    args = parser.parse_args()
    if args.startup_timeout < 1:
        parser.error('--startup-timeout must be positive')
    raise SystemExit(0 if main(args.output,args.recovery,args.desktop,args.startup_timeout) else 1)
