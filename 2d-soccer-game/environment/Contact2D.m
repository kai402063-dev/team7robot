function [robots,ball,state]=Contact2D(robots,ball,state,ballActive,active,P)
%CONTACT2D Select legacy contacts or bounded iterative circle separation.
if P.rulesProfile==TdpRules.ACompat
 [robots,ball,state]=tdp.collisions(robots,ball,state,ballActive,P);return
end
minD=2*P.robotR;xmax=P.L/2+P.border-P.robotR;ymax=P.W/2+P.border-P.robotR;
worst=inf;
for iteration=1:P.contactIterations
 for i=1:7
  if ~active(i),continue;end
  for j=i+1:8
   if ~active(j),continue;end
   dx=robots(j).x-robots(i).x;dy=robots(j).y-robots(i).y;d=hypot(dx,dy);
   if d<minD
    if d<1e-12
     angle=2*pi*(8*i+j)/64;ux=cos(angle);uy=sin(angle);
    else,ux=dx/d;uy=dy/d;end
    shift=(minD-d)/2;
    robots(i).x=robots(i).x-shift*ux;robots(i).y=robots(i).y-shift*uy;
    robots(j).x=robots(j).x+shift*ux;robots(j).y=robots(j).y+shift*uy;
   end
  end
 end
 for i=1:8
  if active(i)
   robots(i).x=min(max(robots(i).x,-xmax),xmax);robots(i).y=min(max(robots(i).y,-ymax),ymax);
  end
 end
 worst=0;
 for i=1:7,for j=i+1:8
  if active(i)&&active(j),worst=max(worst,minD-hypot(robots(j).x-robots(i).x,robots(j).y-robots(i).y));end
 end,end
 if worst<=P.contactTolerance,break;end
end
assert(worst<=max(20*P.contactTolerance,1e-8),'TDP:ContactConvergence');
if ~ballActive,return;end
% Apply A's ball contact impulse once, after robot positions converge.
for k=1:8
 if ~active(k),continue;end
 dx=ball.x-robots(k).x;dy=ball.y-robots(k).y;d=hypot(dx,dy);minB=P.robotR+P.ballR;
 if d<minB
  if d<1e-9,dx=cos(robots(k).th);dy=sin(robots(k).th);d=1;end
  nx=dx/d;ny=dy/d;ball.x=robots(k).x+nx*minB;ball.y=robots(k).y+ny*minB;
  vn=(ball.vx-robots(k).vxw)*nx+(ball.vy-robots(k).vyw)*ny;
  if vn<0,ball.vx=ball.vx-(1+P.ballRobotE)*vn*nx;ball.vy=ball.vy-(1+P.ballRobotE)*vn*ny;end
  state.lastTouch=robots(k).team;
 end
end
end
