function tests=test_actuator
tests=functiontests(localfunctions);
end
function [P,T,obs,req]=fixture()
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;T=tdpTemplates(P);sc=makeScenario(P,1);obs=sc(1).obs;
req=T.Request;req.kind=TdpAction.Kick;req.requestId=uint32(7);req.target=[4.5 0];req.speed=1.8;req.validUntil=1;
end
function testDuplicateRequest(tc)
[P,T,obs,req]=fixture();m=T.Actuator;count=0;
for t=0:0.05:0.8
 [m,fb,~,kick]=Actuator2D(m,req,obs,t,P,true,0,false);count=count+kick;
end
verifyEqual(tc,m.executions,uint32(1));verifyEqual(tc,count,1);verifyEqual(tc,fb.status,TdpStatus.Done);
end
function testExecutionFailure(tc)
[P,T,obs,req]=fixture();m=T.Actuator;
[m,~,~,~]=Actuator2D(m,req,obs,0,P,true,0,false);
[m,fb,~,kick]=Actuator2D(m,req,obs,0.2,P,true,0,true);
verifyEqual(tc,fb.status,TdpStatus.Failed);verifyFalse(tc,kick);verifyFalse(tc,m.active);
end
function testLateAndBusyRequests(tc)
[P,T,obs,req]=fixture();m=T.Actuator;
[m,~,~,~]=Actuator2D(m,req,obs,0,P,true,0,false);
other=req;other.requestId=uint32(8);
[m,fb]=Actuator2D(m,other,obs,0.05,P,true,0,false);verifyEqual(tc,fb.status,TdpStatus.Rejected);verifyEqual(tc,m.seenId,uint32(7));
other.requestId=uint32(6);[m,fb]=Actuator2D(m,other,obs,0.1,P,true,0,false);
verifyEqual(tc,fb.status,TdpStatus.Rejected);verifyEqual(tc,m.executions,uint32(1));
end
function testWalkExpiry(tc)
[P,T,obs,req]=fixture();req.kind=TdpAction.Goto;req.velocity=[0.1 0 0];req.validUntil=0.1;
[~,fb,cmd]=Actuator2D(T.Actuator,req,obs,0.15,P,true,0,false);
verifyEqual(tc,cmd,[0 0 0]);verifyEqual(tc,fb.status,TdpStatus.Rejected);
end
function testStopCancels(tc)
[P,T,obs,req]=fixture();[m,~]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
obs.gameRunning=false;[m,fb,cmd,kick]=Actuator2D(m,req,obs,0.3,P,true,0,false);
verifyFalse(tc,kick);verifyFalse(tc,m.active);verifyEqual(tc,fb.status,TdpStatus.Failed);verifyEqual(tc,cmd,[0 0 0]);
end
function testCompatImmediate(tc)
[P,T,obs,req]=fixture();P.mode=TdpMode.Compat;
[m,fb,~,kick,kv]=Actuator2D(T.Actuator,req,obs,0,P,true,0,false);
verifyTrue(tc,kick);verifyEqual(tc,kv,[1.8 0]);verifyEqual(tc,fb.requestId,uint32(7));verifyEqual(tc,fb.status,TdpStatus.Done);verifyEqual(tc,m.executions,uint32(1));
end

function testObservationAcquisitionTime(tc)
P=tdp.defaultConfig();T=tdpTemplates(P);o=Observation2D(T.World,1,P.dt,P);
verifyEqual(tc,o.ballStamp,0);verifyEqual(tc,o.robotStamp,zeros(1,8));verifyEqual(tc,o.tSim,P.dt);
end
