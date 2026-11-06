function tests=test_controller
tests=functiontests(localfunctions);
end
function setupOnce(tc)
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;tc.TestData.P=P;
end
function testReplayAndTruthIsolation(tc)
P=tc.TestData.P;sc=makeScenario(P,2);T=tdpTemplates(P);
worldA=T.World;worldA.robots=sc(1).obs.robots;worldA.active=sc(1).obs.robotValid;
worldA.ball=sc(1).obs.ball;worldA.referee.pauseUntil=0;
for k=1:numel(sc)
 now=(k-1)*P.dt;worldA.referee.t=now;sc(k).obs=Observation2D(worldA,1,now,P);
end
frozen=sc;a=runReplay(P,frozen);
worldB=worldA;worldB.ball.x=3.2;worldB.ball.y=-0.6;
worldB.robots(1).x=1.7;worldB.robots(1).y=0.8;worldB.robots(1).th=pi;
reobserved=sc;
for k=1:numel(sc)
 now=(k-1)*P.dt;worldB.referee.t=now;reobserved(k).obs=Observation2D(worldB,1,now,P);
end
% Freeze the sensing boundary while changing the actual environment state.
b=runReplay(P,frozen);verifyEqual(tc,a,b);
verifyNotEqual(tc,reobserved(1).obs.ball.x,frozen(1).obs.ball.x);
verifyNotEqual(tc,reobserved(1).obs.robots(1).x,frozen(1).obs.robots(1).x);
% Positive control: reopening sensing must expose the changed world to Core.
c=runReplay(P,reobserved);verifyFalse(tc,isequal(a,c));
load_system('ControllerCore');ports=find_system('ControllerCore/Core','SearchDepth',1,'BlockType','Inport');
names=cellfun(@(p)get_param(p,'Name'),ports,'UniformOutput',false);
verifyEqual(tc,sort(names(:)),sort({'obs';'intent';'feedback';'tSim'}));
verifyTrue(tc,all(isfinite(a(:))));
end
function testNormalFeedback(tc)
for dt=[0.05 0.04]
 P=tc.TestData.P;P.dt=dt;sc=makeScenario(P,2);a=runReplay(P,sc);
 k=find(a(:,1)==double(TdpAction.Kick),1);verifyNotEmpty(tc,k);id=uint32(a(k,2));
 finish=k+3;
 for j=finish:numel(sc),sc(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*dt);end
 b=runReplay(P,sc);verifyEqual(tc,b(finish,3),double(TdpPhase.Recover));
 verifyEqual(tc,b(k:finish-1,2),repmat(double(id),finish-k,1));
end
end
function testTimeout(tc)
P=tc.TestData.P;sc=makeScenario(P,2);a=runReplay(P,sc);
k=find(a(:,3)==double(TdpPhase.Kick),1);j=find(a(:,3)==double(TdpPhase.Recover),1);
verifyGreaterThanOrEqual(tc,(j-k)*P.dt,P.kickTimeout-1e-12);
verifyLessThanOrEqual(tc,(j-k)*P.dt,P.kickTimeout+P.dt);
end
function testFailedAndRejectedFeedback(tc)
for status=[TdpStatus.Failed TdpStatus.Rejected]
 P=tc.TestData.P;sc=makeScenario(P,2);a=runReplay(P,sc);k=find(a(:,1)==double(TdpAction.Kick),1);
 j=k+2;sc(j).feedback=struct('requestId',uint32(a(k,2)),'status',status,'stamp',(j-1)*P.dt);
 b=runReplay(P,sc);verifyEqual(tc,b(j,3),double(TdpPhase.Recover));
end
end
function testLateFeedbackIgnored(tc)
P=tc.TestData.P;sc=makeScenario(P,2);a=runReplay(P,sc);k=find(a(:,1)==double(TdpAction.Kick),1);
for j=k+1:k+5,sc(j).feedback=struct('requestId',uint32(a(k,2)-1),'status',TdpStatus.Done,'stamp',(j-1)*P.dt);end
b=runReplay(P,sc);verifyEqual(tc,b(k:k+5,3),repmat(double(TdpPhase.Kick),6,1));
end
function testLostBallAndStop(tc)
P=tc.TestData.P;sc=makeScenario(P,2);
for k=1:numel(sc),sc(k).obs.ballValid=false;end
a=runReplay(P,sc);verifyFalse(tc,any(a(:,1)==double(TdpAction.Kick)));
verifyTrue(tc,any(a(:,3)==double(TdpPhase.Search)));
sc=makeScenario(P,2);stop=8;
for k=stop:numel(sc),sc(k).obs.gameRunning=false;end
b=runReplay(P,sc);verifyEqual(tc,b(stop:end,1),zeros(numel(sc)-stop+1,1));
verifyEqual(tc,b(stop:end,3),zeros(numel(sc)-stop+1,1));
end
function testStaleObservation(tc)
P=tc.TestData.P;sc=makeScenario(P,2);
for k=1:numel(sc),sc(k).obs.robotStamp(:)=0;end
a=runReplay(P,sc);old=find((0:numel(sc)-1)*P.dt>P.maxObservationAge);
verifyEqual(tc,a(old,1),zeros(numel(old),1));
end
function testSingleClosedLoop(tc)
for dt=[0.05 0.04]
 P=tc.TestData.P;P.dt=dt;input=Simulink.SimulationInput('tdpSingleRobot');input=input.setVariable('P',P,'Workspace','tdpSingleRobot');
 rng(12,'twister');a=sim(input);rng(12,'twister');b=sim(input);
 ar=recordRows(a.records);br=recordRows(b.records);verifyEqual(tc,ar,br);verifyTrue(tc,all(isfinite(ar(:))));
 verifyGreaterThanOrEqual(tc,max(ar(:,8)),1);verifyGreaterThan(tc,max(ar(:,4)),0.5);
 verifyEqual(tc,get_param('tdpSingleRobot','AlgebraicLoopMsg'),'error');
end
end
