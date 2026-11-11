function tests=test_v11_fallback()
%TEST_V11_FALLBACK Repeated-failure takeover and timed hand-back (V1.1 proposal).
% Rules under test come from the team's Draft v1.1 sheet, section 6(d) and T7,
% which is a proposal pending team approval.
tests=functiontests(localfunctions);
end

function testSingleFailureKeepsStriker(t)
[P,o,q,f,m,s,v]=scenario();
[o,q,f]=strikerResult(o,q,f,42,1.0,TdpStatus.Failed);
[p,n,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyFalse(t,n.takeover);verifyFalse(t,n.failed);
verifyEqual(t,n.phase,TdpTeamPhase.Attack);
verifyEqual(t,n.chaser,4);verifyEqual(t,p(4).type,TdpAction.Kick);
verifyEqual(t,n.handledFailureId,uint32(42));verifyEqual(t,v(1),1);
% A repeated delivery of the same terminal result is counted once.
[~,again,v]=tdp.v1TeamPlans(o,1,n,q,f,false,P,s,v);
verifyFalse(t,again.takeover);verifyEqual(t,v(1),1);
end

function testThirdConsecutiveFailureTakesOver(t)
[P,o,q,f,m,s,v]=scenario();
stamps=[1 5 9];
for k=1:3
    [o,q,f]=strikerResult(o,q,f,41+k,stamps(k),TdpStatus.Failed);
    [p,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
    verifyEqual(t,m.takeover,k==3);
end
verifyTrue(t,m.failed);verifyEqual(t,m.phase,TdpTeamPhase.Fallback);
verifyEqual(t,m.chaser,3);
verifyEqual(t,[p(3:4).type],[TdpAction.Kick TdpAction.Stop]);
verifyEqual(t,p(3).role,TdpRole.MF);
end

function testSuccessResetsTheCount(t)
[P,o,q,f,m,s,v]=scenario();
results={1,TdpStatus.Failed;5,TdpStatus.Failed;7,TdpStatus.Done;9,TdpStatus.Failed};
for k=1:size(results,1)
    [o,q,f]=strikerResult(o,q,f,41+k,results{k,1},results{k,2});
    [~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
end
verifyFalse(t,m.takeover);verifyEqual(t,v(1),1);
for k=1:2
    [o,q,f]=strikerResult(o,q,f,45+k,9+2*k,TdpStatus.Failed);
    [~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
end
verifyTrue(t,m.takeover);
end

function testWindowSlidesOverTheLastFailures(t)
[P,o,q,f,m,s,v]=scenario();
stamps=[1 12 22];
for k=1:3
    [o,q,f]=strikerResult(o,q,f,41+k,stamps(k),TdpStatus.Failed);
    [~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
end
verifyFalse(t,m.takeover,'Three failures spanning 21 s exceed the 20 s window.');
[o,q,f]=strikerResult(o,q,f,45,25,TdpStatus.Failed);
[~,m,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyTrue(t,m.takeover,'The last three failures (12, 22, 25 s) lie within 20 s.');
end

function testHandBackAfterRecoverSeconds(t)
[P,o,q,f,m,s,v,start]=takenOver();
[o,q,f]=idle(o,q,f,start+P.v11RecoverSeconds-P.dt);
[~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyTrue(t,m.takeover);
[o,q,f]=idle(o,q,f,start+P.v11RecoverSeconds);
[p,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyFalse(t,m.takeover);verifyFalse(t,m.failed);verifyFalse(t,m.recovering);
verifyEqual(t,m.phase,TdpTeamPhase.Attack);verifyEqual(t,m.chaser,4);
verifyEqual(t,p(4).type,TdpAction.Kick);verifyEqual(t,p(3).type,TdpAction.Goto);
verifyEqual(t,v(1),0);
end

function testNoHandBackWhileMidfielderAlignsOrKicks(t)
[P,o,q,f,m,s,v,start]=takenOver();
[o,q,f]=idle(o,q,f,start+P.v11RecoverSeconds+1);
for busy=[TdpPhase.Align TdpPhase.Kick]
    s(3)=double(busy);
    [~,held,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
    verifyTrue(t,held.takeover);verifyEqual(t,held.chaser,3);
end
s(3)=double(TdpPhase.Recover);
[~,m,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyFalse(t,m.takeover);
end

function testUnavailableStrikerTakesOverAndRestartsTimer(t)
[P,o,q,f,m,s,v]=scenario();
o=at(o,1);o(4).selfValid=false;
[p,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyTrue(t,m.takeover);verifyFalse(t,m.failed);verifyEqual(t,m.chaser,3);
verifyEqual(t,p(4).type,TdpAction.Stop);
o=at(o,2);o(4).selfValid=true;
[~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyTrue(t,m.takeover);
o=at(o,2+P.v11RecoverSeconds-P.dt);
[~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyTrue(t,m.takeover);
o=at(o,2+P.v11RecoverSeconds);
[~,m,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyFalse(t,m.takeover);
end

function testWithoutTheOptionTheCoordinatorIsUnchanged(t)
[~,o,q,f,m,s,v]=scenario();
P=tdp.v1Config();
verifyFalse(t,isfield(P,'v11Fallback'));
[o,q,f]=strikerResult(o,q,f,42,1.0,TdpStatus.Failed);
[p7,m7]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
[p9,m9,v9]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
verifyEqual(t,p9,p7);verifyEqual(t,m9,m7);verifyEqual(t,v9,v);
verifyTrue(t,m7.takeover,'Approved V1 keeps the single-failure takeover.');
end

function testConfigValidation(t)
P=tdp.v11FallbackConfig();
verifyEqual(t,tdp.validateV1Config(P),P);
verifyEqual(t,[P.v11FailCount P.v11FailWindow P.v11RecoverSeconds],[3 20 3]);
verifyTrue(t,P.v11Fallback);
cases={'v11FailCount',0;'v11FailCount',9;'v11FailCount',2.5; ...
    'v11FailWindow',0;'v11RecoverSeconds',-1;'v11Fallback',1};
for k=1:size(cases,1)
    bad=P;bad.(cases{k,1})=cases{k,2};
    verifyError(t,@()tdp.validateV1Config(bad),'TDP:V11Config',cases{k,1});
end
bad=tdp.recoveryConfig();bad.v11Fallback=true;bad.v11FailCount=3;
bad.v11FailWindow=20;bad.v11RecoverSeconds=3;
verifyError(t,@()tdp.validateV1Config(bad),'TDP:V11Config');
end

function testModelThirdForcedFailureTakesOver(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,8);
    q=runFixture(P,world);
    failures=strikerFailures(q,c);
    assertGreaterThanOrEqual(t,numel(failures),3,'Fixture must produce three ST failures.');
    third=failures(3);
    verifyEqual(t,q(1:third,c.takeover(1)),zeros(third,1));
    verifyEqual(t,q(third+1,c.takeover(1)),1);
    verifyEqual(t,q(third+1,c.chaser(1)),3);
    verifyEqual(t,q(third+1,c.phase(1)),double(TdpTeamPhase.Fallback));
    verifyEqual(t,q(failures(1)+1,c.chaser(1)),4,'One failure must not move the token.');
    checkInvariants(t,q,c);
end
end

function testModelHandBackAfterRecoverSeconds(t)
c=v1TraceColumns();
for dt=[.05 .04]
    [P,world]=fixture(dt,14);
    q=runFixture(P,world);
    entry=find(diff(q(:,c.takeover(1)))==1,1)+1;
    assertNotEmpty(t,entry);
    exit=find(diff(q(entry:end,c.takeover(1)))==-1,1)+entry;
    assertNotEmpty(t,exit,'The striker must be handed back within the fixture.');
    verifyGreaterThanOrEqual(t,q(exit,c.time)-q(entry,c.time),P.v11RecoverSeconds-1e-9);
    busy=[double(TdpPhase.Align) double(TdpPhase.Kick)];
    verifyFalse(t,ismember(q(exit-1,c.skill(3)),busy),'No hand-back while MF aligns or kicks.');
    verifyEqual(t,q(exit,c.chaser(1)),4);
    checkInvariants(t,q,c);
end
end

% ---- helpers ---------------------------------------------------------------

function [P,o,q,f,m,s,v]=scenario()
P=tdp.v11FallbackConfig();T=tdpTemplates(P);w=T.World;
w.referee.t=1;
o=repmat(T.Observation,1,8);
for i=1:8,o(i)=Observation2D(w,i,1,P);end
q=repmat(T.Request,1,8);
f=repmat(T.Feedback,1,8);
m=tdp.v1TeamMemory();m.chaser=4;
s=repmat(double(TdpPhase.Approach),1,8);
v=tdp.v11FallbackMemory();
end

function [P,o,q,f,m,s,v,start]=takenOver()
[P,o,q,f,m,s,v]=scenario();
stamps=[1 2 3];
for k=1:3
    [o,q,f]=strikerResult(o,q,f,41+k,stamps(k),TdpStatus.Failed);
    [~,m,v]=tdp.v1TeamPlans(o,1,m,q,f,false,P,s,v);
end
assert(m.takeover);start=o(1).tSim;
end

function o=at(o,tt)
for i=1:8
    o(i).tSim=tt;o(i).robotStamp(:)=tt;o(i).ballStamp=tt;
end
end

function [o,q,f]=strikerResult(o,q,f,id,stamp,status)
% The coordinator at stamp+dt reads last tick's ST kick request and its result.
o=at(o,stamp+.05);
q(4).kind=TdpAction.Kick;q(4).requestId=uint32(id);
q(4).stamp=stamp-.2;q(4).validUntil=stamp+.8;
f(4)=struct('requestId',uint32(id),'status',status,'stamp',stamp);
end

function [o,q,f]=idle(o,q,f,tt)
o=at(o,tt);
q(4).kind=TdpAction.Stop;q(4).requestId=uint32(0);
end

function [P,world]=fixture(dt,duration)
P=tdp.v11FallbackConfig();P.dt=dt;P.Tmatch=duration;P.kickNoise=0;
P.v1FailWindow(4,:)=[0 duration+dt];
T=tdpTemplates(P);world=T.World;
world.ball.x=2;world.ball.y=0;
world.robots(4).x=world.ball.x-.245;world.robots(4).y=0;world.robots(4).th=0;
end

function tactics=runFixture(P,world)
[input,model]=matchSimulationInput(P);
assert(strcmp(model,'tdpV1Match'));
input=input.setVariable('world0',world,'Workspace',model);
output=sim(input);tactics=recordRows(output.tacticsRecords);
end

function rows=strikerFailures(q,c)
failed=q(:,c.status(4))==double(TdpStatus.Failed) & q(:,c.kind(4))==double(TdpAction.Kick);
rows=find(failed & [true;q(2:end,c.feedbackId(4))~=q(1:end-1,c.feedbackId(4)) | ...
    q(1:end-1,c.status(4))~=double(TdpStatus.Failed)]);
end

function checkInvariants(t,q,c)
for team=1:2
    ids=(1:4)+4*(team-1);
    kicks=ismember(q(:,c.kind(ids)),double([TdpAction.Kick TdpAction.Tap]));
    verifyLessThanOrEqual(t,max(sum(kicks,2)),1,'At most one kick request per team.');
    owner=q(:,c.chaser(team));
    for k=1:4
        verifyFalse(t,any(kicks(:,k) & owner~=ids(k)),'Only the chaser may request a kick.');
    end
end
verifyFalse(t,any(q(:,c.kicker)==4),'Forced failures must never kick.');
end
