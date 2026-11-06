function tests=test_v1_model()
%TEST_V1_MODEL Exercise the eight real skill charts, arbiter and actuator.
tests=functiontests(localfunctions);
end

function testShotAndReplay(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=shotFixture(dt,4);
    [trace,q]=runFixture(P,world);
    [again,events]=runFixture(P,world);
    verifyEqual(t,again,trace);
    verifyEqual(t,events,q);
    verifyEqual(t,size(q),[round(P.Tmatch/dt) 171]);
    verifyEqual(t,trace(:,49:56),repmat([1 3 5 2 1 3 5 2],size(trace,1),1));
    kick=find(q(:,c.kicker)==4,1);
    assertNotEmpty(t,kick,'Blue ST must physically kick in the prepared fixture.');
    verifyEqual(t,trace(kick,66),1);
    verifyEqual(t,q(kick,c.status(4)),double(TdpStatus.Done));
    verifyEqual(t,q(kick,c.feedbackId(4)),q(kick,c.requestId(4)));
    verifyGreaterThan(t,trace(kick,59),0);
    verifyGreaterThan(t,trace(kick,57),trace(kick-1,57));
    verifyEqual(t,unique(q(1:kick,c.skill(4)))',(0:4));
    recordEdge('normal-shot',dt,4,q,max(1,kick-1):kick);
end
end

function testKickRevocationAndReturn(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=shotFixture(dt,4);
    [~,normal]=runFixture(P,world);
    start=firstRunning(t,normal,4,c);
    cut=normal(start+1,c.time);
    P.v1UnavailableWindow(4,:)=[cut cut+3*dt];
    P.v1RecoveryWindow(1,:)=[cut+3*dt P.Tmatch+dt];
    [~,q]=runFixture(P,world);
    k=start+1;
    verifyEqual(t,q(k,c.chaser(1)),3);
    verifyEqual(t,q(k,c.kind(4)),double(TdpAction.Stop));
    verifyEqual(t,q(k,c.requestId(4)),q(start,c.requestId(4)));
    verifyEqual(t,q(k,c.feedbackId(4)),q(start,c.requestId(4)));
    verifyEqual(t,q(k,c.status(4)),double(TdpStatus.Failed));
    verifyEqual(t,q(k,c.kicker),0);
    verifyFalse(t,any(q(:,c.kicker)==4 & q(:,c.requestId(4))==q(start,c.requestId(4))));
    verifyTrue(t,any(q(k:end,c.chaser(1))==4));
    verifyEqual(t,q(:,c.failed(1)),zeros(size(q,1),1));
    recordEdge('unavailable-during-preparation',dt,4,q,start:k+1);
end
end

function testFailureTransfersToMidfielder(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=shotFixture(dt,4);
    P.v1FailWindow(4,:)=[0 P.Tmatch+dt];
    [~,q]=runFixture(P,world);
    failed=find(q(:,c.kind(4))==double(TdpAction.Kick) & ...
        q(:,c.status(4))==double(TdpStatus.Failed),1);
    assertNotEmpty(t,failed);
    verifyEqual(t,q(failed,c.feedbackId(4)),q(failed,c.requestId(4)));
    verifyEqual(t,q(failed,c.kicker),0);
    verifyEqual(t,q(failed+1,c.phase(1)),double(TdpTeamPhase.Fallback));
    verifyEqual(t,q(failed+1,c.chaser(1)),3);
    verifyEqual(t,q(failed+1,c.failed(1)),1);
    recordEdge('confirmed-execution-failure',dt,4,q,failed-1:failed+1);
end
end

function testRecoveryDrainsPendingMidfielder(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=shotFixture(dt,3);
    P.v1UnavailableWindow(4,:)=[0 P.Tmatch+dt];
    [trace,normal]=runFixture(P,world);
    kick=find(normal(:,c.kicker)==3,1);
    assertNotEmpty(t,kick,'MF must actually shoot while carrying the fixed MF label.');
    verifyEqual(t,trace(kick,51),double(TdpRole.MF));
    verifyEqual(t,trace(kick,66),1);
    start=firstRunning(t,normal,3,c);
    k=start+1;
    cut=normal(k,c.time);
    P.v1UnavailableWindow(4,:)=[0 cut];
    P.v1RecoveryWindow(1,:)=[cut P.Tmatch+dt];
    [~,q]=runFixture(P,world);
    verifyEqual(t,q(k,c.recovering(1)),1);
    verifyEqual(t,q(k,c.chaser(1)),0);
    verifyEqual(t,q(k,c.rawKind(3)),double(TdpAction.Kick));
    verifyEqual(t,q(k,c.kind(3)),double(TdpAction.Stop));
    verifyEqual(t,q(k,c.status(3)),double(TdpStatus.Failed));
    verifyEqual(t,q(k,c.feedbackId(3)),q(start,c.requestId(3)));
    verifyEqual(t,q(k+1,c.chaser(1)),4);
    verifyEqual(t,q(k+1,c.recovering(1)),0);
    verifyFalse(t,any(q(k:end,c.kicker)==3));
    recordEdge('mf-shoots',dt,3,normal,kick);
    recordEdge('return-to-st',dt,3,q,start:k+1);
end
end

function testBlindStaleAndPaused(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=shotFixture(dt,4);
    P.Tmatch=.6;
    P.v1BlindWindow(:,2)=P.Tmatch+dt;
    world.ball.x=1.5;world.ball.y=2.15;
    [trace,q]=runFixture(P,world);
    world.ball.x=-1.65;world.ball.y=-2.15;
    [changed,events]=runFixture(P,world);
    verifyEqual(t,events,q);
    verifyEqual(t,changed(:,73:96),trace(:,73:96));
    verifyEqual(t,q(:,c.phase),repmat(double(TdpTeamPhase.Search),size(q,1),2));
    verifyEqual(t,nnz(q(:,c.kicker)),0);
    P.v1BlindWindow(:)=0;
    P.v1StaleWindow(:,2)=P.Tmatch+dt;
    P.v1StopWindow=[2*dt 4*dt];
    [~,q]=runFixture(P,world);
    verifyEqual(t,nnz(q(:,c.ballFresh)),0);
    paused=q(:,c.running)==0;
    verifyTrue(t,any(paused));
    verifyEqual(t,q(paused,c.chaser),zeros(nnz(paused),2));
    verifyEqual(t,q(paused,c.kind),repmat(double(TdpAction.Stop),nnz(paused),8));
end
end

function testLateFeedbackAtTeamInput(t)
c=v1TraceColumns();
[P,world]=shotFixture(.05,4);
P.Tmatch=.15;
templates=tdpTemplates(P);
requests=repmat(templates.Request,1,8);
feedback=repmat(templates.Feedback,1,8);
previous=tdp.v1TeamMemory();previous.chaser=4;
requests(4).kind=TdpAction.Kick;
requests(4).requestId=uint32(42);
requests(4).validUntil=.5;
feedback(4).status=TdpStatus.Failed;
feedback(4).requestId=uint32(41);
[~,late]=runFixture(P,world,requests,feedback,previous);
verifyEqual(t,late(1,c.failed(1)),0);
verifyEqual(t,late(1,c.chaser(1)),4);
feedback(4).requestId=uint32(42);
[~,matched]=runFixture(P,world,requests,feedback,previous);
verifyEqual(t,matched(1,c.failed(1)),1);
verifyEqual(t,matched(1,c.chaser(1)),3);
end

function testFrozenRequestAuthorization(t)
% Force the exact handoff boundary independently of chart transition timing.
[P,world]=shotFixture(.05,4);T=tdpTemplates(P);
obs=V1Observation2D(world,.1,P);blue=tdp.v1TeamMemory();red=blue;
blue.chaser=3;red.chaser=8;
raw=repmat(T.Request,1,8);plans=repmat(T.Intent,1,8);
fb=repmat(T.Feedback,1,8);
% A stale plan and frozen request both still say Kick for the old owner.
% Only the team's current ownership token can disarm that request.
plans(4).type=TdpAction.Kick;
raw(4).kind=TdpAction.Kick;raw(4).requestId=uint32(42);
raw(4).validUntil=.6;fb(4).status=TdpStatus.Running;fb(4).requestId=uint32(42);
effective=V1AuthorizeRequests(raw,plans,obs,blue,red,raw,fb,P);
verifyEqual(t,effective(4).kind,TdpAction.Stop);
verifyEqual(t,effective(4).requestId,uint32(42));
end

function testHiddenCoordinatesDoNotEnterDiagnostics(t)
[P,world]=shotFixture(.05,4);
P.v1BlindWindow(:,2)=1;
first=V1Observation2D(world,.1,P);
world.ball.x=-3.7;world.ball.y=2.1;world.ball.vx=1.2;
second=V1Observation2D(world,.1,P);
verifyEqual(t,first,second);
T=tdpTemplates(P);
for i=1:8
    geometry=CoreGeometry(first(i),T.Intent,.1,P);
    verifyFalse(t,geometry.ballVisible);
    verifyEqual(t,geometry.distance,0);
end
end

function testPauseBlindAndStaleDuringPreparation(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [base,world]=shotFixture(dt,4);
    [~,normal]=runFixture(base,world);
    k=firstRunning(t,normal,4,c)+1;
    cut=normal(k,c.time);
    for trial=1:3
        P=base;
        switch trial
            case 1
                P.v1StopWindow=[cut P.Tmatch+dt];label='stop-during-preparation';
            case 2
                P.v1BlindWindow=repmat([cut P.Tmatch+dt],8,1);label='loss-during-preparation';
            otherwise
                P.v1StaleWindow(4,:)=[cut P.Tmatch+dt];label='stale-during-preparation';
        end
        [~,q]=runFixture(P,world);
        verifyEqual(t,q(k,c.kind(4)),double(TdpAction.Stop));
        verifyEqual(t,q(k,c.feedbackId(4)),q(k-1,c.requestId(4)));
        verifyEqual(t,q(k,c.status(4)),double(TdpStatus.Failed));
        verifyEqual(t,nnz(q(k:end,c.kicker)==4),0);
        recordEdge(label,dt,4,q,k-1:k);
    end
end
end

function testNoFeedbackLeavesKickAtTimeout(t)
for dt=[.05 .04]
    P=tdp.v1Config();P.dt=dt;
    scenario=makeScenario(P,2);
    replay=runReplay(P,scenario);
    start=find(replay(:,3)==double(TdpPhase.Kick),1);
    finish=find(replay(:,3)==double(TdpPhase.Recover),1);
    assertNotEmpty(t,start);assertNotEmpty(t,finish);
    elapsed=(finish-start)*dt;
    verifyGreaterThanOrEqual(t,elapsed,P.kickTimeout-1e-12);
    verifyLessThanOrEqual(t,elapsed,P.kickTimeout+dt);
    fprintf('V1_CASE %s\n',jsonencode(struct('case','no-feedback-core-replay', ...
        'dt',dt,'robot',scenario(start).obs.selfIndex,'requestId',replay(start,2), ...
        'kickTime',(start-1)*dt,'recoverTime',(finish-1)*dt,'elapsedSeconds',elapsed)));
end
end

function testRemovedRobotClearsPreparation(t)
[P,world]=shotFixture(.05,4);T=tdpTemplates(P);
world.active(4)=false;
world.actuator(4).active=true;
world.actuator(4).feedback.requestId=uint32(42);
world.actuator(4).feedback.status=TdpStatus.Running;
[next,feedback,kicker]=V1Plant2D(world,repmat(T.Request,1,8),repmat(T.Intent,1,8),.10,P);
verifyFalse(t,next.actuator(4).active);
verifyEqual(t,feedback(4).requestId,uint32(42));
verifyEqual(t,feedback(4).status,TdpStatus.Failed);
verifyEqual(t,kicker,0);
end

function recordEdge(label,dt,robot,q,steps)
c=v1TraceColumns();
edge=struct('case',label,'dt',dt,'robot',robot,'tSim',q(steps,c.time)', ...
    'blueOwner',q(steps,c.chaser(1))','rawKind',q(steps,c.rawKind(robot))', ...
    'kind',q(steps,c.kind(robot))','requestId',q(steps,c.requestId(robot))', ...
    'feedbackId',q(steps,c.feedbackId(robot))','status',q(steps,c.status(robot))', ...
    'kicker',q(steps,c.kicker)');
fprintf('V1_CASE %s\n',jsonencode(edge));
end

function k=firstRunning(t,q,robot,c)
k=find(q(:,c.kind(robot))==double(TdpAction.Kick) & ...
    q(:,c.status(robot))==double(TdpStatus.Running),1);
assertNotEmpty(t,k);
end

function [P,world]=shotFixture(dt,robot)
P=tdp.v1Config();P.dt=dt;P.Tmatch=1.2;P.kickNoise=0;
T=tdpTemplates(P);world=T.World;
world.ball.x=2;world.ball.y=0;
world.robots(robot).x=world.ball.x-.245;
world.robots(robot).y=0;world.robots(robot).th=0;
end

function [trace,tactics]=runFixture(P,world,requests,feedback,memory)
[input,model]=matchSimulationInput(P);
input=input.setVariable('world0',world,'Workspace',model);
if nargin>2
    input=input.setVariable('request0',requests,'Workspace',model);
    input=input.setVariable('feedback0',feedback,'Workspace',model);
    input=input.setVariable('v1Memory0',memory,'Workspace',model);
end
output=sim(input);trace=recordRows(output.records);tactics=recordRows(output.tacticsRecords);
end
