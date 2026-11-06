function tests=test_v1_matrix
tests=functiontests(localfunctions);
end

function setupOnce(t)
tdpSetup;
P=tdp.v1Config();
P.Tmatch=4*P.dt;
T=tdpTemplates(P);
c=v1TraceColumns();
n=4;
trace=repmat(MatchRecord(T.World,4,8),n,1);
trace(:,49:56)=repmat([1 3 5 2 1 3 5 2],n,1);
trace(:,61)=(1:n)'*P.dt;
tactics=zeros(n,c.recovering(end));
tactics(:,c.time)=trace(:,61);
tactics(:,c.phase)=double(TdpTeamPhase.Attack);
tactics(:,c.basePhase)=double(TdpTeamPhase.Attack);
tactics(:,c.chaser)=repmat([4 8],n,1);
tactics(:,[c.available c.ballFresh c.ballKnown c.running])=1;
tactics(:,c.intent)=double(TdpAction.Goto);
tactics(:,c.validUntil)=1;
t.TestData=struct('P',P,'trace',trace,'tactics',tactics,'c',c);
end

function testStationaryReference(t)
d=t.TestData;
[report,violations]=v1MatchMetrics(d.trace,d.tactics,d.P);
verifyTrue(t,report.passed);
verifyEmpty(t,violations);
verifyEqual(t,report.actualKicksByRobot,zeros(1,8));
end

function testUnownedEffectiveRequest(t)
d=t.TestData;
d.tactics(2,d.c.kind(1))=double(TdpAction.Kick);
d.tactics(2,d.c.requestId(1))=7;
[~,violations]=v1MatchMetrics(d.trace,d.tactics,d.P);
bad=violations(strcmp({violations.name},'unauthorizedKickRequest'));
verifyEqual(t,numel(bad),1);
if ~isempty(bad)
    verifyEqual(t,[bad.firstStep bad.firstColumn],[2 1]);
end
end

function testDuplicatePhysicalKick(t)
d=t.TestData;
d.trace(2:3,97)=1;
d.tactics(2:3,d.c.kicker)=4;
d.tactics(2:3,d.c.kind(4))=double(TdpAction.Kick);
d.tactics(2:3,[d.c.requestId(4) d.c.feedbackId(4)])=9;
d.tactics(2:3,d.c.status(4))=double(TdpStatus.Done);
[~,violations]=v1MatchMetrics(d.trace,d.tactics,d.P);
verifyTrue(t,ismember('repeatPhysicalKick',{violations.name}));
end
