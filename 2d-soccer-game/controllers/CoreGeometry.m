function g=CoreGeometry(obs,intent,tSim,P)
%COREGEOMETRY Compute requests only from explicitly supplied observations.
g=struct('command',[0 0 0],'target',intent.target,'speed',intent.speed,'ready',false,'distance',0, ...
 'safe',false,'ballVisible',false,'running',obs.gameRunning,'intent',intent.type);
i=obs.selfIndex;t=tSim;
g.safe=obs.selfValid && obs.robotValid(i) && isfinite(obs.robotStamp(i)) && ...
 t>=obs.robotStamp(i) && t-obs.robotStamp(i)<=P.maxObservationAge;
g.ballVisible=obs.ballValid && isfinite(obs.ballStamp) && ...
 t>=obs.ballStamp && t-obs.ballStamp<=P.maxObservationAge;
if ~g.safe,return;end
robots=obs.robots;
% Invalid obstacle slots coincide with self and are skipped by A's d>epsilon guard.
for j=1:8
 if ~obs.robotValid(j) || ~isfinite(obs.robotStamp(j)) || t<obs.robotStamp(j) || t-obs.robotStamp(j)>P.maxObservationAge
  robots(j).x=robots(i).x;robots(j).y=robots(i).y;
 end
end
r=robots(i);g.distance=hypot(obs.ball.x-r.x,obs.ball.y-r.y);
if intent.type==TdpAction.Goto
 g.command=tdp.goToPose(r,intent.target,intent.heading,robots,i,obs.ball,false,P);
elseif g.ballVisible && (intent.type==TdpAction.Kick || intent.type==TdpAction.Tap)
 [g.command,g.ready,~]=tdp.kickSkill(r,obs.ball,intent.target,intent.speed,robots,i, ...
  obs.gameRunning && obs.allowKick,P,0);
end
end
