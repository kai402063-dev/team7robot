"""Run the actual MATLAB viewer on a private X server; retain pixels and logs."""
import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
MATLAB = Path('/home/fayne/Applications/MATLAB/R2026b')


def main(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    prefs = ROOT / 'build' / ('animation-display-prefs-' + str(os.getpid()))
    prefs.mkdir()
    env = os.environ.copy()
    for key in ('LD_LIBRARY_PATH', 'LD_PRELOAD', 'MATLAB_JAVA', 'XAUTHORITY'):
        env.pop(key, None)
    env['MATLAB_PREFDIR'] = str(prefs)
    env['TDP_CACHE_ID'] = os.environ.get('TDP_CACHE_ID', 'animation_display_' + str(os.getpid()))
    read_fd, write_fd = os.pipe()
    started = time.monotonic()
    receipt = {'status': 'RUNNING', 'scope': 'Private X11 display; user desktop untouched'}
    (output / 'command.json').write_text(json.dumps(receipt, indent=2))
    try:
        with (output / 'xvfb.log').open('w') as xlog:
            server = subprocess.Popen([str(MATLAB / 'sys/Xvfb/bin/glnxa64/Xvfb'),
                '-displayfd', str(write_fd), '-screen', '0', '1400x1000x24', '-nolisten', 'tcp'],
                pass_fds=(write_fd,), stdout=xlog, stderr=subprocess.STDOUT, env=env)
            os.close(write_fd)
            try:
                if not select.select([read_fd], [], [], 15)[0]:
                    raise RuntimeError('Private X server did not announce its display')
                number = os.read(read_fd, 32).decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Invalid X server display number')
                env['DISPLAY'] = ':' + number
                artifact_dir = str(output / 'artifacts').replace("'", "''")
                code = f"tdpSetup; validate_animation('{artifact_dir}','on');"
                with (output / 'matlab.log').open('w') as log:
                    result = subprocess.run([str(MATLAB / 'bin/matlab'), '-batch', code],
                        cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900)
                receipt.update(status='PASS' if result.returncode == 0 else 'FAIL',
                               exitCode=result.returncode, display=env['DISPLAY'], cacheId=env['TDP_CACHE_ID'])
            finally:
                server.terminate()
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
    except Exception as error:
        receipt.update(status='FAIL', error=repr(error))
        raise
    finally:
        os.close(read_fd)
        receipt['elapsedSeconds'] = time.monotonic() - started
        (output / 'command.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt['status'] == 'PASS'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    raise SystemExit(0 if main(args.output) else 1)
