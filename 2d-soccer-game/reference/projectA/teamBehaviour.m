function [actions, mem] = teamBehaviour(robots, ball, team, mem, P)
%TEAMBEHAVIOUR  (WP D) Decide what each robot of one team does this step.
%   Roles: GK goalkeeper (fixed), ST striker, DF defender, SP supporter.
%   The striker is chosen dynamically (closest to the ball, with
%   hysteresis); of the other two, the one nearer our goal defends.
%   Each action is either 'goto' (target, heading) or 'kick' (target, speed).
idx  = find([robots.team] == team);
n    = numel(idx);
s    = P.dirSign(team);
oppGoal = [ s*P.L/2, 0];
ownGoal = [-s*P.L/2, 0];
b    = [ball.x ball.y];
pos  = [[robots(idx).x]' [robots(idx).y]'];
opp  = find([robots.team] ~= team);
oppPos = [[robots(opp).x]' [robots(opp).y]'];
facing = (s < 0)*pi;

actions = repmat(struct('type','goto','target',[0 0],'heading',0, ...
                        'speed',0,'role',''), 1, n);

gk    = find([robots(idx).isGK], 1);
field = setdiff(1:n, gk);

% ---------- role allocation ----------
cost = zeros(1, numel(field));
for k = 1:numel(field)
    i  = field(k);  rb = b - pos(i,:);
    wrongSide = s*(pos(i,1) - b(1)) > 0;          % robot is past the ball
    cost(k) = norm(rb) + 0.3*abs(angWrap(atan2(rb(2),rb(1)) - robots(idx(i)).th)) ...
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

% ---------- goalkeeper ----------
gx = ownGoal(1) + s*0.35;
ty = min(max(0.5*b(2), -(P.goalW/2 - 0.15)), P.goalW/2 - 0.15);
inBox = abs(b(1) - ownGoal(1)) < P.penAreaL && abs(b(2)) < P.penAreaW/2;
dGK   = norm(b - pos(gk,:));
if inBox && dGK < 1.2
    side = sign(b(2)); if side == 0, side = 1; end
    actions(gk) = mkKick([s*1.0, side*2.5], P.shotSpeed, 'GK');
else
    actions(gk) = mkGoto([gx ty], facing, 'GK');
end

% ---------- striker ----------
distGoal = norm(oppGoal - b);
oppGK = opp([robots(opp).isGK]);
gy = 0; if ~isempty(oppGK), gy = robots(oppGK(1)).y; end
aimYs = [-0.8 0 0.8];
[~, m] = max(abs(aimYs - gy));                     % aim away from their keeper
aim = [oppGoal(1), aimYs(m)];
act = mkKick([oppGoal(1), 0.5*b(2)], P.dribbleSpeed, 'ST');   % default: dribble
if distGoal < P.shootDist
    act = mkKick(aim, P.shotSpeed, 'ST');
elseif ~isempty(supporter)
    sp = pos(supporter(1), :);
    dP = norm(sp - b);
    if s*(sp(1) - b(1)) > 1.0 && dP < 4.5 && laneClear(b, sp, oppPos, 0.4)
        act = mkKick(sp, min(P.maxKickSpeed, sqrt(2*P.ballDecel*dP) + 0.2), 'ST');
    end
end
actions(striker) = act;

% ---------- defender ----------
dD = norm(b - pos(defender,:));
if s*b(1) < 0 && dD < 0.9
    actions(defender) = mkKick(oppGoal, P.shotSpeed, 'DF');   % clear it
else
    u = b - ownGoal;  if norm(u) < 1e-6, u = [s 0]; end
    tgt = ownGoal + P.defDist*u/norm(u);
    if s*tgt(1) > -0.3, tgt(1) = -0.3*s; end                 % stay in own half
    hb = b - tgt;
    actions(defender) = mkGoto(tgt, atan2(hb(2), hb(1)), 'DF');
end

% ---------- supporter ----------
for i = supporter
    tx = s*min(max(s*(b(1) + s*1.5), -1), P.L/2 - 1.2);
    side = -sign(b(2)); if side == 0, side = 1; end
    tgt = [tx, side*1.4];
    hb = b - tgt;
    actions(i) = mkGoto(tgt, atan2(hb(2), hb(1)), 'SP');
end
end

% ---------------------------------------------------------------
function a = mkGoto(target, heading, role)
a = struct('type','goto','target',target,'heading',heading,'speed',0,'role',role);
end

function a = mkKick(target, speed, role)
a = struct('type','kick','target',target,'heading',0,'speed',speed,'role',role);
end

function ok = laneClear(a, b, obstacles, margin)
% true if no obstacle is within margin of the segment a-b
ok = true;  ab = b - a;  L2 = dot(ab, ab);
if L2 < 1e-9, return; end
for k = 1:size(obstacles,1)
    t = min(max(dot(obstacles(k,:) - a, ab)/L2, 0), 1);
    if norm(a + t*ab - obstacles(k,:)) < margin
        ok = false; return
    end
end
end
