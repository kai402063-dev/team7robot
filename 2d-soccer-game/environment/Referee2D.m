function [robots,ball,state]=Referee2D(robots,ball,state,P)
%REFEREE2D Explicit profiles; reference restarts are a documented subset.
if P.rulesProfile==TdpRules.ACompat
 [robots,ball,state]=tdp.rulesCheck(robots,ball,state,P);return
end
restart=false;owner=0;
if abs(ball.x)>P.L/2+P.ballR
 sx=sign(ball.x);attacker=1+(sx<0);
 if abs(ball.y)+P.ballR<P.goalW/2
  state.score(attacker)=state.score(attacker)+1;[robots,ball]=tdp.kickoffReset(robots,ball,P);
  state.pauseUntil=state.t+P.restartPause;state.msgUntil=state.t+2.5;
  if attacker==1,state.msg=TdpEvent.GoalBlue;else,state.msg=TdpEvent.GoalRed;end
  return
 end
 sy=sign(ball.y);if sy==0,sy=1;end
 if state.lastTouch==attacker
  owner=3-attacker;state.msg=TdpEvent.GoalKick;
  if P.rulesProfile==TdpRules.ReferenceRestarts,ball.x=0;ball.y=sy*P.W/2;
  else,ball.x=sx*(P.L/2-P.goalAreaL);ball.y=sy*P.goalAreaW/2;end
 else
  owner=attacker;state.msg=TdpEvent.Corner;
  if P.rulesProfile==TdpRules.ReferenceRestarts,ball.x=sx*P.L/2;ball.y=sy*P.W/2;
  else,ball.x=sx*(P.L/2-.25);ball.y=sy*(P.W/2-.25);end
 end
 restart=true;
elseif abs(ball.y)>P.W/2+P.ballR
 owner=3-state.lastTouch;state.msg=TdpEvent.KickIn;
 if P.rulesProfile==TdpRules.ReferenceRestarts
  ball.y=sign(ball.y)*P.W/2;ball.x=min(max(ball.x,-P.L/2),P.L/2);
 else
  ball.y=sign(ball.y)*(P.W/2-.25);ball.x=min(max(ball.x,-P.L/2+.25),P.L/2-.25);
 end
 restart=true;
end
if restart
 if state.lastTouch==0 && P.rulesProfile==TdpRules.ReferenceRestarts
  % Unknown ownership: an explicit teaching drop-ball reset, not an award.
  ball.x=0;ball.y=0;owner=0;state.msg=TdpEvent.Kickoff;
 end
 ball.vx=0;ball.vy=0;state.pauseUntil=state.t+P.outPause;state.msgUntil=state.t+1.5;
 if P.rulesProfile==TdpRules.ReferenceRestarts
  for i=1:8
   if owner==0 || robots(i).team~=owner
    dx=robots(i).x-ball.x;dy=robots(i).y-ball.y;d=hypot(dx,dy);
    if d<P.restartOpponentDistance
     if d<1e-12
      dx=-ball.x;dy=-ball.y;d=hypot(dx,dy);
      if d<1e-12,dx=cos(2*pi*i/8);dy=sin(2*pi*i/8);d=1;end
     end
     robots(i).x=ball.x+P.restartOpponentDistance*dx/d;
     robots(i).y=ball.y+P.restartOpponentDistance*dy/d;
    end
   end
  end
 end
end
end
