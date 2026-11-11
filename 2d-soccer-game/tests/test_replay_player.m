function tests=test_replay_player
%TEST_REPLAY_PLAYER Loader, playback state and inspector of the replay window.
% Automated checks run on hidden figures. They do not replace the manual GUI
% checklist in docs/replay/TESTING.md.
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'scripts'),fullfile(root,'algorithms'),fullfile(root,'interfaces'), ...
    fullfile(root,'environment'));
t.TestData.root=root;
t.TestData.short=fullfile(root,'build','animation-20261106-105233-827','trace.mat');
t.TestData.long=fullfile(root,'build','animation-20261106-151829-226','trace.mat');
set(groot,'DefaultFigureVisible','off');
end

% ---------------------------------------------------------------- loader
function testLoaderOpensRealRecordings(t)
assumeTrue(t,isfile(t.TestData.short) && isfile(t.TestData.long),'saved matches not present');
short=loadReplayRecording(t.TestData.short);
verifyEqual(t,size(short.Trace),[100 98]);
verifyEqual(t,short.Dt,0.05);
verifyEqual(t,short.Times,short.Trace(:,61));
long=loadReplayRecording(fileparts(t.TestData.long));   % a folder works too
verifyEqual(t,size(long.Trace),[12000 98]);
verifyTrue(t,long.HasTactics);
verifyEqual(t,size(long.Tactics),[12000 171]);
verifyEmpty(t,long.Warnings);
end

function testLoaderRejectsBadFilesWithClearErrors(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
good=validTrace(20);P=validP();
verifyError(t,@()loadReplayRecording(fullfile(folder,'nope.mat')),'TDP:ReplayLoad');
garbage=fullfile(folder,'garbage.mat');writelines("not a mat file",garbage);
verifyError(t,@()loadReplayRecording(garbage),'TDP:ReplayLoad');
noTrace=fullfile(folder,'noTrace.mat');save(noTrace,'P');
verifyError(t,@()loadReplayRecording(noTrace),'TDP:ReplayLoad');
noP=fullfile(folder,'noP.mat');trace=good;save(noP,'trace');
verifyError(t,@()loadReplayRecording(noP),'TDP:ReplayLoad');
cases={'wrongColumns',good(:,1:97);'nan',nanRow(good);'empty',zeros(0,98); ...
    'nonMonotonic',nonMonotonic(good);'text',repmat('a',20,98)};
for k=1:size(cases,1)
    file=fullfile(folder,[cases{k,1} '.mat']);trace=cases{k,2};save(file,'trace','P');
    verifyError(t,@()loadReplayRecording(file),'TDP:ReplayLoad',cases{k,1});
end
badP=struct('dt',0.05);trace=good;file=fullfile(folder,'badP.mat');P=badP;save(file,'trace','P');
verifyError(t,@()loadReplayRecording(file),'TDP:ReplayLoad');
end

function testInconsistentTacticsAreDroppedWithWarning(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
trace=validTrace(20);P=validP();
tactics=zeros(20,171);tactics(:,1)=trace(:,61);
file=fullfile(folder,'ok.mat');save(file,'trace','P','tactics');
rec=loadReplayRecording(file);verifyTrue(t,rec.HasTactics);verifyEmpty(t,rec.Warnings);
tactics=zeros(7,171); %#ok<NASGU>
file=fullfile(folder,'size.mat');save(file,'trace','P','tactics');
rec=loadReplayRecording(file);verifyFalse(t,rec.HasTactics);verifyNumElements(t,rec.Warnings,1);
verifyEqual(t,rec.Trace,trace);
tactics=zeros(20,171);tactics(:,1)=trace(:,61)+1;
file=fullfile(folder,'time.mat');save(file,'trace','P','tactics');
rec=loadReplayRecording(file);verifyFalse(t,rec.HasTactics);verifyNumElements(t,rec.Warnings,1);
end

function testLoadingAndReplayLeaveRecordingsByteIdentical(t)
assumeTrue(t,isfile(t.TestData.short) && isfile(t.TestData.long),'saved matches not present');
files={t.TestData.short,t.TestData.long};
before=cellfun(@sha256,files,'UniformOutput',false);
for k=1:2
    rec=loadReplayRecording(files{k});
    p=MatchReplay2D(rec.P,rec.Trace,'unchanged','off',rec.Tactics);
    p.SeekFrame(size(rec.Trace,1));p.Restart();p.Pause();delete(p.Figure);
end
verifyEqual(t,cellfun(@sha256,files,'UniformOutput',false),before);
end

% ---------------------------------------------------------------- playback
function testShownFrameMatchesRecordedState(t)
[P,trace]=syntheticMatch(100);
trace(40,[4 12 20 57 58 62 63])=[0.8 -0.6 pi/2 1.25 -0.8 2 1];   % robot 4: x, y, heading; ball; score
p=openPlayer(t,P,trace);
p.Pause();p.SeekFrame(40);
s=p.State();
verifyEqual(t,s.Frame,40);
verifyEqual(t,s.Time,trace(40,61));
fig=p.Figure;
patches=findobj(fig,'Type','patch');          % 8 robot bodies + the ball
center=@(h)[mean([min(get(h,'XData')) max(get(h,'XData'))]) mean([min(get(h,'YData')) max(get(h,'YData'))])];
centers=cell2mat(arrayfun(@(h)center(h),patches,'UniformOutput',false));
verifyTrue(t,any(all(abs(centers-[0.8 -0.6])<1e-9,2)),'robot 4 is drawn at its recorded position');
verifyTrue(t,any(all(abs(centers-[1.25 -0.8])<1e-9,2)),'ball is drawn at its recorded position');
verifySubstring(t,clockString(fig),sprintf('%02d:%05.2f',floor(trace(40,61)/60),mod(trace(40,61),60)));
verifySubstring(t,clockString(fig),'帧 40 / 100');
verifyEqual(t,textOf(findText(fig,'^BLUE')),'BLUE  2 : 1  RED');
end

function testSeekFrameAndTimeSnapToRecordedRows(t)
[P,trace]=syntheticMatch(4000);                       % 200 s; times are k*0.05
p=openPlayer(t,P,trace);p.Pause();
p.SeekTime(166.6);                                    % stored as 166.60000000000002
verifyEqual(t,p.State().Frame,3332,'tolerance keeps the seek on the requested row');
p.SeekTime(166.62);verifyEqual(t,p.State().Frame,3332,'latest row not after t');
p.SeekTime(166.65);verifyEqual(t,p.State().Frame,3333);
p.SeekTime(0);verifyEqual(t,p.State().Frame,1,'before first row clamps to row 1');
p.SeekTime(1e9);verifyEqual(t,p.State().Frame,4000);
p.SeekFrame(-5);verifyEqual(t,p.State().Frame,1);
p.SeekFrame(1e6);verifyEqual(t,p.State().Frame,4000);
for bad={NaN,Inf,'a',[1 2]}
    verifyError(t,@()p.SeekTime(bad{1}),'TDP:ReplaySeek');
end
verifyError(t,@()p.SeekFrame(NaN),'TDP:ReplaySeek');
end

function testPauseDoesNotAdvanceSimulationTime(t)
[P,trace]=syntheticMatch(1200);
p=openPlayer(t,P,trace);
verifyTrue(t,p.State().Playing);
verifyTrue(t,waitUntil(@()p.State().Time>trace(1,61),10),'playback advanced while playing');
p.Pause();
frozen=p.State();
pause(0.8);
after=p.State();
verifyFalse(t,after.Playing);
verifyEqual(t,after.Frame,frozen.Frame);
verifyEqual(t,after.Time,frozen.Time);
p.Resume();pause(0.5);
verifyTrue(t,p.State().Playing);
verifyGreaterThanOrEqual(t,p.State().Time,frozen.Time);
end

function testPlaybackRateScalesSimulationTime(t)
[P,trace]=syntheticMatch(2400);                      % 120 s
p=openPlayer(t,P,trace);
verifyError(t,@()p.SetRate(3),'TDP:ReplayRate');
for rate=[0.25 0.5 1 2 4 8]
    p.SetRate(rate);p.Restart();
    started=tic;pause(1.2);elapsed=toc(started);
    advance=p.State().Time-trace(1,61);
    fprintf('[rate] %gx: %.2f s of simulation time in %.2f s of wall time (ratio %.2f)\n',rate,advance,elapsed,advance/elapsed);
    verifyEqual(t,p.State().Rate,rate);
    verifyGreaterThan(t,advance,rate*(elapsed-0.4),sprintf('%gx lower bound',rate));
    verifyLessThan(t,advance,rate*elapsed+0.1,sprintf('%gx upper bound',rate));
    p.Pause();
end
end

function testRestartAndEndOfRecording(t)
[P,trace]=syntheticMatch(200);
p=openPlayer(t,P,trace);p.Pause();
p.SeekFrame(200);
fig=p.Figure;
verifyFalse(t,p.State().Playing);
pauseButton=findobj(fig,'Type','uicontrol','Style','pushbutton','String','继续');
verifyEqual(t,get(pauseButton,'Enable'),'off','nothing left to resume at the end');
verifyEqual(t,statusString(fig),'回放结束');
p.Resume();verifyEqual(t,p.State().Frame,200,'resume at the end is a no-op');
p.Restart();
verifyEqual(t,p.State().Frame,1);
verifyTrue(t,p.State().Playing);
p.Pause();
end

function testStepAndEventNavigation(t)
[P,trace]=syntheticMatch(200);
c=replayColumns();
trace(60:end,c.score(1))=1;trace(90,c.kicked)=1;
p=openPlayer(t,P,trace);p.Pause();
p.Step(3);verifyEqual(t,p.State().Frame,4);
p.Step(-100);verifyEqual(t,p.State().Frame,1);
p.Step(1000);verifyEqual(t,p.State().Frame,200);
verifyEqual(t,[p.Events.frame],[60 90]);
p.JumpToEvent(2);
verifyEqual(t,p.State().Frame,90);
verifyFalse(t,p.State().Playing);
verifyError(t,@()p.JumpToEvent(3),'TDP:ReplaySeek');
verifyError(t,@()p.JumpToEvent(0),'TDP:ReplaySeek');
end

function testOnScreenControlsStillWork(t)
% The original controls (slider, speed menu, pause, restart) keep their behaviour.
[P,trace]=syntheticMatch(1200);
p=openPlayer(t,P,trace);fig=p.Figure;
slider=findobj(fig,'Type','uicontrol','Style','slider');
speed=findobj(fig,'Type','uicontrol','Style','popupmenu');
pauseButton=findobj(fig,'Type','uicontrol','Style','pushbutton','String','暂停');
restart=findobj(fig,'Type','uicontrol','Style','pushbutton','String','从头播放');
verifyNumElements(t,slider,1);verifyNumElements(t,speed,1);
verifyNumElements(t,pauseButton,1);verifyNumElements(t,restart,1);
cb=get(pauseButton,'Callback');cb(pauseButton,[]);
verifyFalse(t,p.State().Playing);verifyEqual(t,get(pauseButton,'String'),'继续');
frozen=p.State().Time;pause(0.5);verifyEqual(t,p.State().Time,frozen);
set(slider,'Value',600);cb=get(slider,'Callback');cb(slider,[]);
verifyEqual(t,p.State().Frame,600);verifyFalse(t,p.State().Playing);
set(speed,'Value',6);cb=get(speed,'Callback');cb(speed,[]);
verifyEqual(t,p.State().Rate,8);
cb=get(pauseButton,'Callback');cb(pauseButton,[]);
verifyTrue(t,p.State().Playing);
cb=get(restart,'Callback');cb(restart,[]);
verifyEqual(t,p.State().Frame,1);
p.Pause();
end

function testInspectorAndEventListShowRecordedValues(t)
[P,trace]=syntheticMatch(120);
c=replayColumns();k=v1TraceColumns();
tactics=zeros(120,171);tactics(:,1)=trace(:,61);
tactics(50:end,k.phase(1))=4;tactics(50:end,k.chaser(1))=3;tactics(50:end,k.takeover(1))=1;
tactics(:,k.running)=1;trace(:,c.vxw(3))=0.5;
tactics(70,k.kicker)=4;trace(70,c.kicked)=1;
trace(1:120,c.vxw(7))=0;tactics(80:end,k.chaser(2))=7;      % red chaser stands still
p=openPlayer(t,P,trace,tactics);p.Pause();
verifyEqual(t,[p.Events.frame],[50 50 50 70 80 80]);
p.JumpToEvent(1);
verifySubstring(t,textOf(findText(p.Figure,'BLUE  phase')),'BLUE  phase Fallback');
list=findobj(p.Figure,'Type','uicontrol','Style','listbox');
labels=get(list,'String');
verifyNumElements(t,labels,6);
verifyTrue(t,all(contains(labels(1:5),'[R]')),'logged changes are marked [R]');
verifyTrue(t,contains(labels{6},'[I]'),'the rule-based waiting event is marked [I]');
verifyEqual(t,{p.Events.source},{'recorded','recorded','recorded','recorded','recorded','inferred'});
end

function testKeyboardShortcutsTimeBoxAndEventList(t)
% Drives the window's own callbacks (no OS-level key or mouse events are sent).
[P,trace]=syntheticMatch(200);
c=replayColumns();trace(60:end,c.score(1))=1;trace(90,c.kicked)=1;   % events at rows 60 and 90
p=openPlayer(t,P,trace);p.Pause();fig=p.Figure;
key=get(fig,'WindowKeyPressFcn');
press=@(name,character)key(fig,struct('Key',name,'Character',character));
p.SeekFrame(10);
press('rightarrow','');verifyEqual(t,p.State().Frame,11);
press('leftarrow','');verifyEqual(t,p.State().Frame,10);
press('rightbracket',']');verifyEqual(t,p.State().Frame,60);
press('rightbracket',']');verifyEqual(t,p.State().Frame,90);
press('rightbracket',']');verifyEqual(t,p.State().Frame,90,'no later event: stays');
press('leftbracket','[');verifyEqual(t,p.State().Frame,60);
press('space',' ');verifyTrue(t,p.State().Playing);
press('space',' ');verifyFalse(t,p.State().Playing);
box=findobj(fig,'Type','uicontrol','Style','edit');
set(box,'String','4.5');cb=get(box,'Callback');cb(box,[]);
verifyEqual(t,p.State().Frame,90,'4.5 s is row 90');
set(box,'String','abc');cb(box,[]);
verifyEqual(t,p.State().Frame,90,'non-numeric input is ignored');
list=findobj(fig,'Type','uicontrol','Style','listbox');
set(list,'Value',1);cb=get(list,'Callback');cb(list,[]);
verifyEqual(t,p.State().Frame,60,'choosing an event jumps to its row');
end

function testPlayerRejectsMalformedInputWithoutLeakingWindows(t)
[P,trace]=syntheticMatch(30);
before=numel(findall(groot,'Type','figure'));
bad=trace(:,1:97);verifyError(t,@()MatchReplay2D(P,bad,'x','off'),'TDP:ReplayTrace');
bad=trace;bad(5,10)=NaN;verifyError(t,@()MatchReplay2D(P,bad,'x','off'),'TDP:ReplayTrace');
verifyError(t,@()MatchReplay2D(P,zeros(0,98),'x','off'),'TDP:ReplayTrace');
bad=trace;bad(3,61)=bad(2,61);verifyError(t,@()MatchReplay2D(P,bad,'x','off'),'TDP:ReplayTrace');
verifyError(t,@()MatchReplay2D(P,trace,'x','off',zeros(5,171)),'TDP:ReplayTactics');
tactics=zeros(30,171);tactics(:,1)=trace(:,61)+0.5;
verifyError(t,@()MatchReplay2D(P,trace,'x','off',tactics),'TDP:ReplayTactics');
verifyEqual(t,numel(findall(groot,'Type','figure')),before);
end

function testPlayerNeverModifiesItsInputs(t)
[P,trace]=syntheticMatch(100);
c=replayColumns();k=v1TraceColumns();
tactics=zeros(100,171);tactics(:,1)=trace(:,61);tactics(20:end,k.chaser(1))=2;
trace(30,c.kicked)=1;
traceCopy=trace;tacticsCopy=tactics;
p=openPlayer(t,P,trace,tactics);
p.SeekFrame(50);p.Step(2);p.SetRate(2);p.JumpToEvent(1);p.Restart();p.Pause();
verifyEqual(t,trace,traceCopy);verifyEqual(t,tactics,tacticsCopy);
end

function testLongRecordingIsResponsive(t)
assumeTrue(t,isfile(t.TestData.long),'600 s recording not present');
rec=loadReplayRecording(t.TestData.long);
opening=tic;p=MatchReplay2D(rec.P,rec.Trace,'long','off',rec.Tactics);openSeconds=toc(opening);
t.addTeardown(@()delete(p.Figure));
p.Pause();
p.SeekTime(300);verifyEqual(t,p.State().Frame,6000);
timing=tic;for k=1:100,p.SeekFrame(6000+k);end;perSeek=toc(timing)/100;
fprintf('[timing] open 600 s replay: %.2f s | SeekFrame: %.1f ms per row\n',openSeconds,perSeek*1000);
verifyLessThan(t,openSeconds,30);
verifyLessThan(t,perSeek,0.25,'redraw of one row stays well below one 0.25 s budget');
end

% ---------------------------------------------------------------- helpers
function p=openPlayer(t,P,trace,tactics)
if nargin<4,tactics=[];end
p=MatchReplay2D(P,trace,'test','off',tactics);
t.addTeardown(@()delete(p.Figure));
end

function [P,trace]=syntheticMatch(rows)
P=tdp.defaultConfig();P.Tmatch=rows*P.dt;
trace=validTrace(rows);
end

function trace=validTrace(rows)
c=replayColumns();
trace=zeros(rows,98);
trace(:,c.time)=(1:rows)'*0.05;
trace(:,c.role)=repmat([1 3 5 2 1 3 5 2],rows,1);
trace(:,c.x)=repmat(linspace(-3,3,8),rows,1);
end

function P=validP()
P=struct('dt',0.05,'Tmatch',1);
end

function trace=nanRow(trace)
trace(4,7)=NaN;
end

function trace=nonMonotonic(trace)
trace(5,61)=trace(4,61);
end

function text=clockString(fig)
text=textOf(findText(fig,'帧 \d+ / \d+'));
end

function text=statusString(fig)
text=textOf(findText(fig,'^(正在回放|已暂停|回放结束)$'));
end

function h=findText(fig,pattern)
candidates=findobj(fig,'Type','uicontrol','Style','text');
for k=1:numel(candidates)
    if ~isempty(regexp(textOf(candidates(k)),pattern,'once'))
        h=candidates(k);return
    end
end
error('test:noText','no text control matches %s',pattern);
end

function text=textOf(handle)
text=get(handle,'String');
if iscell(text),text=strjoin(text,newline);end
end

function ok=waitUntil(condition,seconds)
% Poll while letting timers run; true as soon as condition() holds.
deadline=tic;ok=condition();
while ~ok && toc(deadline)<seconds
    pause(0.05);ok=condition();
end
end

function digest=sha256(file)
[status,out]=system(['sha256sum ' shellQuote(file)]);
assert(status==0,'sha256sum failed');
digest=strtok(strtrim(out));
end
