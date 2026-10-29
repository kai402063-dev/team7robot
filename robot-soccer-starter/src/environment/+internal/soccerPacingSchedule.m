function [state,deadline,resetReason] = soccerPacingSchedule(state,simTime,wallTime,rate,epoch)
%SOCCERPACINGSCHEDULE Pure soft-deadline calculation, independent of MATLAB UI.
% Late work is rebased instead of accumulating catch-up debt. The tolerance
% bounds catch-up to 50 ms; this is not a hard real-time scheduler.
maxLag = 0.05;
resetReason = '';
if isempty(state)
    resetReason = 'initial';
elseif epoch ~= state.Epoch || rate ~= state.Rate
    resetReason = 'configuration';
elseif simTime < state.LastSimTime || wallTime < state.LastWallTime
    resetReason = 'restart';
else
    deadline = state.AnchorWall + (simTime-state.AnchorSim)/rate;
    if wallTime-deadline > maxLag
        resetReason = 'late_or_resumed';
    end
end
if ~isempty(resetReason)
    state = struct('AnchorSim',simTime,'AnchorWall',wallTime, ...
        'Rate',rate,'Epoch',epoch,'LastSimTime',simTime,'LastWallTime',wallTime);
    deadline = wallTime;
else
    state.LastSimTime = simTime;
    state.LastWallTime = wallTime;
end
end
