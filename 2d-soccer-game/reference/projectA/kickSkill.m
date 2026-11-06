function [cmd, doKick, kickV] = kickSkill(r, ball, target, speed, robots, self, allowKick, P)
%KICKSKILL  (WP C) Get behind the ball, line up with the target, kick.
%   doKick = true on the step the kick happens; kickV is the ball velocity.
b = [ball.x ball.y];
dir = target(:)' - b;
if norm(dir) < 1e-6, dir = [1 0]; end
dir = dir / norm(dir);
thDir = atan2(dir(2), dir(1));

rb = b - [r.x r.y];  dB = norm(rb);
cosBehind = dot(rb, dir) / max(dB, 1e-6);    % 1 = directly behind the ball
he = angWrap(thDir - r.th);

doKick = false;  kickV = [0 0];
if allowKick && r.cool <= 0 && dB < P.kickRange && ...
        cosBehind > cos(P.behindTol) && abs(he) < P.kickAlign
    ang = thDir + P.kickNoise*randn;
    kickV = min(speed, P.maxKickSpeed) * [cos(ang) sin(ang)];
    doKick = true;
    cmd = [0 0 0];
    return
end

if cosBehind > cos(P.behindTol) && dB < 0.8
    % already behind the ball: step in to kicking distance
    % (no robot avoidance here, otherwise two robots contesting the
    %  ball push each other off and freeze)
    tgt = b - dir*(P.robotR + P.ballR - 0.01);
    err = tgt - [r.x r.y];
    v = max(P.Kp*norm(err), P.stepInSpeed) * err/max(norm(err), 1e-6);
    c = cos(r.th);  s = sin(r.th);
    cmd = [c*v(1) + s*v(2), -s*v(1) + c*v(2), P.Kw*he];
else
    % walk round to the stand-off point behind the ball
    tgt = b - dir*P.approachDist;
    cmd = goToPose(r, tgt, thDir, robots, self, ball, true, P);
end
end
