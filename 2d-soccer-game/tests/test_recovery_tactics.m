function tests=test_recovery_tactics
tests=functiontests(localfunctions);
end

function testReplacementIdCannotTakeOverDrainingKick(t)
% The previous feedback can be missing even when the executor still owns ID 17.
P=tdp.v1Config();P.v1AutoRecovery=true;
templates=tdpTemplates(P);
world=templates.World;world.referee.t=1;
obs=V1Observation2D(world,1,P);
blue=tdp.v1TeamMemory();blue.chaser=3;blue.recovering=true;
blue.releaseId=uint32(17);blue.cancelPending=false;blue.releaseDeadline=1.8;
red=blue;red.chaser=8;red.recovering=false;red.releaseId=uint32(0);
plans=repmat(templates.Intent,1,8);plans(3).type=TdpAction.Kick;
raw=repmat(templates.Request,1,8);raw(3).kind=TdpAction.Kick;
raw(3).requestId=uint32(18);raw(3).stamp=.8;raw(3).validUntil=1.8;
previous=raw;previous(3).requestId=uint32(17);
feedback=repmat(templates.Feedback,1,8);
effective=V1AuthorizeRequests(raw,plans,obs,blue,red,previous,feedback,P);
verifyEqual(t,effective(3).kind,TdpAction.Stop);
verifyEqual(t,effective(3).requestId,uint32(17));
end

function testAutomaticRecoveryUsesTimeAndKeepsSearch(t)
for dt=[.05 .04]
    for team=1:2
        [P,w,q,f,h,m]=fixture(dt);
        st=4*team;mf=st-1;
        m.chaser=st;
        q(st)=kick(q(st),42,.8,1.8);
        f(st)=report(42,TdpStatus.Failed,1);
        h(st).reason=TdpV1Reason.Geometry;h(st).requestId=uint32(42);
        [o,h]=sample(w,P,h,1);
        [~,m]=tdp.v1TeamPlans(o,team,m,q,f,false,P,h);
        verifyTrue(t,m.takeover);verifyTrue(t,m.failed);
        verifyEqual(t,m.failureReason,TdpV1Reason.Geometry);
        verifyEqual(t,m.chaser,mf);
        q(st).kind=TdpAction.Stop;
        for k=0:ceil(P.v1RecoveryHealthySeconds/dt)
            now=1+(k+1)*dt;
            [o,h]=sample(w,P,h,now);
            for i=1:8,o(i).ballValid=false;end
            [p,m]=tdp.v1TeamPlans(o,team,m,q,f,false,P,h);
            if k*dt+1e-10<P.v1RecoveryHealthySeconds
                verifyTrue(t,m.takeover);verifyEqual(t,m.chaser,mf);
            else
                verifyFalse(t,m.takeover);verifyEqual(t,m.chaser,st);
                verifyEqual(t,p(4).type,TdpAction.Search);
            end
        end
    end
end
end

function testHardFaultAndStaleHeartbeatRestartDwell(t)
[P,w,q,f,h,m]=fixture(.05);
m.takeover=true;m.chaser=3;
for k=0:35
    now=1+k*P.dt;
    [o,h]=sample(w,P,h,now);
    if k<=3,h(4).ready=false;else,h(4).ready=true;end
    if k>=8 && k<=20,h(4).stamp=1+7*P.dt;end
    if k==23,o(4).selfValid=false;end
    if k==24,h(4).activeId=uint32(50);else,h(4).activeId=uint32(0);end
    [~,m]=tdp.v1TeamPlans(o,1,m,q,f,true,P,h);
    if k<35
        verifyTrue(t,m.takeover);
    else
        verifyFalse(t,m.takeover);
    end
end
end

function testNaturalCompletionKeepsOneIdAndRestoresPhase(t)
for dt=[.05 .04]
    [P,w,q,f,h,m]=fixture(dt);
    [o,h]=sample(w,P,h,1);m=qualified(m,dt);
    q(3)=kick(q(3),17,.8,1.4);
    f(3)=report(17,TdpStatus.Running,.8);
    h(3).activeId=uint32(17);h(3).ready=false;h(3).requestId=uint32(17);
    [plans,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
    verifyTrue(t,m.recovering);verifyFalse(t,m.cancelPending);
    verifyEqual(t,m.chaser,3);verifyEqual(t,m.releaseId,uint32(17));
    verifyEqual(t,[plans(3:4).type],[TdpAction.Kick TdpAction.Stop]);
    eff=V1AuthorizeRequests(q,[plans plans],o,m,m,q,f,P);
    verifyEqual(t,eff(3),q(3));
    [o,h]=sample(w,P,h,1+dt);
    h(3).ready=true;h(3).activeId=uint32(0);
    f(3)=report(17,TdpStatus.Done,1+dt);
    for i=1:8,o(i).ball.x=-1.9;o(i).ball.y=1.4;end
    [~,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
    verifyFalse(t,m.takeover);verifyEqual(t,m.phase,TdpTeamPhase.Defend);
    verifyEqual(t,m.chaser,0);
end
end

function testAllInvalidationsStopTheOriginalId(t)
[P,w,q,f,h,initial]=fixture(.05);
q(3)=kick(q(3),17,.8,1.10);
f(3)=report(17,TdpStatus.Running,.8);
h(3).activeId=uint32(17);h(3).requestId=uint32(17);h(3).ready=false;
[o,h]=sample(w,P,h,1);
[~,live]=tdp.v1TeamPlans(o,1,qualified(initial,P.dt),q,f,false,P,h);
for condition=1:5
    now=1+P.dt;
    if condition==5,now=1.15;end
    [o,h]=sample(w,P,h,now);
    switch condition
        case 1,for i=1:8,o(i).gameRunning=false;end
        case 2,o(3).ballValid=false;
        case 3,o(3).selfValid=false;
        case 4,o(3).ballStamp=now-P.maxObservationAge-.1;
    end
    [plans,lock]=tdp.v1TeamPlans(o,1,live,q,f,true,P,h);
    verifyTrue(t,lock.takeover);verifyTrue(t,lock.cancelPending);
    verifyEqual(t,lock.chaser,0);verifyEqual(t,lock.releaseId,uint32(17));
    raw=q;raw(3).requestId=uint32(75);raw(3).kind=TdpAction.Goto;
    eff=V1AuthorizeRequests(raw,[plans plans],o,lock,initial,q,f,P);
    verifyEqual(t,eff(3).kind,TdpAction.Stop);verifyEqual(t,eff(3).requestId,uint32(17));
end
end

function testDropRejectWrongIdAndOldAckCannotRelease(t)
[P,w,q,f,h,initial]=fixture(.05);
q(3)=kick(q(3),17,.75,2);
f(3)=report(17,TdpStatus.Running,.75);
h(3).activeId=uint32(17);h(3).requestId=uint32(17);h(3).ready=false;
[o,h]=sample(w,P,h,1);[~,m]=tdp.v1TeamPlans(o,1,qualified(initial,P.dt),q,f,false,P,h);
o(3).ballValid=false;[~,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
verifyTrue(t,m.cancelPending);
q(3).kind=TdpAction.Stop;h(3).ready=true;h(3).activeId=uint32(0);
for k=1:7
    now=1+k*P.dt;
    [o,h]=sample(w,P,h,now);
    f(3)=report(17,TdpStatus.Failed,now);
    switch k
        case 1,f(3).status=TdpStatus.Rejected;
        case 2,f(3).requestId=uint32(16);
        case 3,f(3).stamp=.90;
        case 4,f(3).stamp=now+P.dt;
        case 5,h(3).stamp=now-2*P.dt;
        case 6,f(3).status=TdpStatus.None;
        case 7,h(3).requestId=uint32(78);
    end
    [~,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
    verifyTrue(t,m.recovering);verifyEqual(t,m.releaseId,uint32(17));
    verifyEqual(t,m.chaser,0);
end
% The latest actuator heartbeat certifies the cached result after service returns.
[o,h]=sample(w,P,h,4);h(3).requestId=uint32(17);
f(3)=report(17,TdpStatus.Failed,1.05);
[~,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
verifyEqual(t,m.releaseId,uint32(0));
% The striker heartbeat also had a gap. Its own dwell must start again.
verifyTrue(t,m.takeover);verifyFalse(t,m.recovering);
end

function testOldKickRetainedBeforeStrikerQualifies(t)
[P,w,q,f,h,m]=fixture(.05);m.takeover=true;m.chaser=3;
q(3)=kick(q(3),17,.8,1.2);f(3)=report(17,TdpStatus.Running,.8);
h(3).activeId=uint32(17);h(3).ready=false;h(3).requestId=uint32(17);
for k=0:11
    now=1+k*P.dt;[o,h]=sample(w,P,h,now);
    if k>0
        q(3).kind=TdpAction.Goto;q(3).requestId=uint32(72);
        f(3)=report(0,TdpStatus.None,0);
    end
    [~,m]=tdp.v1TeamPlans(o,1,m,q,f,false,P,h);
    verifyTrue(t,m.takeover);verifyEqual(t,m.releaseId,uint32(17));
end
verifyTrue(t,m.cancelPending);verifyEqual(t,m.chaser,0);
end

function m=qualified(m,dt)
m.takeover=true;m.chaser=3;
m.healthTiming=true;m.healthySince=.45;m.lastHealthyStamp=1-dt;
end

function [P,w,q,f,h,m]=fixture(dt)
P=tdp.recoveryConfig();P.dt=dt;
z=tdpTemplates(P);w=z.World;q=repmat(z.Request,1,8);f=repmat(z.Feedback,1,8);
h=repmat(tdp.v1Health(),1,8);m=tdp.recoveryTeamMemory();
end

function [o,h]=sample(w,P,h,now)
w.referee.t=now;
o=V1Observation2D(w,now,P);
for i=1:8,h(i).stamp=now;end
end

function r=kick(r,id,stamp,expiry)
r.kind=TdpAction.Kick;r.requestId=uint32(id);r.stamp=stamp;r.validUntil=expiry;
end

function f=report(id,status,stamp)
f=struct('requestId',uint32(id),'status',status,'stamp',stamp);
end
