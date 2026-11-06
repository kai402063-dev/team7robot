function cmd = goToPose(r, target, heading, robots, self, ball, avoidBall, P)
%GOTOPOSE  (WP C) Walk to a point, then turn to a final heading.
%   Proportional control on position and heading, plus a repulsive
%   field around other robots (and optionally the ball).
%   Returns cmd = [vx vy w] in the robot body frame.
err = target(:)' - [r.x r.y];
d = norm(err);
vW = P.Kp * err;

for j = 1:numel(robots)                      % avoid other robots
    if j == self, continue; end
    dv = [r.x - robots(j).x, r.y - robots(j).y];  dj = norm(dv);
    if dj < P.avoidR && dj > 1e-9
        vW = vW + P.avoidGain*(P.avoidR - dj)/P.avoidR * dv/dj;
    end
end
if avoidBall                                 % circle round the ball
    dv = [r.x - ball.x, r.y - ball.y];  db = norm(dv);
    if db < P.ballAvoidR && db > 1e-9
        vW = vW + 1.0*(P.ballAvoidR - db)/P.ballAvoidR * dv/db;
    end
end

if d > 0.5
    thDes = atan2(err(2), err(1));           % face where we are walking
else
    thDes = heading;                         % final heading when close
end
eTh = angWrap(thDes - r.th);

c = cos(r.th);  s = sin(r.th);
vx =  c*vW(1) + s*vW(2);                     % world -> body frame
vy = -s*vW(1) + c*vW(2);
if abs(eTh) > pi/3, vx = 0.3*vx; end         % turn first, then walk
cmd = [vx, vy, P.Kw*eTh];
end
