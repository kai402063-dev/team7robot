"""Generate M2 figures and parameter provenance from source and real recordings."""
import json
import os
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[1]
cache=ROOT/'build/matplotlib'
cache.mkdir(parents=True,exist_ok=True)
os.environ['MPLCONFIGDIR']=str(cache)
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
out=ROOT/'docs/generated'
c=json.loads((ROOT/'config/webots.json').read_text());n=json.loads((out/'m2_numbers.json').read_text())
rows=json.loads((ROOT/'evidence/5/closed-02/webots-records.json').read_text())
t=np.array([r['time'] for r in rows]);robot=np.array([r['robot'] for r in rows]);ball=np.array([r['ball'] for r in rows]);speed=np.array([np.hypot(*r['ballVelocity'][:2]) for r in rows])
fig,axes=plt.subplots(2,1,figsize=(9,6),layout='constrained')
axes[0].plot(robot[:,0],robot[:,1],label='NAO V5 body');axes[0].plot(ball[:,0],ball[:,1],label='Physical ball')
axes[0].scatter([robot[0,0],ball[0,0]],[robot[0,1],ball[0,1]],s=35)
axes[0].set(xlabel='Field x (m)',ylabel='Field y (m)',title='Read-only Supervisor measurements');axes[0].legend();axes[0].grid(alpha=.3)
axes[1].plot(t,speed,label='Ball speed sampled at 40 ms');axes[1].axvspan(n['motionStartSeconds'],n['motionEndSeconds'],alpha=.2,color='orange',label='Shoot motion')
axes[1].set(xlabel='Webots time (s)',ylabel='Ball speed (m/s)',title='Motion completion and physical ball movement are separate measurements');axes[1].legend();axes[1].grid(alpha=.3)
fig.savefig(out/'webots_measured.png',dpi=160);plt.close(fig)
shutil.copy2(ROOT/'evidence/5/replay-01/camera.png',out/'webots_camera.png')
units={'basicTimeStepMs':'ms','controlPeriodSeconds':'s','cameraWidth':'pixel','cameraHeight':'pixel','ballRadiusMetres':'m','ballMassKg':'kg',
 'ballDisplacementThresholdMetres':'m','robotInitialPosition':'m, ENU','ballInitialPosition':'m, ENU','kickTimeoutSeconds':'s','recoverTimeSeconds':'s','settleSeconds':'s','controlFrames':'sample',
 'footFriction':'1','footBounce':'1','footBounceVelocityMetresPerSecond':'m/s','uprightMinimumZMetres':'m','uprightMinimumUpZ':'1','walkSelectionReference':'m/s,m/s,rad/s',
 'ballStationarySpeedTolerance':'m/s','ballMotionSpeedThreshold':'m/s','minimumApproachProgressMetres':'m',
 'graphBootstrapTimeoutSeconds':'wall s','graphBootstrapRepublishSeconds':'wall s'}
lines=['# Webots 参数及来源（脚本生成）','','| 参数 | 值 | 单位 | 来源类别 / 状态 |','|---|---|---|---|']
for key,value in c.items():
    category='教学设定 / 已配置，未标定'
    if key.startswith('graphBootstrap'):category='工程通信设定 / 墙钟握手，不推进仿真'
    elif key=='ballRadiusMetres':category='课程尺寸来源 / 已核对'
    elif key.startswith('foot'):category='Webots参考 / 非NAO6实测'
    elif key.startswith('camera') or key=='robotModel':category='现有Webots模型 / 已读取'
    elif key=='ballMassKg':category='显式假设 / 源参数未知，待实测'
    elif isinstance(value,str):category='设计/来源说明'
    lines.append(f'| {key} | {json.dumps(value,ensure_ascii=False)} | {units.get(key,"—")} | {category} |')
(out/'webots_parameters.md').write_text('\n'.join(lines)+'\n');(out/'webots_config.json').write_text(json.dumps(c,indent=2)+'\n')
