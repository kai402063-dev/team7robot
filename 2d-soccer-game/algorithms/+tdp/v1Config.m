function P = v1Config()
%V1CONFIG Team 7 V1 decisions for the idealized four-a-side experiment.
P = tdp.defaultConfig();
P.v1Enabled = true;
P.mode = TdpMode.Delayed;
P.rulesProfile = TdpRules.CourseSimplified;
P.freezeDuringPause = true;

% Explicit teaching assumptions in metres, except loose-ball speed (m/s).
P.v1MidlineBand = 0.15;
P.v1SupportTrail = 0.70;
P.v1SupportWidth = 0.80;
P.v1LooseRange = 1.20;
P.v1LooseSpeed = 0.35;
P.v1OpponentClearance = 0.60;
P.v1KeeperInset = 0.35;
P.v1ScreenDepth = 1.40;
P.v1CounterDepth = 0.40;

% Test-only fault schedules in simulation seconds. Each row is [start,end).
P.v1UnavailableWindow = zeros(8,2);
P.v1BlindWindow = zeros(8,2);
P.v1StaleWindow = zeros(8,2);
P.v1StopWindow = zeros(1,2);
P.v1RecoveryWindow = zeros(2,2);
P.v1FailWindow = zeros(8,2);
end
