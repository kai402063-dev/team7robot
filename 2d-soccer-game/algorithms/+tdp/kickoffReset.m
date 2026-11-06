function [robots, ball] = kickoffReset(robots, ball, P)
%KICKOFFRESET  Put every robot in its own half and the ball on the centre spot.
base = [-4.2  0.0;     % goalkeeper
        -2.6  0.9;
        -2.6 -0.9;
        -1.0  0.0];
for k = 1:numel(robots)
    s = P.dirSign(robots(k).team);
    p = base(robots(k).num, :);
    robots(k).x  = s * p(1);
    robots(k).y  = s * p(2);
    robots(k).th = (s < 0) * pi;     % face the opponent goal
    robots(k).vxw = 0; robots(k).vyw = 0; robots(k).cool = 0;
end
ball.x = 0; ball.y = 0; ball.vx = 0; ball.vy = 0;
end
