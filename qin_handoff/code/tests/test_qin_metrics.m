function tests=test_qin_metrics
tests=functiontests(localfunctions);
end
function [r,q,P]=fixture(n)
P=tdp.v1Config();P.Tmatch=n*P.dt;r=zeros(n,98);q=zeros(n,171);
r(:,61)=(1:n)'*P.dt;q(:,1)=r(:,61);q(:,14)=1;q(:,16:23)=1;
r(:,1:8)=3;r(:,9:16)=2;
end
function testHalfPartitionAndCentre(t)
[r,q,P]=fixture(6);r(:,57)=[-1;0;1;-1;0;0];q(4,14)=0;
r(5:6,65)=2;r(6,57)=6;
m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.halfSeconds,ones(1,6)*P.dt,'AbsTol',1e-12);
end
function testCentreCrossingNotInterpolated(t)
[r,q,P]=fixture(2);r(:,57)=[-.1;.1];m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.halfSeconds(1:3),[.05 0 .05],'AbsTol',1e-12);
end
function testPossessionContestedAndFastBall(t)
[r,q,P]=fixture(4);r(:,1)=-.25;r(:,9)=0;
r(2,5)=.25;r(2,13)=0;r(2,21)=pi;r(3,59)=1;q(4,16)=0;
m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.possessionSeconds,[.05 0 .05 .1],'AbsTol',1e-12);
verifyEqual(t,m.robotSeconds(1,5),.05,'AbsTol',1e-12);
end
function testStateOverlapAndMovement(t)
[r,q,P]=fixture(3);r(:,1)=-.25;r(:,9)=0;q(:,6)=1;q(:,80)=[2;3;0];r(1,25)=.1;
m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.robotSeconds(1,1:7),[.05 .15 .1 .05 .15 0 0],'AbsTol',1e-12);
end
function testMissingTacticsUnavailable(t)
[r,~,P]=fixture(2);m=qinBehaviourMetrics(r,[],P);
verifyTrue(t,all(isnan(m.robotSeconds),'all'));verifyTrue(t,all(isnan(m.possessionSeconds)));
end
function testRejectGapsAndMisalignment(t)
[r,q,P]=fixture(3);r(2,61)=.11;verifyError(t,@()qinBehaviourMetrics(r,q,P),'Qin:Time');
[r,q,P]=fixture(3);q(2,1)=.11;verifyError(t,@()qinBehaviourMetrics(r,q,P),'Qin:Tactics');
end
function testGoalsAreScoreIncrementsNotMessageCounts(t)
[r,q,P]=fixture(4);r(:,98)=2;r(2:end,62)=1;m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.goals,[1 0]);verifyEqual(t,m.goalEvents,[1 0]);
end
function testPartialRecording(t)
[r,q,P]=fixture(2);P.Tmatch=600;m=qinBehaviourMetrics(r,q,P);verifyFalse(t,m.complete);
end
function testPossessionThresholdsAndSameTeamTie(t)
[r,q,P]=fixture(2);r(:,1:2)=-P.kickRange;r(:,9:10)=0;r(2,1:2)=-P.kickRange-1e-6;
m=qinBehaviourMetrics(r,q,P);verifyEqual(t,m.robotSeconds(1:2,5),[.05;0],'AbsTol',1e-12);
verifyEqual(t,m.possessionSeconds,[.05 0 0 .05],'AbsTol',1e-12);
end
function testRejectBadScores(t)
[r,q,P]=fixture(2);r(:,62)=[1;0];verifyError(t,@()qinBehaviourMetrics(r,q,P),'Qin:Score');
end
function testLegacyRecordingAndPausedReset(t)
[r,~,P]=fixture(3);P=tdp.defaultConfig();P.Tmatch=.15;r(1:end,65)=1;
m=qinBehaviourMetrics(r,[],P);
verifyEqual(t,m.halfSeconds,[0 0 0 .1 .05 0],'AbsTol',1e-12);
verifyTrue(t,all(isnan(m.possessionSeconds)));
end
function testNoEligibleTime(t)
[r,q,P]=fixture(2);q(:,14)=0;m=qinBehaviourMetrics(r,q,P);
verifyTrue(t,all(isnan(m.halfFractionOfAnalysis)));verifyEqual(t,m.analysisSeconds,0);
end
function testRejectDirectionChange(t)
[r,q,P]=fixture(2);P.dirSign=[-1 1];verifyError(t,@()qinBehaviourMetrics(r,q,P),'Qin:Direction');
end
function testHeadingAndBallSpeedBoundaries(t)
[r,q,P]=fixture(3);r(:,1)=-.25;r(:,9)=0;r(:,17)=[P.kickAlign;P.kickAlign+1e-6;0];
r(:,59)=[P.v1LooseSpeed;0;P.v1LooseSpeed+1e-6];m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.possessionSeconds,[.05 0 0 .1],'AbsTol',1e-12);
end
function testConfigurableCentreBand(t)
[r,q,P]=fixture(3);r(:,57)=[-.1;0;.1];
m=qinBehaviourMetrics(r,q,P,struct('centreBandMetres',.15));
verifyEqual(t,m.halfSeconds(1:3),[0 .15 0],'AbsTol',1e-12);
verifyError(t,@()qinBehaviourMetrics(r,q,P,struct('centreBandMetres',-1)),'Qin:Options');
end
function testDecisionUsesPreviousState(t)
[r,q,P]=fixture(3);r(:,57)=[-1;1;1];m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.halfSeconds(1:3),[.05 0 .1],'AbsTol',1e-12);
verifyEqual(t,m.decisionHalfSeconds,[.05 0 .05],'AbsTol',1e-12);
verifyEqual(t,m.decisionHalfUnknownSeconds,.05,'AbsTol',1e-12);
end
function testDefendRatioExcludesPauseAndNoDenominator(t)
[r,q,P]=fixture(4);q(:,2)=1;q(1:2,6)=2;q(4,14)=0;
m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.defendSeconds,[.15 0],'AbsTol',1e-12);
verifyEqual(t,m.defendNoChaserRatio(1),1/3,'AbsTol',1e-12);
verifyTrue(t,isnan(m.defendNoChaserRatio(2)));
end
function testKickAndStationaryTypes(t)
[r,q,P]=fixture(3);q(:,6)=2;q(:,81)=4;q(:,49)=[0;1;2];
m=qinBehaviourMetrics(r,q,P);
verifyEqual(t,m.chasingIncludingKickSeconds(2),.15,'AbsTol',1e-12);
verifyEqual(t,m.stationarySeconds(2,:),[.15 .05 .05 .05],'AbsTol',1e-12);
verifyEqual(t,m.robotSeconds(2,3),0);
end
