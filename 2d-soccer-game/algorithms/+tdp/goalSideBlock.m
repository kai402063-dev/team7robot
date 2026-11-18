function [block, oldBlock] = goalSideBlock(ball, team, defDist, P)
%GOALSIDEBLOCK (F4/Yu) Defender block point that never passes the ball.
%   [block, oldBlock] = tdp.goalSideBlock(ball, team, defDist, P)
%   ball = [x y] world. oldBlock reproduces v1TeamPlans.m lines 84-93:
%   a point defDist from the own goal centre on the goal->ball line. When
%   the ball is closer than defDist that point lies BEYOND the ball (on the
%   opponent side), the known V1 anomaly in handoff section 6.3.
%   block uses the distance min(defDist, |ball-goal| - gap), gap =
%   robotR + ballR + 0.05 m, so the defender always stays between the ball
%   and its own goal. Both points get the same clamps as V1 (own half,
%   inside the pitch by one robot radius).

d = P.dirSign(team);
ownGoal = [-d*P.L/2 0];
threat = ball - ownGoal;
dist = hypot(threat(1), threat(2));
fallback = [d*(-P.L/2 + defDist) 0];
gap = P.robotR + P.ballR + 0.05;
if dist > 1e-9
    oldBlock = ownGoal + defDist*threat/dist;
    block = ownGoal + min(defDist, max(dist - gap, 0))*threat/dist;
else
    oldBlock = fallback;
    block = fallback;
end
oldBlock = clampV1(oldBlock, d, P);
block = clampV1(block, d, P);
end

function p = clampV1(p, d, P)
p(1) = d*min(max(d*p(1), -P.L/2 + P.robotR), -P.robotR);
p = [min(max(p(1), -P.L/2 + P.robotR), P.L/2 - P.robotR), ...
     min(max(p(2), -P.W/2 + P.robotR), P.W/2 - P.robotR)];
end
