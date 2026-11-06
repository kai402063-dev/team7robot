"""Render teaching figures from the executable chart and measured replay."""
import json
import os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
cache=root/'build/matplotlib'
cache.mkdir(parents=True,exist_ok=True)
os.environ['MPLCONFIGDIR']=str(cache)
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
import numpy as np
out=root/'docs/generated'
n=json.loads((out/'manual_numbers.json').read_text());r=np.array(n['replay']);time=np.arange(len(r))*n['dt']
fig,ax=plt.subplots(2,1,figsize=(10,5),sharex=True,layout='constrained')
ax[0].step(time,r[:,2],where='post');ax[0].set_yticks(range(6),['Idle','Search','Approach','Align','Kick','Recover']);ax[0].set_ylabel('Skill phase')
ax[1].step(time,r[:,1],where='post',label='requestId');ax[1].step(time,r[:,0],where='post',label='action kind');ax[1].legend();ax[1].set_xlabel('Input simulation time (s)')
for a in ax:a.grid(alpha=.25)
fig.savefig(out/'replay_timeline.png',dpi=160);plt.close(fig)
fig,ax=plt.subplots(figsize=(12,6));ax.set_xlim(0,12);ax.set_ylim(0,6);ax.axis('off')
nodes={'World memory':(1.1,3),'Observation2D':(3.2,3),'TeamCoordinator x2':(5.4,4.9),'Kick arbitration':(5.4,3),'ControllerCore x8':(7.7,3),'Plant + referee':(10.2,3),'Feedback delay':(7.7,1),'Viewer / logs':(10.2,5)}
for name,(x,y) in nodes.items():
 ax.add_patch(FancyBboxPatch((x-.95,y-.32),1.9,.64,boxstyle='round,pad=.06',facecolor='#e8f2fa',edgecolor='#285b80'));ax.text(x,y,name,ha='center',va='center',fontsize=9)
for a,b in [('World memory','Observation2D'),('Observation2D','TeamCoordinator x2'),('Observation2D','Kick arbitration'),('TeamCoordinator x2','Kick arbitration'),('Kick arbitration','ControllerCore x8'),('ControllerCore x8','Plant + referee'),('Plant + referee','Viewer / logs'),('Plant + referee','Feedback delay'),('Feedback delay','ControllerCore x8')]:
 start=np.array(nodes[a]);end=np.array(nodes[b]);delta=end-start;fraction=1/max(abs(delta[0])/.95,abs(delta[1])/.32)
 ax.annotate('',xy=end-delta*fraction,xytext=start+delta*fraction,arrowprops=dict(arrowstyle='->',color='#4c6475',shrinkA=3,shrinkB=3))
ax.plot([10.2,11.5,11.5,1.1],[2.65,2.65,.3,.3],color='#b66028')
ax.annotate('',xy=(1.1,2.65),xytext=(1.1,.3),arrowprops=dict(arrowstyle='->',color='#b66028'))
ax.text(6,.05,'World state is saved for the next step (Unit Delay)',ha='center',color='#b66028',fontsize=10)
fig.savefig(out/'architecture.png',dpi=160,bbox_inches='tight');plt.close(fig)
chart=json.loads((out/'stateflow.json').read_text());fig,ax=plt.subplots(figsize=(11,5));ax.axis('off');ax.set_xlim(0,11);ax.set_ylim(0,5)
ax.add_patch(FancyBboxPatch((2,.35),8.6,4.1,boxstyle='round,pad=.1',facecolor='#f6f9fc',edgecolor='#426784'));ax.text(2.2,4.1,'Active',fontsize=14)
pos={'Idle':(.8,2.4),'Search':(3.4,3.2),'Approach':(5.8,3.2),'Align':(8.3,3.2),'Kick':(8.3,1.3),'Recover':(4.7,1.3)}
for name,(x,y) in pos.items():
 ax.add_patch(FancyBboxPatch((x-.65,y-.3),1.3,.6,boxstyle='round,pad=.08',facecolor='#e0f0e8',edgecolor='#34745c'));ax.text(x,y,name,ha='center',va='center')
pairs=set()
for tr in chart['transitions']:
 a,b=tr['source'],tr['destination']
 if a in pos and b in pos and (a,b) not in pairs:
  pairs.add((a,b));ax.annotate('',xy=pos[b],xytext=pos[a],arrowprops=dict(arrowstyle='->',connectionstyle='arc3,rad=.12',shrinkA=34,shrinkB=34,color='#576c7c'))
ax.annotate('',xy=(2.5,2.4),xytext=(1.5,2.4),arrowprops=dict(arrowstyle='<->',color='#576c7c'))
ax.text(5.5,-.05,'Actual state names/transitions from SLX; full conditions and priorities are in stateflow.md',ha='center',fontsize=9)
fig.savefig(out/'stateflow.png',dpi=160,bbox_inches='tight');plt.close(fig)
