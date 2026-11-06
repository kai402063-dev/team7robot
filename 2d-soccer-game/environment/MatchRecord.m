function row=MatchRecord(world,strikerBlue,strikerRed)
%MATCHRECORD Use the same 98-column schema as the immutable oracle.
r=world.robots;b=world.ball;s=world.referee;
v=[[r.x];[r.y];[r.th];[r.vxw];[r.vyw];[r.cool]]';
roles=zeros(1,8);for i=1:8,roles(i)=double(r(i).role);end
row=[v(:)' roles b.x b.y b.vx b.vy s.t s.score s.lastTouch s.pauseUntil ...
 s.shots s.touchTime s.msgUntil strikerBlue strikerRed world.lastCommands(:)' ...
 double(world.lastKick) double(s.msg)];
end
