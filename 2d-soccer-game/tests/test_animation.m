function tests=test_animation
tests=functiontests(localfunctions);
end
function setupOnce(t)
tdpSetup;t.TestData.P=tdp.defaultConfig();
end
function testCoordinatesAndPersistentGraphics(t)
P=t.TestData.P;v=LiveViewer2D(P,'off',Inf);c=onCleanup(@()dispose(v)); %#ok<NASGU>
T=tdpTemplates(P);row=MatchRecord(T.World,0,0);
row(4)=.8;row(12)=-.6;row(20)=pi/2;row(57)=1.25;row(58)=-.8;
row(61)=3.5;row(62)=2;row(63)=1;
count=numel(findall(v.Figure));v.showFrame(row,true);
x=get(v.Bodies(4),'XData');y=get(v.Bodies(4),'YData');
verifyEqual(t,[min(x) max(x) min(y) max(y)],[.8-P.robotR .8+P.robotR -.6-P.robotR -.6+P.robotR],'AbsTol',1e-12);
verifyEqual(t,get(v.Headings(4),'XData'),[.8 .8],'AbsTol',1e-12);
verifyEqual(t,get(v.Headings(4),'YData'),[-.6 -.36],'AbsTol',1e-12);
x=get(v.Ball,'XData');y=get(v.Ball,'YData');
verifyEqual(t,[min(x) max(x) min(y) max(y)],[1.25-P.ballR 1.25+P.ballR -.8-P.ballR -.8+P.ballR],'AbsTol',1e-12);
verifyEqual(t,get(v.ScoreText,'String'),'BLUE  2 : 1  RED');
verifySubstring(t,get(v.ClockText,'String'),'00:03.5');
for k=1:100,row(57)=k/100;v.showFrame(row,true);end
verifyEqual(t,numel(findall(v.Figure)),count);
end
function testPauseSpeedStopAndClose(t)
v=LiveViewer2D(t.TestData.P,'off',1);c=onCleanup(@()dispose(v)); %#ok<NASGU>
v.beginRun();v.ready();v.togglePause();verifyTrue(t,v.PauseRequested);verifyFalse(t,v.Paused);
verifyEqual(t,get(v.StatusText,'String'),'Pausing...');
v.togglePause();verifyTrue(t,v.PauseRequested);
verifyError(t,@()v.checkPauseTimeout(0),'TDP:AnimationControlTimeout');
frame=v.LastRow;frame(61)=.05;v.showFrame(frame);
count=v.FrameCount;v.confirmPauseState(true);
verifyTrue(t,v.Paused);verifyEqual(t,v.FrameCount,count);
verifyEqual(t,get(v.PauseButton,'String'),'Resume');
verifyEqual(t,char(get(v.StartButton,'Interruptible')),'on');
stamp=v.LastRow(61);v.setSpeed(4);verifyEqual(t,v.LastRow(61),stamp);verifyTrue(t,v.Paused);
v.togglePause();verifyFalse(t,v.PauseRequested);verifyTrue(t,v.Paused);
verifyEqual(t,get(v.StatusText,'String'),'Resuming...');
v.confirmPauseState(false);verifyFalse(t,v.Paused);verifyEqual(t,v.Speed,4);
verifyEqual(t,{v.Events.event},{'started','pauseRequested','paused','speed','resumeRequested','resumed'});
v.togglePause();v.stop();verifyTrue(t,v.StopRequested);verifyFalse(t,v.Paused);
verifyFalse(t,v.PauseRequested);v.checkPauseTimeout(0);
v.finishRun(zeros(0,98));v.close();verifyFalse(t,isgraphics(v.Figure));
end
function testInvalidSpeedLeavesNoWindow(t)
before=numel(findall(groot,'Type','figure'));
verifyError(t,@()LiveViewer2D(t.TestData.P,'off',NaN),'TDP:AnimationSpeed');
P=t.TestData.P;P.Tmatch=-1;
verifyError(t,@()LiveViewer2D(P,'off',1),'TDP:AnimationDuration');
P.Tmatch=.071;
verifyError(t,@()LiveViewer2D(P,'off',1),'TDP:AnimationDuration');
verifyEqual(t,numel(findall(groot,'Type','figure')),before);
v=LiveViewer2D(t.TestData.P,'off',3);c=onCleanup(@()dispose(v)); %#ok<NASGU>
labels=get(v.SpeedControl,'String');verifyEqual(t,labels{get(v.SpeedControl,'Value')},'3x');
end
function testAnimatedTrajectoryMatchesNormalSimulation(t)
for dt=[.05 .04]
 P=t.TestData.P;P.dt=dt;P.Tmatch=8;P.seed=2;
 expected=runMatch(P);
 v=LiveViewer2D(P,'off',Inf);c=onCleanup(@()dispose(v));
 actual=runAnimatedMatch(P,v);
 verifyEqual(t,actual,expected,'AbsTol',1e-12);
 verifyGreaterThan(t,max(actual(:,57))-min(actual(:,57)),.01);
 verifyGreaterThan(t,max(actual(:,4))-min(actual(:,4)),.1);
 verifyEqual(t,v.Trace,actual);verifyEqual(t,v.FrameCount,size(actual,1));
 verifyEqual(t,v.LastRow,actual(end,:));verifyFalse(t,v.Running);
 clear c
end
end
function dispose(v)
if isvalid(v) && isgraphics(v.Figure),delete(v.Figure);end
end

function testV1ChaserHighlight(t)
P=tdp.v1Config();
v=LiveViewer2D(P,'off',Inf);
cleanup=onCleanup(@()dispose(v)); %#ok<NASGU>
row=v.LastRow;
row(71:72)=[3 4];
v.showFrame(row,true);
widths=arrayfun(@(body)get(body,'LineWidth'),v.Bodies);
verifyEqual(t,find(widths>2),[3 8]);
row(71:72)=[0 0];
v.showFrame(row,true);
verifyFalse(t,any(arrayfun(@(body)get(body,'LineWidth')>2,v.Bodies)));
end

function testV1LiveMatchReplaysDecisions(t)
for period=[.05 .04]
    P=tdp.v1Config();
    P.dt=period;
    P.Tmatch=8;
    P.seed=3;
    [reference,decisions]=runMatch(P);
    v=LiveViewer2D(P,'off',Inf);
    cleanup=onCleanup(@()dispose(v));
    [live,liveDecisions]=runAnimatedMatch(P,v);
    verifyEqual(t,live,reference);
    verifyEqual(t,liveDecisions,decisions);
    verifyEqual(t,size(decisions,1),round(P.Tmatch/P.dt));
    verifyEqual(t,live(:,49:56),repmat([1 3 5 2 1 3 5 2],size(live,1),1));
    clear cleanup
end
end
