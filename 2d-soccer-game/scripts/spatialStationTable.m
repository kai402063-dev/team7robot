function [T, D, M] = spatialStationTable(P)
%SPATIALSTATIONTABLE (F4/Yu) Which zone each default station falls in.
%   [T, D] = spatialStationTable()        uses tdp.v1Config()
%   T: one row per (profile, role). Station rules are those of
%   v1TeamPlans.m / handoff section 5, evaluated in the team frame with the
%   ball straight ahead on the centre line (lateral 0) and, for the lateral
%   range, with the ball anywhere across the pitch width.
%   Values: "V1 repo" = this repository (v1Config + defaultConfig);
%   Neutral/Aggressive/Defensive = numbers quoted in F4 handoff section 3
%   (V1.2 code itself is not in this repository).
%   Margin = distance from the station to the nearest zone depth line;
%   below P.zoneHysteresis (0.20 m) the station's zone label can flip.
%   D: the V1 DF anomaly (section 6.3) measured on a 5 cm grid of ball
%   positions in the own half (balls at least robotR+5 cm in front of the
%   goal line): share of positions where the old block point
%   is farther from the own goal than the ball, and the same for the fix.
%   M: the two moving MF stations of handoff section 5, swept over all
%   positions they can take (team frame):
%     MF cover  (V1.2 Neutral/Defensive when the DF intercepts): halfway
%               between ball and own goal, at most defDist from the goal.
%               Swept over the same own-half ball grid as D.
%     MF attack (V1 and all V1.2 profiles): v1SupportTrail behind the ST
%               and v1SupportWidth to either side; ST swept over the whole
%               opponent half.
%   ZoneExample/MarginExample: ball straight ahead on the midline (cover),
%   ST at f = +2.0 (attack). ShareNearLine: share of swept positions closer
%   than zoneHysteresis to a zone depth line. ShareGoalSideOrOwnHalf: cover =
%   share of positions between ball and own goal; attack = share inside the
%   own half (f < 0). ShareTooCloseToBall: cover point closer than 2*robotR
%   to the ball.

if nargin < 1, P = tdp.v1Config(); end
Z = tdp.spatialZones(P);
h = P.L/2;
prof = struct( ...
  'name',   {'V1 repo','Neutral','Aggressive','Defensive'}, ...
  'defDist',{P.defDist, 1.8, 2.6, 1.5}, ...
  'screen', {P.v1ScreenDepth, 1.4, 0.8, 2.0}, ...
  'counter',{P.v1CounterDepth, 0.4, 0.4, 1.0});

rows = {};
for p = prof
    st = { ...
      'GK', 'x=-L/2+keeperInset, y=0.5*ballY in posts', -h + P.v1KeeperInset, P.goalW/2 - P.robotR;
      'DF', 'goal->ball line at defDist',               -h + p.defDist,        p.defDist;
      'MF', 'x=-screenDepth, y=0.5*ballY',               -p.screen,             P.W/4;
      'ST', 'x=-counterDepth, y=+0.8 fixed',             -p.counter,            P.v1SupportWidth};
    for k = 1:size(st,1)
        f = st{k,3};
        [zStraight] = tdp.spatialZone(f, 0, 1, P, 0, Inf);
        % lateral extreme (DF: on the circle of radius defDist, worst case
        % when the ball is far out wide; others: given |lat| max)
        if strcmp(st{k,1},'DF')
            ang = linspace(-pi/2, pi/2, 181);
            zs = unique(tdp.spatialZone(-h + p.defDist*cos(ang), p.defDist*sin(ang), 1, P, 0, Inf));
        else
            zs = unique(tdp.spatialZone([f f], [0 st{k,4}], 1, P, 0, Inf));
        end
        margin = min(abs(Z.depthLines - f));
        rows(end+1,:) = {p.name, st{k,1}, st{k,2}, f, Z.names{zStraight}, ...
            strjoin(Z.names(zs), '/'), margin}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', ...
    {'Profile','Role','Rule','StationF','ZoneBallAhead','ZonesAllBallY','MarginToLine'});

% DF anomaly on a grid of ball positions in the blue half (team 1)
% Balls closer than robotR to the goal line are skipped: there the V1
% insidePitch clamp itself puts any station in front of the ball.
[gx, gy] = meshgrid(-h + P.robotR + 0.05:0.05:0, -P.W/2:0.05:P.W/2);
ownGoal = [-h 0];
D = struct('defDist', [], 'oldAhead', [], 'newAhead', []);
for p = prof
    oldA = 0; newA = 0;
    for k = 1:numel(gx)
        [b, o] = tdp.goalSideBlock([gx(k) gy(k)], 1, p.defDist, P);
        dBall = hypot(gx(k) - ownGoal(1), gy(k) - ownGoal(2));
        oldA = oldA + (hypot(o(1) - ownGoal(1), o(2) - ownGoal(2)) > dBall);
        newA = newA + (hypot(b(1) - ownGoal(1), b(2) - ownGoal(2)) > dBall);
    end
    D(end+1) = struct('defDist', p.defDist, 'oldAhead', oldA/numel(gx), ...
                      'newAhead', newA/numel(gx)); %#ok<AGROW>
end
D(1) = [];

% ---- MF cover and MF attack stations (handoff section 5, rows 4-5) ----
% Both depend on the ball / ST position, so they are swept, not a single
% point. Zones use margin = Inf (robots may stand outside the lines).
hyst = 0.20;
if isfield(P,'zoneHysteresis'), hyst = P.zoneHysteresis; end
nearLine = @(f) min(abs(f(:) - Z.depthLines), [], 2) < hyst;
mrows = {};
% MF cover: halfway between ball and own goal, never farther than defDist
% from the goal (V1.2 v12CoverDefender: Neutral and Defensive only; V1 has no cover).
coverProf = struct('name', {'Neutral','Defensive'}, 'defDist', {1.8, 1.5});
for p = coverProf
    cf = zeros(numel(gx),1); goalSide = true(numel(gx),1); tooClose = false(numel(gx),1);
    cz = zeros(numel(gx),1);
    for k = 1:numel(gx)
        b = [gx(k) gy(k)];
        v = b - ownGoal; dist = hypot(v(1), v(2));
        c = ownGoal + min(0.5*dist, p.defDist)*v/dist;
        c = [min(max(c(1), -h + P.robotR), -P.robotR), min(max(c(2), -P.W/2 + P.robotR), P.W/2 - P.robotR)];
        cf(k) = c(1);
        cz(k) = tdp.spatialZone(c(1), c(2), 1, P, 0, Inf);
        goalSide(k) = hypot(c(1)-ownGoal(1), c(2)-ownGoal(2)) <= dist + 1e-9;
        tooClose(k) = hypot(c(1)-b(1), c(2)-b(2)) < 2*P.robotR;
    end
    fAhead = -h + min(0.5*h, p.defDist);          % ball straight ahead on the midline
    mrows(end+1,:) = {p.name, 'MF cover', ...
        'midpoint ball-goal, <= defDist from goal', fAhead, ...
        Z.names{tdp.spatialZone(fAhead, 0, 1, P, 0, Inf)}, ...
        strjoin(Z.names(unique(cz)), '/'), min(abs(Z.depthLines - fAhead)), ...
        mean(nearLine(cf)), mean(goalSide), mean(tooClose)}; %#ok<AGROW>
end
% MF attack: v1SupportTrail behind the ST, v1SupportWidth to either side
% (the less crowded one; both sides are swept). Same in V1 and every V1.2 profile.
[sf, sl] = meshgrid(P.v1MidlineBand:0.05:h - P.robotR, -P.W/2 + P.robotR:0.05:P.W/2 - P.robotR);
af = []; al = [];
for s = [-1 1]
    af = [af; sf(:) - P.v1SupportTrail]; %#ok<AGROW>
    al = [al; min(max(sl(:) + s*P.v1SupportWidth, -P.W/2 + P.robotR), P.W/2 - P.robotR)]; %#ok<AGROW>
end
az = tdp.spatialZone(af, al, 1, P, 0, Inf);
stF = 2.0;                                        % example: ST at f = +2.0
mrows(end+1,:) = {'All profiles', 'MF attack', ...
    sprintf('%.2f m behind ST, %.2f m to a side', P.v1SupportTrail, P.v1SupportWidth), ...
    stF - P.v1SupportTrail, Z.names{tdp.spatialZone(stF - P.v1SupportTrail, 0, 1, P, 0, Inf)}, ...
    strjoin(Z.names(unique(az)), '/'), min(abs(Z.depthLines - (stF - P.v1SupportTrail))), ...
    mean(nearLine(af)), mean(af < 0), NaN};
M = cell2table(mrows, 'VariableNames', {'Profile','Role','Rule','StationF', ...
    'ZoneExample','ZonesSwept','MarginExample','ShareNearLine','ShareGoalSideOrOwnHalf','ShareTooCloseToBall'});
end
