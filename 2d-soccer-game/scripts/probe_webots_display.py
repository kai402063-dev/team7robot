"""Record an isolated compositor and Webots OpenGL capability probe."""
import json
import sys
import subprocess
from pathlib import Path
from private_display import PrivateDisplay, webots_environment
root=Path(__file__).resolve().parents[1]
attempt=sys.argv[1] if len(sys.argv)>1 else '02'
out=root/f'evidence/5/display-{attempt}';out.mkdir(exist_ok=False)
receipt={'status':'RUNNING'}
try:
 with PrivateDisplay(root/f'build/d{attempt}') as env:
  p=subprocess.run(['/home/fayne/.ros/webotsR2025a/webots/bin/webots-bin','--sysinfo','--batch'],env=webots_environment(env),
                   stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
  (out/'webots.log').write_text(p.stdout);receipt['exitCode']=p.returncode
  assert p.returncode==0
  receipt['status']='PASS_PRIVATE_WAYLAND_OPENGL'
except Exception as exc:
 receipt.update(status='FAIL',error=repr(exc));raise
finally:
 source=root/f'build/d{attempt}/compositor.log'
 if source.exists():(out/'compositor.log').write_bytes(source.read_bytes())
 (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
