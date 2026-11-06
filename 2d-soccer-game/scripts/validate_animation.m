function receipt=validate_animation(outDir,visible)
%VALIDATE_ANIMATION Verify live trajectories, controls and optional real pixels.
if nargin<2,visible='off';end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory.');mkdir(outDir);
receipt=struct('status','RUNNING');writeJson(fullfile(outDir,'receipt.json'),receipt);
started=tic;
try
 r=runtests('tests/test_animation.m');
 receipt.tests=struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]);
 assertSuccess(r);
 P=tdp.v1Config();P.Tmatch=8;
 v=LiveViewer2D(P,visible,1);guard=onCleanup(@()dispose(v)); %#ok<NASGU>
 phase=0;pauseWall=[];framesBefore=[];framesAfter=[];samples=struct();
 pausedRow=[];frozenRow=[];
 controlTimer=timer('ExecutionMode','fixedSpacing','Period',.05,'BusyMode','drop', ...
     'TimerFcn',@interact);
 timerGuard=onCleanup(@()disposeTimer(controlTimer)); %#ok<NASGU>
 start(controlTimer);trace=runAnimatedMatch(P,v);stop(controlTimer);
 receipt.controls=struct('samples',samples,'events',v.Events,'partialFrames',size(trace,1));
 assert(phase==4,'TDP:AnimationControls','Control sequence did not finish.');
 pausedTime=samples.confirmed.recordTime;frozenTime=samples.held.recordTime;
 assert(frozenTime==pausedTime,'TDP:AnimationPause','Simulation advanced while paused.');
 assert(strcmp(samples.confirmed.engineStatus,'paused') && strcmp(samples.held.engineStatus,'paused'), ...
     'TDP:AnimationPause','Solver did not stay paused.');
 assert(samples.held.engineTime==samples.confirmed.engineTime && samples.held.frame==samples.confirmed.frame ...
     && isequal(frozenRow,pausedRow) && strcmp(samples.held.clockText,samples.confirmed.clockText), ...
     'TDP:AnimationPause','Solver time, frame number, frame data or displayed clock changed during pause.');
 assert(isequal(trace(samples.confirmed.frame,:),pausedRow),'TDP:AnimationPause','Frozen frame differs from the logged record.');
 assert(v.StopRequested && size(trace,1)<round(P.Tmatch/P.dt),'TDP:AnimationStop','Stop failed.');
 assert(all(diff(trace(:,61))>0),'TDP:AnimationTime','Duplicate or reversed simulation time.');
 assert(max(trace(:,57))-min(trace(:,57))>.01,'TDP:AnimationBallMotion','No ball movement was observed.');
 assert(numel(unique({v.Events.event}))>=5,'TDP:AnimationEvents','Missing control events.');
 expected=runMatch(P);assert(isequal(trace,expected(1:size(trace,1),:)),'TDP:AnimationParity','Controls changed trajectory.');
 receipt.controls.pausedTime=pausedTime;receipt.controls.frozenTime=frozenTime;
 receipt.controls.heldRowMatchesTrace=true;receipt.controls.sameAsUnpacedPrefix=true;
 if strcmp(visible,'on')
  assert(~isempty(framesBefore) && ~isempty(framesAfter),'TDP:AnimationCapture','Missing real window frames.');
  assert(~isequal(framesBefore,framesAfter),'TDP:AnimationPixels','Frames did not change.');
  imwrite(framesBefore,fullfile(outDir,'live-before.png'));imwrite(framesAfter,fullfile(outDir,'live-after.png'));
  receipt.pixels=struct('visible',true,'changed',true,'size',size(framesBefore));
 end
 % Restart uses the same seed and creates a separate receipt for each run.
 v.setSpeed(Inf);v.start();assert(isempty(v.LastError));first=v.Trace;firstDir=v.RunDirectory;
 cb=get(v.StartButton,'Callback');cb(v.StartButton,[]);assert(isempty(v.LastError));
 assert(isequal(first,v.Trace) && ~strcmp(firstDir,v.RunDirectory),'TDP:AnimationRestart','Restart is not deterministic or overwrote a run.');
 receipt.restart=struct('frames',size(v.Trace,1),'sameTrace',true,'separateReceipts',true);
 v.setSpeed(1);set(controlTimer,'TimerFcn',@closeWhenReady);start(controlTimer);v.start();stop(controlTimer);
 assert(isempty(v.LastError) && v.StopRequested && v.Closing && ~isgraphics(v.Figure), ...
     'TDP:AnimationClose','Closing the running window did not stop and clean up.');
 assert(size(v.Trace,1)<size(expected,1) && isequal(v.Trace,expected(1:size(v.Trace,1),:)), ...
     'TDP:AnimationCloseTrace','Close did not preserve a valid partial trace.');
 receipt.closedDuringRun=true;
 receipt.status='PASS';
catch e
 if exist('samples','var') && exist('v','var')
     receipt.observedSamples=samples;receipt.events=v.Events;
 end
 receipt.status='FAIL';receipt.error=getReport(e,'extended','hyperlinks','off');
 receipt.elapsedSeconds=toc(started);writeJson(fullfile(outDir,'receipt.json'),receipt);rethrow(e);
end
receipt.elapsedSeconds=toc(started);writeJson(fullfile(outDir,'receipt.json'),receipt);

    function interact(~,~)
        if ~v.Running,return;end
        if phase==0 && v.FrameCount>=6
            if strcmp(visible,'on'),frame=getframe(v.Figure);framesBefore=frame.cdata;end
            cb=get(v.PauseButton,'Callback');cb(v.PauseButton,[]);
            samples.requested=sampleControl();phase=1;
        elseif phase==1 && v.Paused
            pausedRow=v.LastRow;samples.confirmed=sampleControl();pauseWall=tic;phase=2;
        elseif phase==2 && toc(pauseWall)>.4
            frozenRow=v.LastRow;samples.held=sampleControl();samples.held.wallSecondsSinceConfirmation=toc(pauseWall);
            set(v.SpeedControl,'Value',4);cb=get(v.SpeedControl,'Callback');cb(v.SpeedControl,[]);
            cb=get(v.PauseButton,'Callback');cb(v.PauseButton,[]);phase=3;
        elseif phase==3 && ~v.Paused && ~v.PauseRequested && v.FrameCount>=95
            if strcmp(visible,'on'),v.refreshDisplay();drawnow;frame=getframe(v.Figure);framesAfter=frame.cdata;end
            samples.resumed=sampleControl();
            cb=get(v.StopButton,'Callback');cb(v.StopButton,[]);phase=4;
        end
    end
    function sample=sampleControl()
        sample=struct('requested',v.PauseRequested,'confirmedPaused',v.Paused,'frame',v.FrameCount, ...
            'recordTime',v.LastRow(61),'clockText',get(v.ClockText,'String'),'engineStatus', ...
            get_param('tdpV1Match','SimulationStatus'),'engineTime',get_param('tdpV1Match','SimulationTime'));
    end
    function closeWhenReady(~,~)
        if v.Running && v.FrameCount>=6,v.close();end
    end
end
function dispose(v)
if isvalid(v) && isgraphics(v.Figure),delete(v.Figure);end
end
function disposeTimer(t)
if isvalid(t),stop(t);delete(t);end
end
