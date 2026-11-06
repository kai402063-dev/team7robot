function P = defaultConfig()
%SIMPARAMS  All simulation parameters in one place.
%   Pitch dimensions follow Table 1 of the ENG5325 project specification.
%   Coordinates: origin at the centre spot, x along the pitch length,
%   y across it. Blue (team 1) attacks +x, red (team 2) attacks -x.

% ---- Pitch (Table 1, metres) ----
P.L         = 9;     % A  pitch length
P.W         = 6;     % B  pitch width
P.goalD     = 0.6;   % C  goal depth
P.goalW     = 2.6;   % D  goal width
P.goalAreaL = 1;     % E  goal area length
P.goalAreaW = 3;     % F  goal area width
P.penMark   = 1.5;   % G  penalty mark distance
P.centreD   = 1.5;   % H  centre circle diameter
P.border    = 1;     % I  border strip width
P.penAreaL  = 2;     % J  penalty area length
P.penAreaW  = 5;     % K  penalty area width

% ---- Ball (WP B) ----
P.ballR       = 0.07;  % 14 cm diameter (FIFA size 1)
P.ballDecel   = 0.4;   % rolling-friction deceleration, m/s^2 (tune)
P.ballRestit  = 0.5;   % bounce off the outer border
P.ballRobotE  = 0.3;   % restitution when a robot walks into the ball

% ---- Robot (WP A) -- NAO6-like omnidirectional walk ----
% Older NAOqi docs give ~0.1 m/s default walking speed; a tuned walk is
% faster. Raise these if matches feel too slow, then validate.
P.robotR = 0.15;          % footprint radius
P.vFwd   = 0.25;          % max forward speed, m/s
P.vBack  = 0.12;          % max backward speed, m/s
P.vSide  = 0.15;          % max sideways speed, m/s
P.wMax   = deg2rad(45);   % max turn rate, rad/s

% ---- Control & navigation (WP C) ----
P.Kp          = 0.8;          % position gain
P.Kw          = 2.0;          % heading gain
P.avoidR      = 0.7;          % robot-robot avoidance radius
P.avoidGain   = 0.6;
P.ballAvoidR  = 0.35;         % keep clear of the ball while circling it
P.approachDist = 0.45;        % stand-off point behind the ball
P.kickRange   = P.robotR + P.ballR + 0.06;
P.stepInSpeed = 0.10;         % min speed for the final step onto the ball
P.kickAlign   = deg2rad(20);  % heading tolerance for a kick
P.behindTol   = deg2rad(30);  % how "behind the ball" the robot must be
P.kickNoise   = deg2rad(6);   % kick direction error (std dev)
P.kickCooldown = 1.0;         % s between kicks by one robot
P.shotSpeed   = 1.8;          % m/s
P.dribbleSpeed = 0.6;         % small kick used to dribble
P.maxKickSpeed = 2.2;

% ---- Behaviour (WP D) ----
P.roleHyst  = 0.4;   % striker keeps its role unless another is this much better
P.shootDist = 3.0;   % shoot when ball is this close to the opponent goal
P.defDist   = 1.8;   % defender distance from own goal centre

% ---- Simulation / integration (WP E) ----
P.nPerTeam     = 4;
P.dt           = 0.05;   % s
P.Tmatch       = 600;    % s of match time
P.restartPause = 2.0;    % s pause after a goal
P.outPause     = 1.0;    % s pause after the ball goes out
P.drawEvery    = 4;      % redraw every N steps (higher = faster run)
P.realtime     = false;  % true = slow the animation down to real time
P.dirSign      = [1 -1]; % attacking direction of team 1 and team 2
P.seed         = 1;      % random seed for kick noise (repeatable runs)
P.mode = TdpMode.Compat;
P.rulesProfile = TdpRules.ACompat;
P.maxObservationAge = 0.5;
P.walkValidity = 0.10;
P.kickPreparation = 0.20;
P.kickTimeout = 1.0;
P.recoverTime = 0.5;
P.alignEnter = 0.35;
P.alignExit = 0.45;
P.searchTurnRate = 0.30;
P.fieldOfView = 2*pi;
P.observationDelay = 0;
P.observationNoise = 0;
P.fixedStriker = false;
P.tapSpeed = 0.30;
P.freezeDuringPause = false;
P.contactIterations = 256;
P.restartOpponentDistance = 0.75;
P.contactTolerance = 1e-10;
end
