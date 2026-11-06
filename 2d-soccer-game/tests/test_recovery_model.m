function tests=test_recovery_model()
%TEST_RECOVERY_MODEL Exercise automatic handback in the opt-in eight-robot model.
tests=functiontests(localfunctions);
end

function testHandoverDuringApproach(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,4);
    P.v1UnavailableWindow(4,:)=[0 .3];
    [~,q,h]=runFixture(P,world);
    k=firstRelease(t,q,c,1);
    expected=.3+P.v1RecoveryHealthySeconds;
    verifyGreaterThanOrEqual(t,q(k,c.time),expected-1e-10);
    verifyLessThanOrEqual(t,q(k,c.time),expected+2*dt+1e-10);
    verifyFalse(t,any(q(1:k,c.kind(3))==double(TdpAction.Kick)));
    verifyEqual(t,q(k,c.chaser(1)),4);
    verifyEqual(t,q(:,c.recovering(1)),zeros(size(q,1),1));
    record('approach-handback',dt,1,3,q,h,[1 k-1 k]);
end
end

function testNaturalGeometryFailureRecovers(t)
% Both seeds first produced an actual red-striker Failed in the archived V1.
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    P=tdp.recoveryConfig();P.dt=dt;P.Tmatch=12;
    if dt==.05,P.seed=5;else,P.seed=11;end
    template=tdpTemplates(P);
    [~,q,h]=runFixture(P,template.World);
    fail=find(q(:,c.kind(8))==double(TdpAction.Kick) & q(:,c.status(8))==double(TdpStatus.Failed) & ...
        h(:,hc.reason(8))==double(TdpV1Reason.Geometry),1);
    assertNotEmpty(t,fail,'Expected a real geometry loss, without injected faults.');
    verifyEqual(t,q(fail,c.feedbackId(8)),q(fail,c.requestId(8)));
    verifyEqual(t,q(fail,c.kicker),0);
    verifyEqual(t,q(fail+1,c.takeover(2)),1);
    k=firstRelease(t,q,c,2);
    firstHealthy=find(h(:,hc.healthTiming(2))==1 & q(:,c.time)>q(fail,c.time),1);
    assertNotEmpty(t,firstHealthy);
    % A 0.50 s interval occupies 10 complete 50 ms or 13 complete 40 ms steps.
    completeIntervals=ceil(P.v1RecoveryHealthySeconds/dt-1e-10);
    verifyEqual(t,k-firstHealthy,completeIntervals);
    verifyEqual(t,q(k,c.time)-q(firstHealthy,c.time),completeIntervals*dt,'AbsTol',1e-10);
    record('natural-geometry-return',dt,2,8,q,h,[fail fail+1 firstHealthy k-1 k]);
end
end

function testLegalKickFinishesBeforeHandback(t)
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    [P,world]=inFlightFixture(dt);
    [trace,q,h]=runFixture(P,world);
    held=find(q(:,c.recovering(1))==1 & q(:,c.chaser(1))==3);
    assertNotEmpty(t,held,'MF must already have a legal request when ST stabilizes.');
    id=q(held(1),c.requestId(3));
    verifyGreaterThan(t,id,0);
    verifyEqual(t,unique(q(held,c.kind(3))),double(TdpAction.Kick));
    verifyEqual(t,unique(q(held,c.requestId(3))),id);
    verifyEqual(t,unique(h(held,hc.releaseId(1))),id);
    verifyEqual(t,unique(h(held,hc.cancelPending(1))),0);
    verifyFalse(t,any(q(held,c.kind(4))==double(TdpAction.Kick)));
    kick=find(q(:,c.kicker)==3 & q(:,c.requestId(3))==id);
    assertEqual(t,numel(kick),1);
    verifyEqual(t,q(kick,c.status(3)),double(TdpStatus.Done));
    verifyEqual(t,q(kick,c.feedbackId(3)),id);
    verifyGreaterThan(t,trace(kick,57),trace(kick-1,57));
    verifyEqual(t,trace(kick,51),double(TdpRole.MF));
    verifyEqual(t,q(kick+1,c.chaser(1)),4);
    verifyEqual(t,q(kick+1,c.takeover(1)),0);
    record('finish-original-mf-kick',dt,1,3,q,h,[held(1) kick kick+1]);
end
end

function testUnsafePendingKickIsCanceled(t)
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    for cause={'stopped-game','stale-ball','unavailable-midfielder'}
        [P,world]=inFlightFixture(dt);
        window=[.8 1.28];
        switch cause{1}
            case 'stopped-game', P.v1StopWindow=window;
            case 'stale-ball', P.v1StaleWindow(3,:)=window;
            case 'unavailable-midfielder', P.v1UnavailableWindow(3,:)=window;
        end
        [~,q,h]=runFixture(P,world);
        k=find(q(:,c.time)>=window(1)-1e-10,1);
        verifyEqual(t,q(k-1,c.recovering(1)),1);
        id=q(k-1,c.requestId(3));
        verifyEqual(t,q(k,c.chaser(1)),0);
        verifyEqual(t,q(k,c.kind(3)),double(TdpAction.Stop));
        verifyEqual(t,q(k,c.requestId(3)),id);
        verifyEqual(t,q(k,c.feedbackId(3)),id);
        verifyEqual(t,q(k,c.status(3)),double(TdpStatus.Failed));
        verifyEqual(t,h(k,hc.reason(3)),double(TdpV1Reason.Canceled));
        verifyFalse(t,any(q(k:end,c.kicker)==3 & q(k:end,c.requestId(3))==id));
        if strcmp(cause{1},'stopped-game')
            stopped=q(:,c.running)==0;
            verifyFalse(t,any(q(stopped,c.chaser)~=0,'all'));
        end
        record(cause{1},dt,1,3,q,h,[k-1 k k+1]);
    end
end
end

function testNoTerminalKeepsBothDisarmed(t)
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    [P,world]=inFlightFixture(dt);
    P.v1HealthDropWindow(3,:)=[.76 1.60];
    P.v1StaleWindow(3,:)=[.80 1.08];
    [~,q,h]=runFixture(P,world);
    waiting=q(:,c.time)>=.80-1e-10 & q(:,c.time)<1.60-1e-10;
    id=q(find(waiting,1)-1,c.requestId(3));
    verifyGreaterThan(t,nnz(waiting),5);
    verifyEqual(t,unique(q(waiting,c.chaser(1))),0);
    verifyEqual(t,unique(q(waiting,c.kind(3))),double(TdpAction.Stop));
    verifyEqual(t,unique(q(waiting,c.requestId(3))),id);
    verifyEqual(t,unique(h(waiting,hc.releaseId(1))),id);
    verifyFalse(t,any(q(waiting,c.kind(4))==double(TdpAction.Kick)));
    verifyFalse(t,any(q(:,c.kicker)==3 & q(:,c.requestId(3))==id));
    verifyTrue(t,any(q(q(:,c.time)>1.65,c.takeover(1))==0));
    k=find(waiting,1);j=find(waiting,1,'last');
    record('hold-through-missing-terminal',dt,1,3,q,h,[k j j+1 j+2]);
end
end

function testFaultAndHeartbeatInterruptRecovery(t)
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,4);P.Tmatch=2.4;
    P.v1UnavailableWindow(4,:)=[0 .20];
    P.v1FailWindow(4,:)=[.35 .80];
    P.v1HealthDropWindow(4,:)=[1.04 1.40];
    P.v1RecoveryWindow(1,:)=[.40 1.84];  % Old manual signals cannot override health.
    [~,q,h]=runFixture(P,world);
    fail=q(:,c.time)>=.40 & q(:,c.time)<.75;
    verifyEqual(t,unique(h(fail,hc.ready(4))),0);
    drop=q(:,c.time)>=1.10 & q(:,c.time)<1.35;
    verifyEqual(t,numel(unique(h(drop,hc.stamp(4)))),1);
    k=firstRelease(t,q,c,1);
    expected=1.40+P.v1RecoveryHealthySeconds;
    verifyGreaterThanOrEqual(t,q(k,c.time),expected-1e-10);
    verifyLessThanOrEqual(t,q(k,c.time),expected+2*dt+1e-10);
    verifyEqual(t,q(k,c.chaser(1)),4);
    record('subsystem-clear-heartbeat-drop-return',dt,1,4,q,h,[find(fail,1) find(drop,1) k-1 k]);
end
end

function testOnlyCurrentTerminalReleasesLock(t)
% Seed the actual delay blocks at a cancellation boundary, then perform one step.
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,4);P.Tmatch=dt;
    for event={'wrong-id','old-stamp','cancel-rejected','future-stamp','still-active','matching-terminal'}
        channels=releaseBoundary(P);
        switch event{1}
            case 'wrong-id'
                channels.feedback0(3).requestId=uint32(41);
                channels.health0(3).requestId=uint32(41);
            case 'old-stamp'
                channels.feedback0(3).stamp=-.10;
            case 'cancel-rejected'
                channels.feedback0(3).status=TdpStatus.Rejected;
            case 'future-stamp'
                channels.feedback0(3).stamp=1.0;
            case 'still-active'
                channels.health0(3).activeId=uint32(42);
                channels.health0(3).ready=false;
        end
        [~,q,h]=runFixture(P,world,channels);
        if strcmp(event{1},'matching-terminal')
            verifyEqual(t,q(1,c.chaser(1)),4);
            verifyEqual(t,h(1,hc.releaseId(1)),0);
        else
            verifyEqual(t,q(1,c.chaser(1)),0);
            verifyEqual(t,h(1,hc.releaseId(1)),42);
            verifyEqual(t,q(1,c.kind(3)),double(TdpAction.Stop));
            verifyEqual(t,q(1,c.requestId(3)),42);
        end
        record(event{1},dt,1,3,q,h,1);
    end
end
end

function testExpiredPendingKickIsCanceled(t)
c=v1TraceColumns();hc=v1RecoveryColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,3);P.Tmatch=3*dt;
    channels=releaseBoundary(P);
    channels.v1Memory0.cancelPending=false;
    channels.v1Memory0.chaser=3;
    channels.v1Memory0.releaseStamp=-.5;
    channels.v1Memory0.releaseDeadline=.01;
    channels.request0(3).kind=TdpAction.Kick;
    channels.request0(3).stamp=-.5;
    channels.request0(3).validUntil=.01;
    channels.feedback0(3).status=TdpStatus.Running;
    channels.health0(3).activeId=uint32(42);
    channels.health0(3).ready=false;
    world.actuator(3).active=true;
    world.actuator(3).start=-.5;
    world.actuator(3).seenId=uint32(42);
    world.actuator(3).feedback=channels.feedback0(3);
    [~,q,h]=runFixture(P,world,channels);
    verifyEqual(t,h(1,hc.cancelPending(1)),1);
    verifyEqual(t,q(1,c.kind(3)),double(TdpAction.Stop));
    verifyEqual(t,q(1,c.requestId(3)),42);
    verifyEqual(t,q(1,c.feedbackId(3)),42);
    verifyEqual(t,q(1,c.status(3)),double(TdpStatus.Failed));
    verifyEqual(t,nnz(q(:,c.kicker)),0);
    verifyEqual(t,q(2,c.chaser(1)),4);
    record('expired-locked-request',dt,1,3,q,h,1:2);
end
end

function channels=releaseBoundary(P)
T=tdpTemplates(P);
channels.request0=repmat(T.Request,1,8);
channels.feedback0=repmat(T.Feedback,1,8);
channels.health0=repmat(tdp.v1Health(),1,8);
channels.request0(3).requestId=uint32(42);
channels.feedback0(3).requestId=uint32(42);
channels.feedback0(3).status=TdpStatus.Failed;
channels.health0(3).requestId=uint32(42);
channels.health0(3).reason=TdpV1Reason.Canceled;
m=tdp.recoveryTeamMemory();m.takeover=true;m.recovering=true;
m.cancelPending=true;m.releaseId=uint32(42);m.releaseStamp=0;m.releaseDeadline=1;
m.healthTiming=true;m.healthySince=-1;m.lastHealthyStamp=-P.dt;
channels.v1Memory0=m;
end

function testRecoveryWhileBallUnknown(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,3);
    P.v1UnavailableWindow(4,:)=[0 .3];
    P.v1BlindWindow(:,2)=2.0;
    [~,q,h]=runFixture(P,world);
    k=firstRelease(t,q,c,1);
    verifyEqual(t,q(k,c.phase(1)),double(TdpTeamPhase.Search));
    verifyEqual(t,q(k,c.chaser(1)),4);
    verifyEqual(t,nnz(q(:,c.kicker)),0);
    record('healthy-return-to-search',dt,1,4,q,h,[k-1 k]);
end
end

function k=firstRelease(t,q,c,team)
k=find(diff(q(:,c.takeover(team)))<0,1)+1;
assertNotEmpty(t,k,'A healthy striker must recover without an operator command.');
end

function [P,w]=inFlightFixture(dt)
[P,w]=fixture(dt,3);
P.kickPreparation=.80;           % Expose overlap with the 0.50 s stability window.
P.v1UnavailableWindow(4,:)=[0 .20];
end

function [P,world]=fixture(dt,robot)
P=tdp.recoveryConfig();P.dt=dt;P.Tmatch=2;P.kickNoise=0;
T=tdpTemplates(P);world=T.World;
world.ball.x=2;world.ball.y=0;
world.robots(robot).x=world.ball.x-.245;
world.robots(robot).y=0;world.robots(robot).th=0;
end

function [trace,tactics,health]=runFixture(P,world,channels)
previous=rng;restore=onCleanup(@()rng(previous)); %#ok<NASGU>
rng(P.seed,'twister');
[input,model]=matchSimulationInput(P);
assert(strcmp(model,'tdpRecoveryMatch'),'The recovery profile must select its own model.');
input=input.setVariable('world0',world,'Workspace',model);
if nargin>2
    for field=fieldnames(channels)'
        key=field{1};input=input.setVariable(key,channels.(key),'Workspace',model);
    end
end
output=sim(input);
trace=recordRows(output.records);
tactics=recordRows(output.tacticsRecords);
health=recordRows(output.recoveryRecords);
end

function record(label,dt,team,robot,q,h,k)
c=v1TraceColumns();hc=v1RecoveryColumns();
row=struct('case',label,'dt',dt,'team',team,'robot',robot, ...
    'tSim',q(k,c.time)','owner',q(k,c.chaser(team))','takeover',q(k,c.takeover(team))', ...
    'recovering',q(k,c.recovering(team))','releaseId',h(k,hc.releaseId(team))', ...
    'kind',q(k,c.kind(robot))','requestId',q(k,c.requestId(robot))', ...
    'status',q(k,c.status(robot))','feedbackId',q(k,c.feedbackId(robot))', ...
    'reason',h(k,hc.reason(robot))','ready',h(k,hc.ready(robot))','heartBeatStamp',h(k,hc.stamp(robot))', ...
    'kicker',q(k,c.kicker)');
fprintf('RECOVERY_CASE %s\n',jsonencode(row));
end
