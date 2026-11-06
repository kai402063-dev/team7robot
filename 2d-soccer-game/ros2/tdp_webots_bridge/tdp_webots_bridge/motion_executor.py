"""Idempotent finite Webots motions. Motion completion is not ball contact."""
from enum import IntEnum
import math

class Status(IntEnum):
    NONE=0
    RUNNING=1
    DONE=2
    FAILED=3
    REJECTED=4

class Action(IntEnum):
    STOP=0
    GOTO=1
    KICK=2
    SEARCH=3
    TAP=4

class MotionExecutor:
    def __init__(self, motions, walk_reference=(.25,.15,.7853981633974483)):
        self.motions=motions
        assert len(walk_reference)==3 and all(math.isfinite(v) and v>0 for v in walk_reference)
        self.walk_reference=walk_reference
        self.current=None
        self.current_name=None
        self.seen_id=0
        self.active_id=None
        self.feedback=[0,Status.NONE,0.0]
        self.walk=[0.0,0.0,0.0]
        self.valid_until=-1.0
        self.executions=0
        self.acceptances=0
        self.events=[]
        self.shooting=False

    def stop_motion(self):
        if self.current is not None:self.current.stop()
        self.current=None;self.current_name=None

    def play(self,name):
        self.stop_motion()
        self.current=self.motions[name];self.current_name=name
        self.current.setLoop(False);self.current.setTime(0);self.current.play()

    def reject(self,rid,now,reason):
        self.events.append({'event':'rejected','requestId':rid,'time':now,'reason':reason})
        if self.active_id is None:self.feedback=[rid,Status.REJECTED,now]

    def receive(self,record,now):
        if len(record)!=11 or not all(math.isfinite(v) for v in record):
            raise ValueError('Expected 11 finite action values')
        kind,rid=record[0],record[1]
        if rid<0 or rid>2**32-1 or rid!=int(rid) or kind not in range(5):
            raise ValueError('Invalid action or requestId')
        rid=int(rid);kind=Action(kind)
        if rid<self.seen_id:
            self.reject(rid,now,'late request');return
        if rid==self.seen_id:
            return  # Never restart or extend the validity of a duplicate.
        if record[9]>now+1e-9 or record[10]<now-1e-9:
            self.seen_id=rid;self.reject(rid,now,'future or expired');return
        self.seen_id=rid
        if kind==Action.STOP:
            self.walk=[0.0,0.0,0.0];self.valid_until=now
            self.fail(now,'controller stop')
            self.stop_motion();return
        if kind in (Action.KICK,Action.TAP):
            if self.active_id is not None:
                self.reject(rid,now,'busy');return
            self.active_id=rid;self.shooting=False
            self.acceptances+=1;self.feedback=[rid,Status.RUNNING,now]
            self.events.append({'event':'accepted','requestId':rid,'time':now,'kind':int(kind)})
            return
        if self.active_id is not None:
            self.reject(rid,now,'busy');return
        self.walk=list(record[3:6]);self.valid_until=record[10]

    def fail(self,now,reason):
        if self.active_id is not None:
            self.feedback=[self.active_id,Status.FAILED,now]
            self.events.append({'event':'failed','requestId':self.active_id,'time':now,'reason':reason})
        self.active_id=None;self.shooting=False

    def tick(self,now,ball_xy,upright=True):
        if not upright:
            self.fail(now,'upright criterion failed');self.stop_motion();return
        if self.active_id is not None:
            if not self.shooting:
                if self.current is None or self.current.isOver():
                    self.play('Shoot');self.shooting=True;self.executions+=1
                    self.events.append({'event':'motion_start','requestId':self.active_id,'time':now,'ball':list(ball_xy)})
            elif self.current.isOver():
                self.feedback=[self.active_id,Status.DONE,now]
                self.events.append({'event':'motion_end','requestId':self.active_id,'time':now,'ball':list(ball_xy)})
                self.active_id=None;self.shooting=False;self.stop_motion();self.walk=[0.0,0.0,0.0]
            return
        if now>self.valid_until+1e-9 or max(abs(v) for v in self.walk)<1e-5:
            self.stop_motion();return
        if self.current is not None and not self.current.isOver():return
        vx,vy,w=self.walk
        strengths=[abs(v)/scale for v,scale in zip((vx,vy,w),self.walk_reference)]
        index=max(range(3),key=lambda k:strengths[k])
        name=('Forwards' if vx>=0 else 'Backwards') if index==0 else (
             ('SideStepLeft' if vy>=0 else 'SideStepRight') if index==1 else ('TurnLeft40' if w>=0 else 'TurnRight40'))
        self.play(name)
