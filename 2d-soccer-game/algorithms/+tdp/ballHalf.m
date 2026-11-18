function [code, nearGoal, inSwitchBand] = ballHalf(x, y, paused, P)
%BALLHALF (Y3) Classify ball positions for half-time statistics.
%   [code, nearGoal, inSwitchBand] = tdp.ballHalf(x, y, paused, P)
%   x, y, paused may be scalars or arrays of the same size (ball centre in
%   metres, world frame). paused is true while the game is stopped
%   (t < pauseUntil). Codes come from tdp.halfCodes():
%
%     Stoppage  game paused (after a goal or an out); not counted to a half
%     Goal      whole ball over a goal line AND inside the posts
%     OutOfPlay whole ball over a goal line outside the posts, or over a
%               touchline
%     Midline   |x| <= band (band = 0 by default: only x exactly 0)
%     BlueHalf  x < -band (blue defends -x, see defaultConfig)
%     RedHalf   x > +band
%     Unknown   x or y is NaN/Inf
%
%   Rules are checked in the order listed. They use the SAME thresholds as
%   the referee (environment/Referee2D.m) so that statistics and scoring
%   never disagree:
%     whole ball over goal line : |x| > L/2 + ballR
%     inside the posts          : CourseSimplified |y| + ballR < goalW/2
%                                 ACompat          |y|         < goalW/2
%     whole ball over touchline : |y| > W/2 + ballR
%   A ball only partly over a line is still in play (football rule).
%
%   Half rule (F4 handoff 6.1, proposed by Yu, to confirm with Qin):
%   statistics use the HARD line x = 0 on the ball centre. The +-0.15 m
%   band (P.v1MidlineBand) is control hysteresis for the coordinator's
%   Attack/Defend switch, not a pitch marking, so it does not split time.
%   inSwitchBand (in play and |x| <= P.v1MidlineBand) reports it as a
%   separate diagnostic. band = P.y3MidlineBand if that field exists.
%
%   nearGoal: -1 ball (in play) inside the penalty area in front of the
%   BLUE goal (x < 0), +1 in front of the RED goal, 0 otherwise.

C = tdp.halfCodes();
band = 0;
if isfield(P,'y3MidlineBand'), band = P.y3MidlineBand; end
if isscalar(paused) && ~isscalar(x), paused = repmat(paused, size(x)); end

overGoalLine  = abs(x) > P.L/2 + P.ballR;
overTouchline = abs(y) > P.W/2 + P.ballR;
if isfield(P,'rulesProfile') && P.rulesProfile == TdpRules.ACompat
    insidePosts = abs(y) < P.goalW/2;
else
    insidePosts = abs(y) + P.ballR < P.goalW/2;
end

code = zeros(size(x));
code(:) = C.RedHalf;
code(x < -band) = C.BlueHalf;
code(abs(x) <= band) = C.Midline;
code(overTouchline) = C.OutOfPlay;
code(overGoalLine) = C.OutOfPlay;           % goal line is checked first, as in Referee2D
code(overGoalLine & insidePosts) = C.Goal;
code(logical(paused)) = C.Stoppage;
code(~isfinite(x) | ~isfinite(y)) = C.Unknown;

inPlay = code == C.BlueHalf | code == C.RedHalf | code == C.Midline;
inPenArea = abs(x) >= P.L/2 - P.penAreaL & abs(y) <= P.penAreaW/2;
nearGoal = zeros(size(x));
nearGoal(inPlay & inPenArea) = sign(x(inPlay & inPenArea));
switchBand = 0.15;
if isfield(P,'v1MidlineBand'), switchBand = P.v1MidlineBand; end
inSwitchBand = inPlay & abs(x) <= switchBand;
end
