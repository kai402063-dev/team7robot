function out = ballHalfTrace(trace, P)
%BALLHALFTRACE (Y3) Apply tdp.ballHalf to a 98-column physical trace.
%   out = ballHalfTrace(trace, P) classifies every row and applies the
%   time convention agreed for Qin's statistics (Q2):
%
%   * Sample-and-hold: row k stands for the interval [t_k, t_k + dt).
%     Its whole dt is given to the category of row k. A crossing between
%     two samples is therefore located to within one dt (0.05 s).
%   * A row is a stoppage when time < pauseUntil (columns 61 and 65).
%     The referee resets the ball in the same step as a goal or an out, so
%     Goal and OutOfPlay normally do NOT appear in plant traces; count
%     goals from the score columns, not from ball positions.
%   * A half crossing is a change BlueHalf <-> RedHalf, ignoring Midline
%     and Stoppage rows in between (Blue, Mid, Red = 1 crossing).
%
%   Fields of out:
%     code       per-row category (tdp.halfCodes)
%     nearGoal   per-row -1 / 0 / +1 (see tdp.ballHalf)
%     seconds    1x7 time per category, ordered as tdp.halfCodes().names
%     names      the category names
%     crossings  number of half crossings
%     nearGoalSeconds [blueGoal redGoal] time spent in front of each goal

c = replayColumns();
x = trace(:,c.ballX);
y = trace(:,c.ballY);
paused = trace(:,c.time) < trace(:,c.pauseUntil);
[code, nearGoal, inBand] = tdp.ballHalf(x, y, paused, P);

C = tdp.halfCodes();
out.code = code;
out.nearGoal = nearGoal;
out.names = C.names;
out.seconds = zeros(1, numel(C.names));
for k = 1:numel(C.names)
    out.seconds(k) = P.dt * nnz(code == C.(C.names{k}));
end
sides = code(code == C.BlueHalf | code == C.RedHalf);
out.crossings = nnz(diff(sides) ~= 0);
out.nearGoalSeconds = P.dt * [nnz(nearGoal == -1), nnz(nearGoal == 1)];
out.switchBandSeconds = P.dt * nnz(inBand);   % diagnostic, already inside Blue/RedHalf
end
