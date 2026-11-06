function [next,feedback,kicker,reasons]=Plant2D(world,requests,tSim,P,forceFailure)
%PLANT2D Own physical state and environment-only random kick samples.
coder.extrinsic('randn');
if nargin<5,forceFailure=false(1,8);end
kicker=0;
reasons=repmat(TdpV1Reason.None,1,8);
next=world;next.referee.t=tSim;cmds=zeros(8,3);kicked=false;
feedback=repmat(struct('requestId',uint32(0),'status',TdpStatus.None,'stamp',0),1,8);
step=round(tSim/P.dt);order=[1 2 3 4 5 6 7 8];
if mod(step,2)==0,order=[5 6 7 8 1 2 3 4];end
for a=1:8
 i=order(a);
 if ~world.active(i),continue;end
 obs=Observation2D(next,i,tSim,P);
 [m,fb,cmd,dk,kv,reasons(i)]=Actuator2D(next.actuator(i),requests(i),obs,tSim,P,~kicked,0,forceFailure(i));
 if dk
  z=0;z=randn();
  [~,~,~,~,kv]=Actuator2D(next.actuator(i),requests(i),obs,tSim,P,~kicked,z,forceFailure(i));
  next.ball.vx=kv(1);next.ball.vy=kv(2);next.robots(i).cool=P.kickCooldown;
  next.referee.lastTouch=next.robots(i).team;
  if requests(i).speed>=P.shotSpeed && (next.robots(i).role==TdpRole.ST || next.robots(i).role==TdpRole.MF)
   next.referee.shots(next.robots(i).team)=next.referee.shots(next.robots(i).team)+1;
  end
  kicker=i;kicked=true;next.kickCount=next.kickCount+uint32(1);
 end
 next.actuator(i)=m;feedback(i)=fb;cmds(i,:)=cmd;
end
oldRobots=next.robots;next.robots=tdp.robotModel(next.robots,cmds,P);
for i=1:8,if ~world.active(i),next.robots(i)=oldRobots(i);end,end
playing=tSim>=world.referee.pauseUntil;
if playing,next.ball=tdp.ballModel(next.ball,P);end
[next.robots,next.ball,next.referee]=Contact2D(next.robots,next.ball,next.referee,playing,world.active,P);
if playing
 if next.referee.lastTouch>0
  next.referee.touchTime(next.referee.lastTouch)=next.referee.touchTime(next.referee.lastTouch)+P.dt;
 end
 [next.robots,next.ball,next.referee]=Referee2D(next.robots,next.ball,next.referee,P);
end
next.lastCommands=cmds;next.lastKick=kicked;
end
