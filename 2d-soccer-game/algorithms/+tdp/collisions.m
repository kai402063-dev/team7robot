function [robots, ball, state] = collisions(robots, ball, state, ballActive, P)
%COLLISIONS  Robot-robot separation and robot-ball contact (pushing).
n = numel(robots);
% robot-robot: push overlapping robots apart
for i = 1:n-1
    for j = i+1:n
        dx = robots(j).x - robots(i).x;  dy = robots(j).y - robots(i).y;
        d = hypot(dx, dy);  minD = 2*P.robotR;
        if d < minD && d > 1e-9
            o = (minD - d)/2;  ux = dx/d;  uy = dy/d;
            robots(i).x = robots(i).x - o*ux;  robots(i).y = robots(i).y - o*uy;
            robots(j).x = robots(j).x + o*ux;  robots(j).y = robots(j).y + o*uy;
        end
    end
end
if ~ballActive, return; end
% robot-ball: a robot walking into the ball pushes it (dribbling)
for k = 1:n
    dx = ball.x - robots(k).x;  dy = ball.y - robots(k).y;
    d = hypot(dx, dy);  minD = P.robotR + P.ballR;
    if d < minD
        if d < 1e-9, dx = cos(robots(k).th); dy = sin(robots(k).th); d = 1; end
        nx = dx/d;  ny = dy/d;
        ball.x = robots(k).x + nx*minD;
        ball.y = robots(k).y + ny*minD;
        vn = (ball.vx - robots(k).vxw)*nx + (ball.vy - robots(k).vyw)*ny;
        if vn < 0
            ball.vx = ball.vx - (1 + P.ballRobotE)*vn*nx;
            ball.vy = ball.vy - (1 + P.ballRobotE)*vn*ny;
        end
        state.lastTouch = robots(k).team;
    end
end
end
