function [roles,mem] = roleAssignment(robots,ball,team,mem,P)
%ROLEASSIGNMENT A teamBehaviour.m lines 21-44; fixed four-player team.
idx = (1:4) + 4*(team-1);
n = 4;
s    = P.dirSign(team);
oppGoal = [ s*P.L/2, 0];
ownGoal = [-s*P.L/2, 0];
b    = [ball.x ball.y];
pos  = [[robots(idx).x]' [robots(idx).y]'];
opp  = find([robots.team] ~= team);
oppPos = [[robots(opp).x]' [robots(opp).y]'];
facing = (s < 0)*pi;

gk    = find([robots(idx).isGK], 1);
field = setdiff(1:n, gk);

% ---------- role allocation ----------
cost = zeros(1, numel(field));
for k = 1:numel(field)
    i  = field(k);  rb = b - pos(i,:);
    wrongSide = s*(pos(i,1) - b(1)) > 0;          % robot is past the ball
    cost(k) = norm(rb) + 0.3*abs(tdp.angWrap(atan2(rb(2),rb(1)) - robots(idx(i)).th)) ...
              + 0.5*wrongSide;
end
[cmin, kmin] = min(cost);
striker = field(kmin);
if any(field == mem.striker)                       % hysteresis
    if cost(field == mem.striker) < cmin + P.roleHyst
        striker = mem.striker;
    end
end
mem.striker = striker;
rest = setdiff(field, striker);
[~, o] = sort(s*pos(rest,1));                      % nearest our goal first
defender  = rest(o(1));
supporter = rest(o(2:end));

roles=repmat(TdpRole.SP,1,4);
roles(gk)=TdpRole.GK;roles(striker)=TdpRole.ST;roles(defender)=TdpRole.DF;
end
