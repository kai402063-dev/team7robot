function tests = test_pitch_ball
%TEST_PITCH_BALL (Y1 + Y4) Executable check of the existing 2D pitch, ball,
% referee thresholds and robot/ball interaction. Nothing here changes the
% model; each test pins down how the current code behaves so that the
% check record in docs/chapters/yu_pitch_zones_halves.md stays true.
% Run: tdpSetup; runtests('tests/test_pitch_ball.m')
tests = functiontests(localfunctions);
end

%% ---------- Y1: pitch and coordinate system ----------
function testPitchDimensionsMatchCourseTable(t)
P = tdp.v1Config();
verifyEqual(t, [P.L P.W], [9 6]);
verifyEqual(t, [P.goalD P.goalW], [0.6 2.6]);
verifyEqual(t, [P.goalAreaL P.goalAreaW], [1 3]);
verifyEqual(t, [P.penAreaL P.penAreaW], [2 5]);
verifyEqual(t, [P.penMark P.centreD P.border], [1.5 1.5 1]);
verifyEqual(t, P.ballR, 0.07);
verifyEqual(t, P.dirSign, [1 -1]);   % blue attacks +x, red attacks -x
verifyEqual(t, P.rulesProfile, TdpRules.CourseSimplified);
end

function testKickoffOwnHalvesFacingAndMirror(t)
P = tdp.v1Config();
[r, b] = tdp.initialState(P);
verifyEqual(t, [b.x b.y b.vx b.vy], [0 0 0 0]);
blue = r([r.team] == 1);  red = r([r.team] == 2);
verifyTrue(t, all([blue.x] < 0), 'every blue robot starts in its own half (x<0)');
verifyTrue(t, all([red.x] > 0),  'every red robot starts in its own half (x>0)');
verifyEqual(t, [blue.th], zeros(1,4));             % blue faces +x
verifyEqual(t, [red.th], pi*ones(1,4));            % red faces -x
verifyEqual(t, [red.x], -[blue.x]);                % point mirror through (0,0)
verifyEqual(t, [red.y], -[blue.y]);
centreR = P.centreD/2;
for k = 1:8   % nobody inside the centre circle at kick-off
    verifyGreaterThan(t, hypot(r(k).x, r(k).y), centreR - 1e-12);
end
end

%% ---------- Y1: ball rolling and outer border ----------
function testBallRollingStepAndStoppingDistance(t)
P = tdp.v1Config();
b = struct('x',0,'y',0,'vx',1,'vy',0);
b = tdp.ballModel(b, P);                           % numbers quoted in the parameter docx
verifyEqual(t, b.vx, 0.98, 'AbsTol', 1e-12);
verifyEqual(t, b.x, 0.049, 'AbsTol', 1e-12);
for v0 = [P.shotSpeed P.dribbleSpeed]
    b = struct('x',0,'y',0,'vx',v0,'vy',0);
    for k = 1:1000, b = tdp.ballModel(b, P); end
    expected = P.dt*sum(max(0, v0 - (1:1000)*P.ballDecel*P.dt));
    verifyEqual(t, b.x, expected, 'AbsTol', 1e-9);
    verifyEqual(t, b.vx, 0);
    % discrete distance stays within one step of v^2/(2a)
    verifyLessThan(t, abs(b.x - v0^2/(2*P.ballDecel)), v0*P.dt);
end
end

function testOuterBorderBounce(t)
P = tdp.v1Config();
b = struct('x',5.40,'y',0,'vx',1,'vy',0);
b = tdp.ballModel(b, P);
verifyEqual(t, b.x, P.L/2 + P.border - P.ballR, 'AbsTol', 1e-12);   % 5.43
verifyEqual(t, b.vx, -P.ballRestit*0.98, 'AbsTol', 1e-12);
end

function testBorderBounceUnreachableInPlay(t)
% The referee stops play at |x| > 4.57 / |y| > 3.07. With the fastest kick
% the ball moves at most maxKickSpeed*dt per step, so it is always caught
% before it reaches the bouncing wall at 5.43 / 3.93.
P = tdp.v1Config();
step = P.maxKickSpeed*P.dt;
verifyLessThan(t, P.L/2 + P.ballR + step, P.L/2 + P.border - P.ballR);
verifyLessThan(t, P.W/2 + P.ballR + step, P.W/2 + P.border - P.ballR);
end

%% ---------- Y1: referee thresholds (CourseSimplified, default V1) ----------
function testGoalLineAndPosts(t)
P = tdp.v1Config();
cases = [ ...   % x      y      expected blue/red score after one check
    4.571   0       1 0;    % whole ball over the line, centre -> blue goal
    4.569   0       0 0;    % ball still touching the line -> play on
    4.6     1.229   1 0;    % |y| + ballR = 1.299 < 1.30 -> goal
   -4.6     0       0 1;    % red scores at the -x end
   -4.6    -1.229   0 1];
for k = 1:size(cases,1)
    [r, b, s] = fresh(P);
    b.x = cases(k,1); b.y = cases(k,2); s.lastTouch = 1;
    [~, b2, s2] = Referee2D(r, b, s, P);
    verifyEqual(t, s2.score, cases(k,3:4), sprintf('case %d', k));
    if any(cases(k,3:4))
        verifyEqual(t, [b2.x b2.y], [0 0]);                  % kick-off reset
        verifyEqual(t, s2.pauseUntil, s.t + P.restartPause);
    end
end
end

function testBesideThePostIsNotAGoal(t)
% |y| = 1.231 -> |y| + ballR = 1.301: the ball overlaps the post line, so the
% 2D referee calls it out (in Webots it would hit the post).
P = tdp.v1Config();
[r, b, s] = fresh(P);
b.x = 4.6; b.y = 1.231; s.lastTouch = 1;
[~, b2, s2] = Referee2D(r, b, s, P);
verifyEqual(t, s2.score, [0 0]);
verifyEqual(t, s2.msg, TdpEvent.GoalKick);
verifyEqual(t, [b2.x b2.y], [P.L/2 - P.goalAreaL, P.goalAreaW/2]);   % (3.5, 1.5)
end

function testGoalKickCornerKickIn(t)
P = tdp.v1Config();
% attacker (blue) put it over the +x goal line -> goal kick
[r, b, s] = fresh(P); b.x = 4.6; b.y = -2; s.lastTouch = 1;
[~, b2, s2] = Referee2D(r, b, s, P);
verifyEqual(t, s2.msg, TdpEvent.GoalKick);
verifyEqual(t, [b2.x b2.y], [3.5 -1.5], 'AbsTol', 1e-12);
% defender (red) put it over its own goal line -> corner
[r, b, s] = fresh(P); b.x = 4.6; b.y = 2; s.lastTouch = 2;
[~, b2, s2] = Referee2D(r, b, s, P);
verifyEqual(t, s2.msg, TdpEvent.Corner);
verifyEqual(t, [b2.x b2.y], [4.25 2.75], 'AbsTol', 1e-12);
% touchline
[r, b, s] = fresh(P); b.x = 4.4; b.y = 3.071; s.lastTouch = 2;
[~, b2, s2] = Referee2D(r, b, s, P);
verifyEqual(t, s2.msg, TdpEvent.KickIn);
verifyEqual(t, [b2.x b2.y], [4.25 2.75], 'AbsTol', 1e-12);
verifyEqual(t, [b2.vx b2.vy], [0 0]);
verifyEqual(t, s2.pauseUntil, s.t + P.outPause);
% ball only partly over the touchline -> still in play
[r, b, s] = fresh(P); b.x = 1; b.y = 3.06;
[~, b2, s2] = Referee2D(r, b, s, P);
verifyEqual(t, [b2.x b2.y], [1 3.06]);
verifyEqual(t, s2.pauseUntil, s.pauseUntil);
end

function testACompatPostRuleDiffers(t)
% The legacy profile counts |y| < 1.30 as inside the posts. Statistics must
% use the same profile as the referee (tdp.ballHalf does).
P = tdp.defaultConfig();
verifyEqual(t, P.rulesProfile, TdpRules.ACompat);
[r, b, s] = fresh(P); b.x = 4.6; b.y = 1.25;
[~, ~, s2] = Referee2D(r, b, s, P);
verifyEqual(t, s2.score, [1 0]);
end

%% ---------- Y4: robots, borders and robot-ball interaction ----------
function testRobotClampedToOuterBorder(t)
P = tdp.v1Config();
[r, ~, ~] = fresh(P);
r(1).x = 5.349; r(1).y = 3.849; r(1).th = pi/4;   % one step would carry it past 5.35 / 3.85
cmds = zeros(8,3); cmds(1,:) = [P.vFwd 0 0];
r2 = tdp.robotModel(r, cmds, P);
verifyEqual(t, r2(1).x, P.L/2 + P.border - P.robotR, 'AbsTol', 1e-12);   % 5.35
verifyEqual(t, r2(1).y, P.W/2 + P.border - P.robotR, 'AbsTol', 1e-12);   % 3.85
end

function testRobotCanStandInsideGoal(t)
% Known simplification: no posts or net in 2D, robots are only stopped by
% the outer border (5.35 m). A robot may stand behind the goal line.
P = tdp.v1Config();
[r, ~, ~] = fresh(P);
r(1).x = 4.80; r(1).y = 0; r(1).th = 0;
cmds = zeros(8,3); cmds(1,:) = [P.vFwd 0 0];
r2 = tdp.robotModel(r, cmds, P);
verifyGreaterThan(t, r2(1).x, P.L/2);
verifyLessThan(t, r2(1).x, P.L/2 + P.goalD);
end

function testWalkingRobotPushesBall(t)
P = tdp.v1Config();
[r, b, s] = fresh(P);
r(4).x = 0; r(4).y = 0; r(4).th = 0; r(4).vxw = 0.25; r(4).vyw = 0;
b.x = 0.10; b.y = 0; b.vx = 0; b.vy = 0;
[~, b2, s2] = Contact2D(r, b, s, true, true(1,8), P);
verifyEqual(t, b2.x, P.robotR + P.ballR, 'AbsTol', 1e-12);       % pushed to 0.22 m
verifyEqual(t, b2.vx, (1 + P.ballRobotE)*0.25, 'AbsTol', 1e-12);  % 0.325 m/s
verifyEqual(t, s2.lastTouch, 1);
% while play is paused (ballActive = false) the ball is not touched
[~, b3, s3] = Contact2D(r, b, s, false, true(1,8), P);
verifyEqual(t, [b3.x b3.vx], [b.x b.vx]);
verifyEqual(t, s3.lastTouch, s.lastTouch);
end

function testRobotsSeparateWithoutOverlap(t)
P = tdp.v1Config();
[r, b, s] = fresh(P);
r(4).x = 0;    r(4).y = 0;
r(8).x = 0.1;  r(8).y = 0.05;            % red striker almost on top of blue striker
[r2, ~, ~] = Contact2D(r, b, s, false, true(1,8), P);
verifyGreaterThan(t, hypot(r2(8).x - r2(4).x, r2(8).y - r2(4).y), 2*P.robotR - 1e-8);
end

%% ---------- helpers ----------
function [r, b, s] = fresh(P)
[r, b, s] = tdp.initialState(P);
s.t = 10; s.pauseUntil = 0;
end
