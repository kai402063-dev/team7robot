function [robots,ball,state]=initialState(P)
%INITIALSTATE Fixed eight-robot state, matching A initState and kickoffReset.
r=struct('team',0,'num',0,'isGK',false,'role',TdpRole.Unknown, ...
 'x',0,'y',0,'th',0,'vxw',0,'vyw',0,'cool',0);
robots=repmat(r,1,8);
for k=1:8
 robots(k).team=1+(k>4);robots(k).num=1+mod(k-1,4);robots(k).isGK=mod(k-1,4)==0;
end
ball=struct('x',0,'y',0,'vx',0,'vy',0);
state=struct('t',0,'score',[0 0],'lastTouch',0,'pauseUntil',0, ...
 'msg',TdpEvent.Kickoff,'msgUntil',2,'shots',[0 0],'touchTime',[0 0]);
[robots,ball]=tdp.kickoffReset(robots,ball,P);
end
