function tests=test_recovery_actuator
tests=functiontests(localfunctions);
end

function testWrongNumberCannotCancelAnActiveKick(tc)
[P,T,obs,req]=fixture();
[m,fb]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
verifyEqual(tc,fb.status,TdpStatus.Running);
wrong=req;
wrong.kind=TdpAction.Stop;
wrong.requestId=uint32(8);
[m,fb]=Actuator2D(m,wrong,obs,.05,P,true,0,false);
verifyTrue(tc,m.active);
verifyEqual(tc,fb.requestId,uint32(8));
verifyEqual(tc,fb.status,TdpStatus.Rejected);
end

function [P,T,obs,req]=fixture()
P=tdp.v1Config();
P.v1AutoRecovery=true;
P.v1RecoveryHealthySeconds=.5;
P.v1HealthDropWindow=zeros(8,2);
T=tdpTemplates(P);
sc=makeScenario(P,1);
obs=sc(1).obs;
req=T.Request;
req.kind=TdpAction.Kick;
req.requestId=uint32(7);
req.target=[4.5 0];req.speed=1.8;req.validUntil=1;
end

function testOutcomeReasons(tc)
[P,T,obs,req]=fixture();
for expected=[TdpV1Reason.Geometry TdpV1Reason.Arbitration TdpV1Reason.Subsystem TdpV1Reason.None]
    [m,fb]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
    verifyEqual(tc,fb.status,TdpStatus.Running);
    observation=obs;
    if expected==TdpV1Reason.Geometry,observation.ball.x=3.1;end
    [m,fb,~,didKick,~,reason]=Actuator2D(m,req,observation,.2,P, ...
        expected~=TdpV1Reason.Arbitration,0,expected==TdpV1Reason.Subsystem);
    verifyEqual(tc,reason,expected);
    verifyEqual(tc,didKick,expected==TdpV1Reason.None);
    verifyFalse(tc,m.active);
    if didKick,verifyEqual(tc,fb.status,TdpStatus.Done);else,verifyEqual(tc,fb.status,TdpStatus.Failed);end
end
end

function testSameNumberCancelsAndExpiredDuplicatesCannotKick(tc)
[P,T,obs,req]=fixture();
[m,~]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
stop=req;stop.kind=TdpAction.Stop;
[canceled,fb,~,k,~,reason]=Actuator2D(m,stop,obs,.05,P,true,0,false);
verifyFalse(tc,canceled.active);verifyFalse(tc,k);verifyEqual(tc,fb.requestId,req.requestId);
verifyEqual(tc,fb.status,TdpStatus.Failed);verifyEqual(tc,reason,TdpV1Reason.Canceled);
[expired,fb,~,k,~,reason]=Actuator2D(m,req,obs,1.05,P,true,0,false);
verifyFalse(tc,expired.active);verifyFalse(tc,k);verifyEqual(tc,fb.requestId,req.requestId);
verifyEqual(tc,fb.status,TdpStatus.Failed);verifyEqual(tc,reason,TdpV1Reason.Expired);
end

function testHealthyIdleAndSubsystemReset(tc)
[P,T,~,~]=fixture();
P.v1FailWindow(4,:)=[0 .1];
requests=repmat(T.Request,1,8);plans=repmat(T.Intent,1,8);
h0=repmat(tdp.v1Health(),1,8);
[w,fb,k,h]=RecoveryPlant2D(T.World,requests,plans,.05,h0,P);
verifyEqual(tc,[h.stamp],repmat(.05,1,8));
verifyEqual(tc,[h.ready],[true true true false true true true true]);
verifyEqual(tc,[h.activeId],zeros(1,8,'uint32'));verifyEqual(tc,[h.requestId],[fb.requestId]);
verifyEqual(tc,k,0);
[~,~,~,h]=RecoveryPlant2D(w,requests,plans,.1,h,P);
verifyTrue(tc,all([h.ready]));verifyEqual(tc,[h.stamp],repmat(.1,1,8));
end

function testHoldBothMessagesUntilReturn(tc)
[P,T,~,~]=fixture();
P.v1HealthDropWindow(3,:)=[.05 .15];
held=repmat(tdp.v1Health(),1,8);fb=repmat(T.Feedback,1,8);
held(3).activeId=uint32(7);held(3).ready=false;
fb(3).requestId=uint32(7);fb(3).status=TdpStatus.Running;
live=held;live(3).reason=TdpV1Reason.Geometry;live(3).ready=true;
live(3).activeId=uint32(0);live(3).requestId=uint32(7);live(3).stamp=.05;
terminal=fb;terminal(3).status=TdpStatus.Failed;terminal(3).stamp=.05;
[h,f]=RecoveryFeedback2D(live,terminal,held,fb,.1,P);
verifyEqual(tc,h,held);verifyEqual(tc,f,fb);
[h,f]=RecoveryFeedback2D(live,terminal,h,f,.15,P);
verifyEqual(tc,h,live);verifyEqual(tc,f,terminal);
end

function testOldV1AndACompatRetainTheirStopSemantics(tc)
[~,T,obs,req]=fixture();
for newV1=[false true]
    if newV1,P=tdp.v1Config();else,P=tdp.defaultConfig();P.mode=TdpMode.Delayed;end
    [m,~]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
    wrong=req;wrong.kind=TdpAction.Stop;wrong.requestId=uint32(81);
    [m,fb]=Actuator2D(m,wrong,obs,.05,P,true,0,false);
    verifyFalse(tc,m.active);verifyEqual(tc,fb.requestId,req.requestId);
    verifyEqual(tc,fb.status,TdpStatus.Failed);
end
end
