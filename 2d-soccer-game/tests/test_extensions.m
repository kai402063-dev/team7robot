function tests=test_extensions
tests=functiontests(localfunctions);
end
function testThresholdChangesDecision(t)
P=tdp.defaultConfig();s=makeScenario(P,1);o=s(1).obs;o.robots(1).x=-.29;
g=CoreGeometry(o,s(1).intent,0,P);verifyFalse(t,g.ready);
P.kickRange=.32;g=CoreGeometry(o,s(1).intent,0,P);verifyTrue(t,g.ready);
end
function testFixedRoleRule(t)
P=tdp.defaultConfig();T=tdpTemplates(P);o=Observation2D(T.World,1,0,P);
[a,~]=TeamCoordinator(o,1,0,P);verifyEqual(t,a(4).role,TdpRole.ST);
P.fixedStriker=true;[a,m]=TeamCoordinator(o,1,0,P);verifyEqual(t,a(2).role,TdpRole.ST);verifyEqual(t,m,2);
verifyEqual(t,sum([a.role]==TdpRole.ST),1);
end
function testFiniteFieldOfView(t)
P=tdp.defaultConfig();T=tdpTemplates(P);w=T.World;w.ball.x=w.robots(1).x-1;w.ball.y=w.robots(1).y;
o=Observation2D(w,1,0,P);verifyTrue(t,o.ballValid);
P.fieldOfView=pi/3;o=Observation2D(w,1,0,P);verifyFalse(t,o.ballValid);
end
function testObservationDelayAndNoise(t)
P=tdp.defaultConfig();P.observationDelay=.10;P.observationNoise=.02;
s=makeScenario(P,.2);m=ObservationHistory(P);z=zeros(9,2);z(9,:)=[1 -2];
for k=1:3
 raw=s(k).obs;raw.ball.x=k-1;[m,o]=ObservationChannel(m,raw,(k-1)*P.dt,P,z);
 if k<3,verifyFalse(t,o.ballValid);end
end
verifyTrue(t,o.ballValid);verifyEqual(t,[o.ball.x o.ball.y],[.02 -.04],'AbsTol',1e-12);verifyEqual(t,o.ballStamp,0);verifyEqual(t,o.tSim,.1);
P.observationDelay=.07;verifyError(t,@()ObservationChannel(m,raw,.1,P,z),'TDP:ObservationDelay');
end
function testTapExecutesLowerSpeed(t)
P=tdp.defaultConfig();s=makeScenario(P,1);intent=tdp.makeTapIntent(s(1).obs.ball,1,P);
g=CoreGeometry(s(1).obs,intent,0,P);req=EmitRequest(g,TdpPhase.Kick,uint32(12),0,intent.target,intent.speed,0,P);
verifyEqual(t,req.kind,TdpAction.Tap);T=tdpTemplates(P);
[m,fb,~,kicked,v]=Actuator2D(T.Actuator,req,s(1).obs,0,P,true,0,false);
verifyTrue(t,kicked);verifyEqual(t,fb.status,TdpStatus.Done);verifyEqual(t,norm(v),P.tapSpeed,'AbsTol',1e-12);verifyEqual(t,m.executions,uint32(1));
end
function testRandomizationStartsFresh(t)
P=tdp.defaultConfig();z=ones(9,3);[a,b,c]=tdp.randomizeInitial(P,z);[x,y,s]=tdp.randomizeInitial(P,z);
verifyEqual(t,a,x);verifyEqual(t,b,y);verifyEqual(t,c,s);[base,~,~]=tdp.initialState(P);verifyEqual(t,a(1).x-base(1).x,.05,'AbsTol',1e-12);
end
function testUnknownParameterRejected(t)
verifyError(t,@()tdp.requireKnown([]),'TDP:UnknownParameter');verifyError(t,@()tdp.requireKnown(NaN),'TDP:UnknownParameter');verifyEqual(t,tdp.requireKnown(0),0);
end
function testDelayedChannelRunsSharedCore(t)
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;P.observationDelay=.1;
a=sensorReplay(P,7,2);b=sensorReplay(P,7,2);verifyEqual(t,a,b);
verifyEqual(t,a(1:2,1),zeros(2,1));verifyTrue(t,any(a(:,1)==double(TdpAction.Kick)));
end
function testConfigurationRejectsUnknownNumericField(t)
P=tdp.defaultConfig();P.vFwd=[];verifyError(t,@()tdp.validateConfig(P),'TDP:UnknownParameter');
end
function testInvalidObstacleTimestampIsIgnored(t)
P=tdp.defaultConfig();s=makeScenario(P,1);o=s(1).obs;intent=s(1).intent;
o.robotValid(2)=true;o.robotStamp(2)=NaN;o.robots(2).x=o.robots(1).x+.2;o.robots(2).y=.1;
intent.type=TdpAction.Goto;intent.target=[2 1];a=CoreGeometry(o,intent,0,P);
o.robotValid(2)=false;b=CoreGeometry(o,intent,0,P);verifyEqual(t,a.command,b.command,'AbsTol',1e-12);
end
