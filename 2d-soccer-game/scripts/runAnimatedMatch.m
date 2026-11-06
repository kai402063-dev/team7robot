function [trace,tactics,recovery]=runAnimatedMatch(P,viewer)
%RUNANIMATEDMATCH Observe normal-mode simulation without changing its timebase.
% Wall-clock pacing belongs to the simulator UI, never to the controller.
previousRng=rng;
restoreRng=onCleanup(@()rng(previousRng)); %#ok<NASGU>
rng(P.seed,'twister');
[s,model]=matchSimulationInput(P);
viewer.beginRun();
trace=zeros(0,98);
tactics=zeros(0,0);
recovery=zeros(0,0);
if viewer.StopRequested || viewer.Closing
    viewer.finishRun(trace);
    return;
end
s=s.setModelParameter('SimulationMode','normal');
speed=viewer.Speed;s=configureSpeed(s,speed);
sm=simulation(s);
simulationCleanup=onCleanup(@()cleanupSimulation(sm,viewer)); %#ok<NASGU>
initialize(sm);
% The atomic MATLAB Function owns a real output port. The optimized-away
% To Workspace sink does not, so the listener observes Record directly.
listener=add_exec_event_listener([model '/Record'],'PostOutputs', ...
    @(block,~)viewer.showFrame(block.OutputPort(1).Data));
listenerCleanup=onCleanup(@()delete(listener)); %#ok<NASGU>
viewer.ready();start(sm);
lastProgress=tic;lastTime=-Inf;
while ~strcmp(sm.Status,'inactive')
    drawnow;
    if viewer.StopRequested || viewer.Closing
        if ~strcmp(sm.Status,'inactive'),stop(sm);end
        break
    end
    viewer.checkPauseTimeout(15);
    if strcmp(sm.Status,'running') && viewer.PauseRequested
        pause(sm);
    end
    if viewer.Speed~=speed && ~strcmp(sm.Status,'inactive')
        sm=configureSpeed(sm,viewer.Speed);speed=viewer.Speed;
    end
    if strcmp(sm.Status,'paused')
        if viewer.PauseRequested
            viewer.confirmPauseState(true);
        else
            resume(sm);
        end
    end
    if strcmp(sm.Status,'running') && ~viewer.PauseRequested
        viewer.confirmPauseState(false);
    end
    if viewer.Paused || viewer.LastRow(61)~=lastTime
        lastProgress=tic;lastTime=viewer.LastRow(61);
    elseif toc(lastProgress)>30
        error('TDP:AnimationStalled','Simulation produced no new frame for 30 seconds.');
    end
    pause(.04);
end
out=sm.SimulationOutput;
if ~isempty(out.ErrorMessage),error('TDP:AnimationSimulation','%s',out.ErrorMessage);end
if ismember('records',out.who),trace=recordRows(out.records);end
if ~strcmp(model,'tdpMatch') && ismember('tacticsRecords',out.who)
    tactics=recordRows(out.tacticsRecords);
end
if ismember('recoveryRecords',out.who)
    recovery=recordRows(out.recoveryRecords);
end
viewer.finishRun(trace);
end

function cleanupSimulation(sm,viewer)
if ~strcmp(sm.Status,'inactive'),stop(sm);end
if viewer.Running,viewer.finishRun(zeros(0,98));end
end

function s=configureSpeed(s,speed)
if isinf(speed)
    s=setModelParameter(s,'EnablePacing','off');
else
    s=setModelParameter(s,'EnablePacing','on','PacingRate',num2str(speed,17));
end
end
