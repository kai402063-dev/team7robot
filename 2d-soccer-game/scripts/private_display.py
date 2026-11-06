"""Task-owned headless Wayland display; never replaces the user's compositor."""
import os
from pathlib import Path
import signal
import subprocess
import time
from urllib.parse import quote

class PrivateDisplay:
    def __init__(self, folder):
        self.folder = Path(folder).resolve()
        self.folder.mkdir(parents=True, exist_ok=False)
        self.env = os.environ.copy()
        for key in ['DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'LD_LIBRARY_PATH', 'LD_PRELOAD']:
            self.env.pop(key, None)
        for key, sub in [('XDG_RUNTIME_DIR','r'),('XDG_CACHE_HOME','c'),('XDG_CONFIG_HOME','g'),('XDG_DATA_HOME','d')]:
            path=self.folder/sub;path.mkdir(mode=0o700);self.env[key]=str(path)
        # A directory FD keeps Unix socket names short even in deep clean clones.
        self.runtime_fd=os.open(self.folder/'r',os.O_RDONLY|os.O_DIRECTORY)
        self.runtime_alias=f'/proc/{os.getpid()}/fd/{self.runtime_fd}'
        (self.folder/'r'/'t').mkdir()
        self.env['TMPDIR']=self.runtime_alias+'/t'
        self.env['WEBOTS_TMPDIR']=self.env['TMPDIR']
        self.env.update(GSETTINGS_BACKEND='memory', LIBGL_ALWAYS_SOFTWARE='1',
                        WAYLAND_DISPLAY=self.runtime_alias+'/w', QT_QPA_PLATFORM='wayland',
                        XDG_SESSION_TYPE='wayland', NO_AT_BRIDGE='1', GIO_USE_VFS='local', GTK_USE_PORTAL='0')
        self.bus_config=self.folder/'bus.conf'
        self.bus_config.write_text('<busconfig><type>session</type><listen>unix:path='+quote(self.runtime_alias+'/b',safe='/')+'</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>')
        self.env['DBUS_SESSION_BUS_ADDRESS']='unix:path='+quote(self.runtime_alias+'/b',safe='/')
        self.log = (self.folder/'compositor.log').open('w')
        self.process = None

    def __enter__(self):
        self.process = subprocess.Popen(['dbus-run-session','--config-file='+str(self.bus_config),'--','gnome-shell','--headless','--wayland',
            '--no-x11','--virtual-monitor=1280x720','--wayland-display='+self.env['WAYLAND_DISPLAY'],'--sm-disable'],
            env=self.env, stdout=self.log, stderr=subprocess.STDOUT, start_new_session=True)
        deadline=time.monotonic()+20
        while not Path(self.env['WAYLAND_DISPLAY']).exists():
            if self.process.poll() is not None or time.monotonic()>deadline:
                self.__exit__(None,None,None)
                raise RuntimeError('Private Wayland startup failed; see compositor.log')
            time.sleep(.1)
        return self.env

    def __exit__(self,*args):
        if self.process and self.process.poll() is None:
            os.killpg(self.process.pid,signal.SIGTERM)
            try:self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid,signal.SIGKILL);self.process.wait()
        self.log.close()
        os.close(self.runtime_fd)


def webots_environment(display_env):
    env=display_env.copy()
    home=os.environ.get("TDP_WEBOTS_HOME","/home/fayne/.ros/webotsR2025a/webots")
    original=os.environ.get("LD_LIBRARY_PATH", "")
    env.update(WEBOTS_HOME=home,WEBOTS_ORIGINAL_LD_LIBRARY_PATH=original,
               LD_LIBRARY_PATH=home+"/lib/webots:"+original,QT_QPA_PLATFORM="wayland")
    return env
