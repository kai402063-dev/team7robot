function ball = ballModel(ball, P)
%BALLMODEL  (WP B) Rolling ball with constant friction deceleration,
%   bouncing off the outer edge of the border strip.
v = hypot(ball.vx, ball.vy);
if v > 0
    vNew = max(0, v - P.ballDecel*P.dt);
    ball.vx = ball.vx * vNew/v;
    ball.vy = ball.vy * vNew/v;
end
ball.x = ball.x + ball.vx*P.dt;
ball.y = ball.y + ball.vy*P.dt;

xl = P.L/2 + P.border - P.ballR;
yl = P.W/2 + P.border - P.ballR;
if abs(ball.x) > xl
    ball.x = sign(ball.x)*xl;  ball.vx = -P.ballRestit*ball.vx;
end
if abs(ball.y) > yl
    ball.y = sign(ball.y)*yl;  ball.vy = -P.ballRestit*ball.vy;
end
end
