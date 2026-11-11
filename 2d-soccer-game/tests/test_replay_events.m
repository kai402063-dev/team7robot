function tests=test_replay_events
%TEST_REPLAY_EVENTS Column map, event extraction and inspector text for replay.
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'scripts'),fullfile(root,'algorithms'),fullfile(root,'interfaces'), ...
    fullfile(root,'environment'));
t.TestData.root=root;
t.TestData.realTrace=fullfile(root,'build','animation-20261106-151829-226','trace.mat');
end

function testColumnMapMatchesGeneratedSchema(t)
% replayColumns must agree with the schema exported from MatchRecord.
schema=jsondecode(fileread(fullfile(t.TestData.root,'docs','generated','trace_schema.json')));
c=replayColumns();
prefix=struct('x','robot.x','y','robot.y','th','robot.th','vxw','robot.vxw', ...
    'vyw','robot.vyw','cool','robot.cool','role','robot.role','ballX','ball.x', ...
    'ballY','ball.y','ballVx','ball.vx','ballVy','ball.vy','time','state.t', ...
    'score','score','lastTouch','lastTouch','pauseUntil','pauseUntil','shots','shots', ...
    'touchTime','touchTime','msgUntil','msgUntil','striker','striker','cmdVx','cmd.vx', ...
    'cmdVy','cmd.vy','cmdW','cmd.w','kicked','kicked','msg','msg');
fields=fieldnames(c);
verifyEqual(t,sort(fields),sort(fieldnames(prefix)));
covered=[];
for f=1:numel(fields)
    cols=c.(fields{f});
    for j=1:numel(cols)
        label=schema.columns.(sprintf('x%d',cols(j)));
        if numel(cols)==1
            expected=prefix.(fields{f});
        else
            expected=sprintf('%s[%d]',prefix.(fields{f}),j);
        end
        verifyEqual(t,label,expected,sprintf('column %d (%s)',cols(j),fields{f}));
    end
    covered=[covered cols]; %#ok<AGROW>
end
verifyEqual(t,sort(covered),1:98,'every column is named exactly once');
end

function testSyntheticEventsAreExactAndLabelled(t)
[trace,tactics]=syntheticRecording(80);
c=replayColumns();k=v1TraceColumns();
trace(10:end,c.score(1))=1;                          % blue goal at row 10
trace(5:end,c.msg)=5;trace(1:4,c.msg)=1;             % Kickoff -> Corner at row 5
tactics(12,k.kicker)=4;trace(12,c.kicked)=1;         % robot 4 kicks at row 12
tactics(20:end,k.phase(1))=4;tactics(20:end,k.takeover(1))=1;
tactics(20:end,k.chaser(1))=3;                       % chaser 0 -> 3 at row 20
tactics(7:9,k.kind(3))=2;tactics(7:9,k.requestId(3))=77; % Kick request id 77 from row 7
tactics(3,k.kind(3))=1;tactics(3:6,k.requestId(3))=5;    % a Goto: must NOT be listed
tactics(9:end,k.status(3))=3;tactics(9:end,k.feedbackId(3))=77; % Failed for id 77 at row 9
tactics(1:60,k.chaser(2))=0;
tactics(:,k.running)=1;
tactics(15:end,k.intent(4))=2;                       % robot 4 intent Stop -> Kick at row 15
% Red chaser 7 stands still from row 30 to row 80 (2.5 s at dt 0.05): inferred event.
tactics(30:end,k.chaser(2))=7;
trace(:,c.vxw(7))=0;trace(1:29,c.vxw(7))=0.5;
trace(:,c.vxw(3))=0.5;                               % blue chaser 3 keeps moving
events=replayEvents(trace,tactics);
byType=@(name)events(strcmp({events.type},name));
verifyEqual(t,[byType('goal').frame],10);
verifyEqual(t,byType('goal').team,1);
verifyEqual(t,[byType('referee').frame],5);
verifyEqual(t,[byType('kick').frame],12);
verifyEqual(t,byType('kick').robot,4);
verifyEqual(t,byType('kick').team,1);
verifyEqual(t,[byType('intent').frame],15);
verifyEqual(t,byType('intent').robot,4);
verifySubstring(t,byType('intent').detail,'Stop -> Kick');
verifyEqual(t,[byType('phase').frame],20);
verifyEqual(t,[byType('takeover').frame],20);
verifyEqual(t,[byType('chaser').frame],[20 30]);
request=byType('request');
verifyEqual(t,[request.frame],7);
verifySubstring(t,request.detail,'Kick request id 77');
feedback=byType('feedback');
verifyEqual(t,[feedback.frame],9);
verifySubstring(t,feedback.detail,'Failed');
still=byType('chaserStationary');
verifyEqual(t,[still.frame],30);
verifyEqual(t,still.robot,7);
verifyEqual(t,still.source,'inferred');
verifyEqual(t,unique({events(~strcmp({events.type},'chaserStationary')).source}),{'recorded'});
verifyEqual(t,[events.time],trace([events.frame],c.time)');
verifyTrue(t,issorted([events.frame]));
verifyTrue(t,all(cellfun(@(s)~isempty(s),{events.evidence})));
end

function testConstantRecordingHasNoEvents(t)
[trace,tactics]=syntheticRecording(30);
verifyEmpty(t,replayEvents(trace,tactics));
verifyEmpty(t,replayEvents(trace));
end

function testFastChaserIsNotReportedStationary(t)
[trace,tactics]=syntheticRecording(80);
c=replayColumns();k=v1TraceColumns();
tactics(:,k.chaser(1))=4;tactics(:,k.running)=1;
trace(:,c.vxw(4))=0.25;
verifyEmpty(t,replayEvents(trace,tactics));
trace(:,c.vxw(4))=0;                       % stops: now reported
found=replayEvents(trace,tactics);
verifyEqual(t,{found.type},{'chaserStationary'});
verifyEqual(t,[found.frame],1);
end

function testPausedGameIsNotReportedAsWaiting(t)
[trace,tactics]=syntheticRecording(80);
k=v1TraceColumns();
tactics(:,k.chaser(1))=4;tactics(:,k.running)=0;   % referee pause: not tactical waiting
events=replayEvents(trace,tactics);
verifyFalse(t,any(strcmp({events.type},'chaserStationary')));
end

function testMismatchedInputsAreRejected(t)
[trace,tactics]=syntheticRecording(10);
verifyError(t,@()replayEvents(trace(:,1:97)),'TDP:ReplayEvents');
verifyError(t,@()replayEvents(trace,tactics(1:5,:)),'TDP:ReplayEvents');
end

function testRealRecordingCountsMatchIndependentPythonCounts(t)
assumeTrue(t,isfile(t.TestData.realTrace),'600 s recording not present in this checkout');
rec=loadReplayRecording(t.TestData.realTrace);
events=replayEvents(rec.Trace,rec.Tactics);
count=@(name)sum(strcmp({events.type},name));
% Reference numbers were counted with an independent numpy script
% (replay-mvp-evidence/phaseC/independent_counts.py) from the same file.
verifyEqual(t,count('phase'),22);
verifyEqual(t,count('chaser'),44);
verifyEqual(t,count('kick'),126);
verifyEqual(t,count('takeover'),1);
verifyEqual(t,count('referee'),1);
verifyEqual(t,count('intent'),107);
verifyEqual(t,count('goal'),0);
verifyEqual(t,[events.time],rec.Trace([events.frame],61)');
takeover=events(strcmp({events.type},'takeover'));
verifyEqual(t,takeover.time,166.85,'AbsTol',1e-9);
end

function testNoTacticsStillListsKicksWithoutInventingRobots(t)
assumeTrue(t,isfile(t.TestData.realTrace),'600 s recording not present in this checkout');
rec=loadReplayRecording(t.TestData.realTrace);
events=replayEvents(rec.Trace);
verifyEqual(t,sum(strcmp({events.type},'kick')),126);
verifyTrue(t,all([events(strcmp({events.type},'kick')).robot]==0));
verifyFalse(t,any(strcmp({events.type},'phase')));
end

function testInspectorTextShowsRecordedValuesOnly(t)
[trace,tactics]=syntheticRecording(5);
c=replayColumns();k=v1TraceColumns();
trace(3,[c.x(4) c.y(4) c.vxw(4) c.vyw(4)])=[2.5 -1.25 0.3 0.4];
trace(3,c.role(4))=2;                                        % ST
tactics(3,[k.intent(4) k.kind(4) k.skill(4) k.status(4)])=[2 2 4 1]; % Kick Kick Kick Running
tactics(3,[k.requestId(4) k.feedbackId(4)])=[3205 3205];
tactics(3,[k.targetX(4) k.targetY(4)])=[4.5 0];
tactics(3,k.phase(1))=4;tactics(3,k.chaser(1))=3;
lines=replayInfoText(trace(3,:),tactics(3,:));
text=strjoin(lines,newline);
verifySubstring(t,text,'BLUE  phase Fallback');
verifySubstring(t,text,'chaser 3');
row=lines{find(startsWith(lines,'4  ST'),1)};
verifySubstring(t,row,'2.50');verifySubstring(t,row,'-1.25');
verifySubstring(t,row,'0.50');                               % hypot(.3,.4)
verifySubstring(t,row,'Kick');verifySubstring(t,row,'Running');verifySubstring(t,row,'#3205');
none=strjoin(replayInfoText(trace(3,:),[]),newline);
verifySubstring(t,none,'NOT RECORDED');
verifyFalse(t,contains(none,'Running'));
end

function [trace,tactics]=syntheticRecording(n)
c=replayColumns();
trace=zeros(n,98);
trace(:,c.time)=(1:n)'*0.05;
trace(:,c.role)=repmat([1 3 5 2 1 3 5 2],n,1);
tactics=zeros(n,171);
tactics(:,1)=trace(:,c.time);
end
