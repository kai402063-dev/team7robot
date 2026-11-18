function tests = test_spatial_zones
%TEST_SPATIAL_ZONES (F4/Yu) Zone map, hysteresis, mirror, half rule and the
% goal-side defender block. Covers the boundary cases in F4 handoff sec. 7.
% Run: tdpSetup; runtests('tests/test_spatial_zones.m')
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.P = tdp.v1Config();
t.TestData.Z = tdp.spatialZones(t.TestData.P);
end

%% ---------- zone map ----------
function testZoneTableFollowsPitchMarkings(t)
Z = t.TestData.Z;
verifyEqual(t, Z.depthLines, [-4.5 -3.5 -2.5 -1.5 0 1.5 2.5 3.5 4.5], 'AbsTol', 1e-12);
verifyEqual(t, Z.rect(1,:), [-4.5 -3.5 -1.5 1.5], 'AbsTol', 1e-12);
verifyEqual(t, Z.rect(2,:), [-4.5 -2.5 -2.5 2.5], 'AbsTol', 1e-12);
verifyEqual(t, Z.rect(8,:), [3.5 4.5 -1.5 1.5], 'AbsTol', 1e-12);
end

function testOneIdPerZoneCentre(t)
P = t.TestData.P;
pts = [-4.0 0; -3.0 2; -3.0 2.8; -0.7 0; 0.7 0; 2.0 0; 3.0 -2; 4.0 0];
for k = 1:8
    verifyEqual(t, tdp.spatialZone(pts(k,1), pts(k,2), 1, P), k, sprintf('zone %d', k));
end
end

function testTiesOnLines(t)
P = t.TestData.P;
z = @(x,y) tdp.spatialZone(x, y, 1, P);
verifyEqual(t, z(-3.5, 0), 1);      % goal-area line belongs to goal area
verifyEqual(t, z(-4.0, 1.5), 1);
verifyEqual(t, z(-2.5, 0), 2);      % penalty-area line belongs to penalty area
verifyEqual(t, z(-3.0, 2.5), 2);
verifyEqual(t, z(-1.5, 0), 3);      % third line -> zone nearer own goal
verifyEqual(t, z(0, 0), 4);         % midline -> own half
verifyEqual(t, z(1.5, 0), 5);
verifyEqual(t, z(2.5, 0), 7);       % opponent penalty-area line -> penalty area
verifyEqual(t, z(3.5, 1.5), 8);
end

function testRequestedCorners(t)
% handoff 7: own-third corner, goal line outside posts, goal area by GK
P = t.TestData.P;
verifyEqual(t, tdp.spatialZone(-4.45, 2.95, 1, P), 3);   % own-third corner
verifyEqual(t, tdp.spatialZone(-4.5, 1.40, 1, P), 1);    % on goal line, outside posts (1.3), still goal area
verifyEqual(t, tdp.spatialZone(-4.5, 2.00, 1, P), 2);    % on goal line, outside goal area
verifyEqual(t, tdp.spatialZone(-4.15, 0.30, 1, P), 1);   % next to the GK station
end

%% ---------- red/blue mirror ----------
function testRedIsPointMirrorOfBlue(t)
P = t.TestData.P;
rng(7);
x = (rand(300,1)-0.5)*(P.L + 0.2);
y = (rand(300,1)-0.5)*(P.W + 0.2);
[zb, fb, lb] = tdp.spatialZone(x, y, 1, P);
[zr, fr, lr] = tdp.spatialZone(-x, -y, 2, P);
verifyEqual(t, zr, zb);
verifyEqual(t, [fr lr], [fb lb]);
% zones are also left/right symmetric
verifyEqual(t, tdp.spatialZone(x, -y, 1, P), zb);
% hysteresis is mirrored too
prev = randi(8, 300, 1);
verifyEqual(t, tdp.spatialZone(-x, -y, 2, P, prev), tdp.spatialZone(x, y, 1, P, prev));
end

%% ---------- hysteresis ----------
function testJitterOnLineDoesNotFlip(t)
P = t.TestData.P;
for line = [-3.5 -2.5 -1.5 0 1.5 2.5 3.5]
    xs = line + 0.02*sin((1:200)*1.3);                  % +-2 cm jitter
    raw = tdp.spatialZone(xs, zeros(size(xs)), 1, P);
    verifyGreaterThan(t, nnz(diff(raw)), 0, 'raw map does flip');
    id = raw(1); seq = zeros(size(xs));
    for k = 1:numel(xs)
        id = tdp.spatialZone(xs(k), 0, 1, P, id); seq(k) = id;
    end
    verifyEqual(t, nnz(diff(seq)), 0, sprintf('line %.1f', line));
end
end

function testEnterAndExitThresholds(t)
P = t.TestData.P;
% start in zone 4 (own middle), move towards own goal past -1.5
verifyEqual(t, tdp.spatialZone(-1.69, 0, 1, P, 4), 4);   % 0.19 m past: still 4
verifyEqual(t, tdp.spatialZone(-1.71, 0, 1, P, 4), 3);   % 0.21 m past: enter 3
verifyEqual(t, tdp.spatialZone(-1.31, 0, 1, P, 3), 3);   % going back: hold 3
verifyEqual(t, tdp.spatialZone(-1.29, 0, 1, P, 3), 4);   % 0.21 m back: exit
% nested area: from own third into penalty area through its front line
verifyEqual(t, tdp.spatialZone(-2.65, 0, 1, P, 3), 3);
verifyEqual(t, tdp.spatialZone(-2.75, 0, 1, P, 3), 2);
% through the side line of the penalty area
verifyEqual(t, tdp.spatialZone(-3.0, 2.35, 1, P, 3), 3);
verifyEqual(t, tdp.spatialZone(-3.0, 2.25, 1, P, 3), 2);
% a jump far away is not held
verifyEqual(t, tdp.spatialZone(3.0, 0, 1, P, 3), 7);
% zoneHysteresis = 0 gives the raw map
P.zoneHysteresis = 0;
verifyEqual(t, tdp.spatialZone(-1.51, 0, 1, P, 4), 3);
end

%% ---------- off pitch / border strip ----------
function testBallOverLinesAndBorderStrip(t)
P = t.TestData.P;
% ball partly over the goal line is still in play (clamped onto the pitch)
verifyEqual(t, tdp.spatialZone(-4.55, 0, 1, P), 1);
verifyEqual(t, tdp.spatialZone(-4.4, 3.06, 1, P), 3);
% whole ball over: OffPitch (0), even with a remembered zone
verifyEqual(t, tdp.spatialZone(-4.6, 0, 1, P, 1), 0);
verifyEqual(t, tdp.spatialZone(1.0, 3.5, 1, P, 5), 0);   % in the 1 m border strip
verifyEqual(t, tdp.spatialZone(NaN, 0, 1, P), 0);
% robots may stand in the border: margin Inf clamps them to the nearest zone
verifyEqual(t, tdp.spatialZone(1.0, 3.5, 1, P, 0, Inf), 5);
verifyEqual(t, tdp.spatialZone(-4.8, 0, 1, P, 0, Inf), 1);   % behind the goal line
end

%% ---------- half rule (6.1) ----------
function testHalfStatisticsUseHardMidline(t)
P = t.TestData.P;
C = tdp.halfCodes();
x = [-0.10 -0.01 0.01 0.10 0.20];
[code, ~, band] = tdp.ballHalf(x, zeros(size(x)), false, P);
verifyEqual(t, code, [C.BlueHalf C.BlueHalf C.RedHalf C.RedHalf C.RedHalf]);
verifyEqual(t, band, [true true true true false]);
verifyEqual(t, tdp.ballHalf(0, 0, false, P), C.Midline);
% paused rows are never in the switch band
[~, ~, b2] = tdp.ballHalf(0.05, 0, true, P);
verifyFalse(t, b2);
end

function testDefendPhaseInsideBand(t)
% handoff 7: ball at +0.10 m while blue is still in Defend. The half
% statistics say RedHalf (hard line), the zone map says OppMiddle, and the
% coordinator keeps Defend because 0.10 < v1MidlineBand: three answers,
% each by design. inSwitchBand marks these rows so they can be reported.
P = t.TestData.P;
verifyEqual(t, tdp.spatialZone(0.10, 0, 1, P), 5);
verifyLessThan(t, 0.10, P.v1MidlineBand);
[~, ~, band] = tdp.ballHalf(0.10, 0, false, P);
verifyTrue(t, band);
end

function testHalfTraceReportsSwitchBand(t)
P = t.TestData.P;
c = replayColumns();
tr = zeros(4, 98);
tr(:, c.ballX) = [-1; -0.1; 0.1; 1];
tr(:, c.time) = 1; tr(:, c.pauseUntil) = 0;
out = ballHalfTrace(tr, P);
verifyEqual(t, out.seconds(2:3), [2 2]*P.dt, 'AbsTol', 1e-12);
verifyEqual(t, out.switchBandSeconds, 2*P.dt, 'AbsTol', 1e-12);
verifyEqual(t, out.crossings, 1);
end

%% ---------- DF block point (6.3) ----------
function testGoalSideBlockMatchesV1WhenBallIsFar(t)
P = t.TestData.P;
for ball = [0 0; -1 2; -2 -2.5; 3 1]'
    [b, o] = tdp.goalSideBlock(ball', 1, P.defDist, P);
    verifyEqual(t, b, o, 'AbsTol', 1e-12);
    verifyEqual(t, o, oldFormula(ball', 1, P), 'AbsTol', 1e-12);
end
end

function testGoalSideBlockStaysBetweenBallAndGoal(t)
P = t.TestData.P;
ball = [-3.5 0.5];                      % 1.12 m from the blue goal centre
[b, o] = tdp.goalSideBlock(ball, 1, P.defDist, P);
g = [-4.5 0];
verifyGreaterThan(t, norm(o - g), norm(ball - g), 'V1 point is in front of the ball');
verifyLessThan(t, norm(b - g), norm(ball - g));
verifyGreaterThan(t, norm(ball - b), P.robotR + P.ballR);   % no overlap with the ball
% red is the mirror
[br, or] = tdp.goalSideBlock(-ball, 2, P.defDist, P);
verifyEqual(t, br, -b, 'AbsTol', 1e-12);
verifyEqual(t, or, -o, 'AbsTol', 1e-12);
end

%% ---------- default stations (section 5) ----------
function testDefaultStationsZones(t)
P = t.TestData.P;
[T, D] = spatialStationTable(P);
v1 = T(strcmp(T.Profile, 'V1 repo'), :);
verifyEqual(t, v1.ZonesAllBallY(1), {'OwnGoalArea'});       % GK always in goal area
verifyEqual(t, v1.ZoneBallAhead(2), {'OwnPenaltyArea'});   % DF 1.8 m: inside the box
verifyEqual(t, v1.ZoneBallAhead(3), {'OwnMiddle'});        % MF screen -1.4
verifyLessThan(t, v1.MarginToLine(3), 0.20);               % ...only 0.10 m from -1.5
verifyEqual(t, v1.ZoneBallAhead(4), {'OwnMiddle'});        % ST counter -0.4
verifyGreaterThan(t, D(1).oldAhead, 0);                    % V1 anomaly exists
verifyEqual(t, [D.newAhead], zeros(1, numel(D)));          % fix removes it
end

function testMovingMidfielderStations(t)
% handoff 5: MF cover (V1.2) and MF attack are swept over every position
P = t.TestData.P;
[~, ~, M] = spatialStationTable(P);
cover = M(strcmp(M.Role, 'MF cover'), :);
verifyEqual(t, cover.Profile', {'Neutral','Defensive'});
verifyEqual(t, cover.ShareGoalSideOrOwnHalf', [1 1]);      % always between ball and goal
verifyEqual(t, cover.StationF', [-4.5+1.8, -4.5+1.5], 'AbsTol', 1e-12);
verifyEqual(t, cover.ZoneExample', {'OwnPenaltyArea','OwnPenaltyArea'});
attack = M(strcmp(M.Role, 'MF attack'), :);
verifyEqual(t, attack.StationF, 2.0 - P.v1SupportTrail, 'AbsTol', 1e-12);
verifyGreaterThan(t, attack.ShareGoalSideOrOwnHalf, 0);    % ST near midline -> MF in own half
end

function o = oldFormula(ball, team, P)
% verbatim copy of v1TeamPlans.m lines 84-93
direction = P.dirSign(team);
defenderX = direction*(-P.L/2 + P.defDist);
ownGoal = [-direction*P.L/2 0];
threat = ball - ownGoal;
distance = hypot(threat(1), threat(2));
if distance > 1e-9
    block = ownGoal + P.defDist*threat/distance;
else
    block = [defenderX 0];
end
block(1) = direction*min(max(direction*block(1), -P.L/2 + P.robotR), -P.robotR);
o = [min(max(block(1), -P.L/2 + P.robotR), P.L/2 - P.robotR), ...
     min(max(block(2), -P.W/2 + P.robotR), P.W/2 - P.robotR)];
end
