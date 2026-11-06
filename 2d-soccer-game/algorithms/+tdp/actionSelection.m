function actions=actionSelection(robots,ball,team,roles,P)
%ACTIONSELECTION A teamBehaviour.m lines 45-96, with typed roles/actions.
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

gk=find(roles==TdpRole.GK,1);striker=find(roles==TdpRole.ST,1);
defender=find(roles==TdpRole.DF,1);supporter=find(roles==TdpRole.SP);
actions=repmat(struct('type',TdpAction.Goto,'target',[0 0],'heading',0, ...
    'speed',0,'role',TdpRole.Unknown),1,4);
% ---------- goalkeeper ----------
gx = ownGoal(1) + s*0.35;
ty = min(max(0.5*b(2), -(P.goalW/2 - 0.15)), P.goalW/2 - 0.15);
inBox = abs(b(1) - ownGoal(1)) < P.penAreaL && abs(b(2)) < P.penAreaW/2;
dGK   = norm(b - pos(gk,:));
if inBox && dGK < 1.2
    side = sign(b(2)); if side == 0, side = 1; end
    actions(gk) = mkKick([s*1.0, side*2.5], P.shotSpeed, TdpRole.GK);
else
    actions(gk) = mkGoto([gx ty], facing, TdpRole.GK);
end

% ---------- striker ----------
distGoal = norm(oppGoal - b);
oppGK = opp([robots(opp).isGK]);
gy = 0; if ~isempty(oppGK), gy = robots(oppGK(1)).y; end
aimYs = [-0.8 0 0.8];
[~, m] = max(abs(aimYs - gy));                     % aim away from their keeper
aim = [oppGoal(1), aimYs(m)];
act = mkKick([oppGoal(1), 0.5*b(2)], P.dribbleSpeed, TdpRole.ST);   % default: dribble
if distGoal < P.shootDist
    act = mkKick(aim, P.shotSpeed, TdpRole.ST);
elseif ~isempty(supporter)
    sp = pos(supporter(1), :);
    dP = norm(sp - b);
    if s*(sp(1) - b(1)) > 1.0 && dP < 4.5 && tdp.laneClear(b, sp, oppPos, 0.4)
        act = mkKick(sp, min(P.maxKickSpeed, sqrt(2*P.ballDecel*dP) + 0.2), TdpRole.ST);
    end
end
actions(striker) = act;

% ---------- defender ----------
dD = norm(b - pos(defender,:));
if s*b(1) < 0 && dD < 0.9
    actions(defender) = mkKick(oppGoal, P.shotSpeed, TdpRole.DF);   % clear it
else
    u = b - ownGoal;  if norm(u) < 1e-6, u = [s 0]; end
    tgt = ownGoal + P.defDist*u/norm(u);
    if s*tgt(1) > -0.3, tgt(1) = -0.3*s; end                 % stay in own half
    hb = b - tgt;
    actions(defender) = mkGoto(tgt, atan2(hb(2), hb(1)), TdpRole.DF);
end

% ---------- supporter ----------
for k = 1:numel(supporter)
    i = supporter(k);
    tx = s*min(max(s*(b(1) + s*1.5), -1), P.L/2 - 1.2);
    side = -sign(b(2)); if side == 0, side = 1; end
    tgt = [tx, side*1.4];
    hb = b - tgt;
    actions(i) = mkGoto(tgt, atan2(hb(2), hb(1)), TdpRole.SP);
end
end
function a = mkGoto(target, heading, role)
a = struct('type',TdpAction.Goto,'target',target,'heading',heading,'speed',0,'role',role);
end

function a = mkKick(target, speed, role)
a = struct('type',TdpAction.Kick,'target',target,'heading',0,'speed',speed,'role',role);
end

