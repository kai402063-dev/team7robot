function tests = test_v1_tactics
tests = functiontests(localfunctions);
end

function testFixedRolesAndOpening(t)
[P,o,q,f,m] = scenario();
for team=1:2
    [p,n] = tdp.v1TeamPlans(o,team,m,q,f,false,P);
    verifyEqual(t,[p.role],[TdpRole.GK TdpRole.DF TdpRole.MF TdpRole.ST]);
    verifyEqual(t,n.phase,TdpTeamPhase.Attack);
    verifyEqual(t,n.chaser,4*team);
    verifyEqual(t,n.ballSource,1+4*(team-1));
    verifyEqual(t,[p.type],[TdpAction.Goto TdpAction.Goto TdpAction.Goto TdpAction.Kick]);
    verifyEqual(t,p(4).speed,P.dribbleSpeed);
end
o = ballAt(o,[2.8 0],[0 0]);
[p,~] = tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,p(4).speed,P.shotSpeed);
verifyEqual(t,p(4).target,[P.L/2 0]);
verifyLessThan(t,p(3).target(1),o(4).robots(4).x);
end

function testGoalCoverageAndOpenWing(t)
[P,o,q,f,m]=scenario();
o=ballAt(o,[2 1],[0 0]);
for i=1:8
    o(i).robots(4).x=1.5;o(i).robots(4).y=.2;
    % Occupy the left support point; the MF should choose the right wing.
    o(i).robots(5).x=.8;o(i).robots(5).y=1;
end
[p,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,p(1).target,[-4.15 .5],'AbsTol',1e-12);
verifyEqual(t,p(3).target,[.8 -.6],'AbsTol',1e-12);
verifyLessThan(t,p(2).target(1),0);
o=ballAt(o,[2 -2.8],[0 0]);
[p,~]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,p(1).target(2),-P.goalW/2+P.robotR,'AbsTol',1e-12);
end

function testBoundaryAndHysteresis(t)
[P,o,q,f,initial] = scenario();
for team=1:2
    m=initial;
    m.basePhase=TdpTeamPhase.Defend;
    x=[-.2 .04 .15 .16 -.10 -.15 -.16];
    want=[1 1 1 2 2 2 1];
    for k=1:numel(x)
        o=ballAt(o,[P.dirSign(team)*x(k) 0],[0 0]);
        [~,m]=tdp.v1TeamPlans(o,team,m,q,f,false,P);
        verifyEqual(t,double(m.phase),want(k));
    end
end
end

function testDefendAndDesignatedLooseBall(t)
[P,o,q,f,m]=scenario();
o=ballAt(o,[-2 -.9],[0 0]);
[p,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,n.phase,TdpTeamPhase.Defend);
verifyEqual(t,n.chaser,3);
verifyEqual(t,p(3).type,TdpAction.Kick);
verifyEqual(t,p(4).type,TdpAction.Goto);
verifyLessThan(t,p(2).target(1),0);
cases={o,o,o};
cases{1}=ballAt(o,[-2 -.9],[P.v1LooseSpeed+.01 0]);
for i=1:8
    cases{2}(i).robots(8).x=-2+.1;
    cases{2}(i).robots(8).y=-.9;
    cases{3}(i).robotValid(8)=false;
end
for k=1:numel(cases)
    [p,n]=tdp.v1TeamPlans(cases{k},1,m,q,f,false,P);
    verifyEqual(t,n.chaser,0);
    verifyEqual(t,p(3).type,TdpAction.Goto);
    verifyEqual(t,p(3).target,[-P.v1ScreenDepth -.45],'AbsTol',1e-12);
end
end

function testUnknownDoesNotLeakBall(t)
[P,o,q,f,m]=scenario();
a=o;b=o;
for i=1:8
    a(i).ballValid=false;b(i).ballValid=false;
end
a=ballAt(a,[4 2],[.1 .2]);
b=ballAt(b,[NaN -2],[NaN NaN]);
[pa,ma]=tdp.v1TeamPlans(a,1,m,q,f,false,P);
[pb,mb]=tdp.v1TeamPlans(b,1,m,q,f,false,P);
verifyEqual(t,pa,pb);
verifyEqual(t,ma,mb);
verifyEqual(t,ma.phase,TdpTeamPhase.Search);
verifyEqual(t,[pa.type],[TdpAction.Goto TdpAction.Goto TdpAction.Goto TdpAction.Search]);
verifyEqual(t,ma.ballSource,0);
a(3).ballValid=true;
[~,n]=tdp.v1TeamPlans(a,1,m,q,f,false,P);
verifyEqual(t,n.phase,TdpTeamPhase.Attack);
verifyEqual(t,n.ballSource,3);
end

function testSelectFreshLocalSource(t)
[P,o,q,f,m]=scenario();
for i=1:4,o(i).ballStamp=0;end
o(1).ballStamp=1-P.maxObservationAge;
[~,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,n.ballSource,1);
o(1).ballStamp=o(1).ballStamp-.001;
o(2).ballStamp=1.05;
o(3).ballStamp=NaN;
o(4).ballStamp=.9;
o(4).selfValid=false;
[~,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyFalse(t,n.ballKnown);
verifyEqual(t,n.phase,TdpTeamPhase.Search);
verifyEqual(t,n.chaser,3);
o(4).selfValid=true;
o(1).ballStamp=.85;
[~,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,n.ballSource,4);
o(2).ballStamp=.9;
[~,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyEqual(t,n.ballSource,2);
end

function testFeedbackCorrelationAndDuplicates(t)
[P,o,q,f,m]=scenario();
m.chaser=4;
q(4).kind=TdpAction.Kick;q(4).requestId=uint32(42);
q(4).stamp=.5;q(4).validUntil=1.5;
f(4)=struct('requestId',uint32(42),'status',TdpStatus.Failed,'stamp',.9);
for fault=1:7
    fi=f;qi=q;mi=m;
    switch fault
        case 1,fi(4).requestId=uint32(41);
        case 2,fi(4).stamp=.1;
        case 3,fi(4).stamp=2;
        case 4,fi(4).status=TdpStatus.Rejected;
        case 5,qi(4).kind=TdpAction.Stop;
        case 6,fi(8)=fi(4);fi(4).status=TdpStatus.None;
        case 7,mi.chaser=3;
    end
    [~,actual]=tdp.v1TeamPlans(o,1,mi,qi,fi,false,P);
    verifyFalse(t,actual.failed);
    verifyFalse(t,actual.takeover);
end
[p,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyTrue(t,n.failed);verifyTrue(t,n.takeover);
verifyEqual(t,n.phase,TdpTeamPhase.Fallback);
verifyEqual(t,n.handledFailureId,uint32(42));
verifyEqual(t,n.chaser,3);verifyEqual(t,p(3).role,TdpRole.MF);
verifyEqual(t,p(3).type,TdpAction.Kick);verifyEqual(t,p(4).type,TdpAction.Stop);
[~,restored]=tdp.v1TeamPlans(o,1,n,q,f,true,P);
verifyFalse(t,restored.failed);verifyFalse(t,restored.takeover);
[~,again]=tdp.v1TeamPlans(o,1,restored,q,f,false,P);
verifyFalse(t,again.failed);
end

function testPendingKickMustReleaseBeforeRecovery(t)
[P,o,q,f,m]=scenario();
m.takeover=true;m.failed=true;m.chaser=3;
q(3).kind=TdpAction.Kick;q(3).requestId=uint32(17);q(3).stamp=.8;
f(3)=struct('requestId',uint32(17),'status',TdpStatus.Running,'stamp',.8);
[p,n]=tdp.v1TeamPlans(o,1,m,q,f,true,P);
verifyTrue(t,n.recovering);verifyEqual(t,n.releaseId,uint32(17));
verifyEqual(t,n.chaser,0);
verifyEqual(t,[p(3:4).type],[TdpAction.Stop TdpAction.Stop]);
q(3).kind=TdpAction.Stop;
f(3).status=TdpStatus.Failed;f(3).stamp=.9;
[~,early]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyTrue(t,early.recovering);
f(3).stamp=1;f(3).requestId=uint32(18);
[~,wrong]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyTrue(t,wrong.recovering);
f(3).requestId=uint32(17);
[p,done]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyFalse(t,done.recovering);verifyFalse(t,done.takeover);
verifyEqual(t,done.chaser,4);verifyEqual(t,p(3).type,TdpAction.Goto);
end

function testUnavailableAndPause(t)
[P,o,q,f,m]=scenario();
o(4).selfValid=false;
[~,n]=tdp.v1TeamPlans(o,1,m,q,f,false,P);
verifyTrue(t,n.takeover);verifyFalse(t,n.failed);verifyEqual(t,n.chaser,3);
o(4).selfValid=true;
[~,n]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyTrue(t,n.takeover);
for i=1:8,o(i).ballValid=false;end
[p,n]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyEqual(t,n.phase,TdpTeamPhase.Search);
verifyEqual(t,n.chaser,3);verifyEqual(t,p(3).type,TdpAction.Search);
o(3).selfValid=false;
[p,n]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyEqual(t,n.chaser,0);verifyEqual(t,[p(3:4).type],[TdpAction.Stop TdpAction.Stop]);
for i=1:8,o(i).gameRunning=false;end
[p,n]=tdp.v1TeamPlans(o,1,n,q,f,false,P);
verifyEqual(t,n.phase,TdpTeamPhase.Hold);
verifyEqual(t,[p.type],repmat(TdpAction.Stop,1,4));
end

function testMirrorAndAuthorizationAcrossPitch(t)
[P,o,q,f,m]=scenario();
saved=rng;cleanup=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(817,'twister');
for sample=1:1000
    ball=([P.L P.W]-2*P.ballR).*(rand(1,2)-.5);
    velocity=rand(1,2)-.5;
    blue=ballAt(o,ball,velocity);
    red=ballAt(o,-ball,-velocity);
    for idx=1:8
        mirror=mod(idx+3,8)+1;
        xy=([P.L P.W]-2*P.robotR).*(rand(1,2)-.5);
        for j=1:8
            blue(j).robots(idx).x=xy(1);blue(j).robots(idx).y=xy(2);
            red(j).robots(mirror).x=-xy(1);red(j).robots(mirror).y=-xy(2);
        end
    end
    [p,b]=tdp.v1TeamPlans(blue,1,m,q,f,false,P);
    [r,d]=tdp.v1TeamPlans(red,2,m,q,f,false,P);
    verifyEqual(t,b.phase,d.phase);verifyEqual(t,[p.role],[r.role]);
    verifyEqual(t,[p.type],[r.type]);verifyEqual(t,[p.target],-[r.target],'AbsTol',1e-12);
    verifyLessThanOrEqual(t,sum([p.type]==TdpAction.Kick),1);
    if b.chaser~=0,verifyEqual(t,d.chaser,b.chaser+4);else,verifyEqual(t,d.chaser,0);end
end
end

function testConfigAndWindowShapes(t)
P=tdp.v1Config();
verifyEqual(t,tdp.validateV1Config(P),P);
verifyEqual(t,P.mode,TdpMode.Delayed);
verifyEqual(t,P.rulesProfile,TdpRules.CourseSimplified);
bad=P;bad.mode=TdpMode.Compat;
verifyError(t,@()tdp.validateV1Config(bad),'TDP:V1Mode');
bad=P;bad.v1BlindWindow=zeros(2,8);
verifyError(t,@()tdp.validateV1Config(bad),'TDP:V1Window');
bad=P;bad.v1RecoveryWindow(1,:)=[2 1];
verifyError(t,@()tdp.validateV1Config(bad),'TDP:V1Window');
bad=P;bad.v1MidlineBand=P.L/2;
verifyError(t,@()tdp.validateV1Config(bad),'TDP:V1Config');
end

function [P,o,q,f,m]=scenario()
P=tdp.v1Config();T=tdpTemplates(P);w=T.World;
w.referee.t=1;
o=repmat(T.Observation,1,8);
for i=1:8,o(i)=Observation2D(w,i,1,P);end
q=repmat(T.Request,1,8);
f=repmat(T.Feedback,1,8);
m=tdp.v1TeamMemory();
end

function o=ballAt(o,xy,velocity)
for i=1:8
    o(i).ball.x=xy(1);o(i).ball.y=xy(2);
    o(i).ball.vx=velocity(1);o(i).ball.vy=velocity(2);
end
end
