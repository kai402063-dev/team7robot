function obs=Observation2D(world,self,tSim,P)
%OBSERVATION2D Explicit ideal sensing adapter; no controller truth access.
obs=struct('selfIndex',self,'robots',world.robots,'robotValid',world.active,'robotStamp',repmat(world.referee.t,1,8), ...
 'ball',world.ball,'ballValid',true,'ballStamp',world.referee.t,'selfValid',world.active(self), ...
 'gameRunning',tSim>=world.referee.pauseUntil,'allowKick',true,'tSim',tSim);
r=world.robots(self);
a=tdp.angWrap(atan2(world.ball.y-r.y,world.ball.x-r.x)-r.th);
obs.ballValid=abs(a)<=P.fieldOfView/2;
end
