function soccerRuntimeWait(model)
%SOCCERRUNTIMEWAIT Optional pacing for the explicitly configured soccer copy.
% No pause(), spinning, simulation commands, RNG calls, or saved model changes.
persistent clockToken schedule configEpoch lastPump stats
key = 'SoccerRuntimePacingConfig';
if ~isappdata(groot,key),return;end
cfg = getappdata(groot,key);
if ~cfg.Enabled || ~strcmp(model,cfg.ModelName) || ~bdIsLoaded(model),return;end
if ~strcmp(get_param(model,'FileName'),cfg.ModelFile),return;end
if strcmp(get_param(model,'EnablePacing'),'on')
    error('SoccerRuntimePacing:DoublePacing', ...
        'Disable built-in Simulation Pacing before using soccerRuntimePacing.');
end
if isempty(clockToken) || isempty(configEpoch) || configEpoch ~= cfg.Epoch
    clockToken = tic;
    schedule = [];
    configEpoch = cfg.Epoch;
    lastPump = 0;
    stats = struct('Calls',0,'WaitSeconds',0,'Reanchors',0, ...
        'LastResetReason','','LastSimTime',0,'WallSeconds',0);
end
simTime = get_param(model,'SimulationTime');
wallTime = toc(clockToken);
[schedule,deadline,reason] = internal.soccerPacingSchedule( ...
    schedule,simTime,wallTime,cfg.Rate,cfg.Epoch);
if ~isempty(reason)
    stats.Reanchors = stats.Reanchors + 1;
    stats.LastResetReason = reason;
end
waitStart = wallTime;
while deadline > toc(clockToken)
    % Short blocking sleeps release the CPU. Existing visualization drawnow
    % handles normal GUI work; the extra pump bounds long-wait responsiveness.
    remaining = deadline-toc(clockToken);
    if remaining <= 0,break;end
    java.lang.Thread.sleep(int64(max(1,min(10,ceil(remaining*1000)))));
    wallTime = toc(clockToken);
    if wallTime-lastPump >= 0.05
        drawnow('limitrate');
        lastPump = toc(clockToken);
        if ~isappdata(groot,key),return;end
        current = getappdata(groot,key);
        if ~current.Enabled || current.Epoch ~= cfg.Epoch
            schedule = [];
            return;
        end
        if ~bdIsLoaded(model) || ~strcmp(get_param(model,'SimulationStatus'),'running')
            schedule = [];
            return;
        end
        % A pause or callback can keep drawnow busy for an arbitrary time.
        if toc(clockToken)-deadline > 0.05
            schedule = [];
            break;
        end
    end
end
stats.Calls = stats.Calls + 1;
stats.WaitSeconds = stats.WaitSeconds + max(0,toc(clockToken)-waitStart);
stats.LastSimTime = simTime;
stats.WallSeconds = toc(clockToken);
setappdata(groot,'SoccerRuntimePacingStats',stats);
end
