function [report,violations] = v1MatchMetrics(trace,tactics,P)
%V1MATCHMETRICS Audit effective permissions and physical outcomes independently.
c = v1TraceColumns();
n = size(trace,1);
assert(n > 0 && size(trace,2) == 98 && size(tactics,1) == n, ...
    'TDP:V1TraceShape','Physical and tactical samples must have corresponding rows.');
expectedRoles = double([TdpRole.GK TdpRole.DF TdpRole.MF TdpRole.ST]);
expectedRoles = [expectedRoles expectedRoles];
chaser = tactics(:,c.chaser);
owner = false(n,8);
owner(:,1:4) = chaser(:,1) == 1:4;
owner(:,5:8) = chaser(:,2) == 5:8;
kick = double(TdpAction.Kick);
tap = double(TdpAction.Tap);
shootIntent = ismember(tactics(:,c.intent),[kick tap]);
primaryIntent = shootIntent | tactics(:,c.intent) == double(TdpAction.Search);
rawKick = ismember(tactics(:,c.rawKind),[kick tap]);
effectiveKick = ismember(tactics(:,c.kind),[kick tap]);
kicker = tactics(:,c.kicker);
didKick = kicker == (1:8);
available = logical(tactics(:,c.available));
freshBall = logical(tactics(:,c.ballFresh));
running = logical(tactics(:,c.running));
known = logical(tactics(:,c.ballKnown));
teamHasBall = [repmat(known(:,1),1,4) repmat(known(:,2),1,4)];
roleChanged = trace(:,49:56) ~= expectedRoles;
expectedTime = (1:n)'*P.dt;

violations = struct('name',{},'count',{},'firstStep',{},'firstColumn',{});
violations = check(violations,'timeAndLength', ...
    [n~=round(P.Tmatch/P.dt) abs(trace(end,61)-P.Tmatch)>1e-9]);
violations = check(violations,'physicalFinite',~isfinite(trace));
violations = check(violations,'tacticsFinite',~isfinite(tactics));
violations = check(violations,'recordClocks', ...
    [abs(trace(:,61)-expectedTime)>1e-9 abs(tactics(:,c.time)-expectedTime)>1e-9]);
violations = check(violations,'fixedRole',roleChanged);
violations = check(violations,'chaserTeamAndRole', ...
    [~ismember(chaser(:,1),[0 3 4]) ~ismember(chaser(:,2),[0 7 8])]);
violations = check(violations,'unavailableChaser',owner & ~available);
violations = check(violations,'unauthorizedPrimaryIntent',primaryIntent & ~owner);
violations = check(violations,'unauthorizedKickRequest',effectiveKick & ~owner);
violations = check(violations,'multipleKickRequesters', ...
    [sum(effectiveKick(:,1:4),2)>1 sum(effectiveKick(:,5:8),2)>1]);
violations = check(violations,'invalidKickRequest', ...
    effectiveKick & (~available | ~freshBall | ~teamHasBall | ~running));
violations = check(violations,'expiredKickRequest',effectiveKick & ...
    (tactics(:,c.time)<tactics(:,c.stamp)-1e-12 | tactics(:,c.time)>tactics(:,c.validUntil)+1e-12));
violations = check(violations,'kickRequestIdZero',effectiveKick & tactics(:,c.requestId)==0);
violations = check(violations,'physicalKickEvent', ...
    [~ismember(kicker,0:8) (kicker~=0)~=logical(trace(:,97))]);
violations = check(violations,'physicalKickOwner',didKick & (~owner | ~effectiveKick));
violations = check(violations,'kickFeedback',didKick & ...
    (tactics(:,c.status)~=double(TdpStatus.Done) | tactics(:,c.feedbackId)~=tactics(:,c.requestId)));
duplicateKick = false(n,8);
for robot=1:8
    steps = find(didKick(:,robot));
    ids = tactics(steps,c.requestId(robot));
    [~,first] = unique(ids,'stable');
    duplicateKick(steps(setdiff(1:numel(steps),first)),robot) = true;
end
violations = check(violations,'repeatPhysicalKick',duplicateKick);
physicalShots = didKick & tactics(:,c.speed)>=P.shotSpeed;
expectedShots = cumsum([sum(physicalShots(:,1:4),2) sum(physicalShots(:,5:8),2)]);
violations = check(violations,'actualShotCounters',trace(:,66:67)~=expectedShots);

% Each row observes the previous world. The experiment uses the ideal sensor.
initial = tdpTemplates(P);
observedX = [initial.World.ball.x; trace(1:end-1,57)];
base = tactics(:,c.basePhase);
changedBase = [false(1,2); diff(base)~=0];
violations = check(violations,'midlineBandSwitch',changedBase & known & ...
    abs(observedX) <= P.v1MidlineBand);
report = matchMetrics(trace,P);
report.period = P.dt;
report.simulationSeconds = trace(end,61);
report.roleChangesByRobot = sum(diff(trace(:,49:56))~=0,1);
report.actualKicksByRobot = sum(didKick,1);
report.actualKicksByTeam = [sum(report.actualKicksByRobot(1:4)) sum(report.actualKicksByRobot(5:8))];
report.actualShotsByRobot = sum(physicalShots,1);
report.midfielderShots = report.actualShotsByRobot([3 7]);
report.kickRequestSamples = sum(effectiveKick,1);
report.kickRequestIds = uniqueActions(effectiveKick,tactics(:,c.requestId));
report.executionStartsByRobot = tactics(end,c.executions);
report.revokedRawKickSamples = sum(rawKick & ~effectiveKick,1);
report.phaseSwitches = sum(diff(tactics(:,c.phase))~=0,1);
report.basePhaseSwitches = sum(changedBase,1);
report.phaseSampleCounts = zeros(2,5);
for team=1:2
    for phase=0:4
        report.phaseSampleCounts(team,phase+1) = nnz(tactics(:,c.phase(team))==phase);
    end
end
report.fallbackEntries = risingCount(tactics(:,c.phase)==double(TdpTeamPhase.Fallback));
report.takeoverEntries = risingCount(logical(tactics(:,c.takeover)));
report.takeoverSeconds = sum(tactics(:,c.takeover),1)*P.dt;
normalDefender = tactics(:,c.phase)==double(TdpTeamPhase.Defend);
report.regularMfChaseSamples = sum((chaser==[3 7]) & normalDefender & ~logical(tactics(:,c.takeover)),1);
report.searchSamples = sum(~known,1);
report.failedStrikerSamples = sum(tactics(:,c.failed),1);
report.doneActionsByRobot = uniqueActions(tactics(:,c.status)==double(TdpStatus.Done),tactics(:,c.feedbackId));
report.failedActionsByRobot = uniqueActions(tactics(:,c.status)==double(TdpStatus.Failed),tactics(:,c.feedbackId));
report.rejectedActionsByRobot = uniqueActions(tactics(:,c.status)==double(TdpStatus.Rejected),tactics(:,c.feedbackId));
report.runningActionsByRobot = uniqueActions(tactics(:,c.status)==double(TdpStatus.Running),tactics(:,c.feedbackId));
report.chaserChanges = sum(diff(chaser)~=0,1);
deltaBall = diff([initial.World.ball.x initial.World.ball.y; trace(:,57:58)]);
motion = hypot(deltaBall(:,1),deltaBall(:,2));
report.physicalKickStepsWithBallMotion = sum(kicker>0 & motion>1e-9);
report.maximumBallDisplacementOnKickMetres = max([0; motion(kicker>0)]);
report.observedBallTravelMetresIncludingResets = sum(motion);
position = trace(:,1:16);
report.robotsWithMotion = sum(any(hypot(diff(position(:,1:8)),diff(position(:,9:16)))>1e-9,1));
report.geometryPassed = report.overlapSteps==0 && report.outsideBorderRobotSamples==0;
if ~report.geometryPassed
    violations = check(violations,'geometryRepair', ...
        [report.overlapSteps>0 report.outsideBorderRobotSamples>0]);
end
report.passed = isempty(violations);
end

function violations=check(violations,name,mask)
if any(mask,'all')
    firstStep = find(any(mask,2),1);
    firstColumn = find(mask(firstStep,:),1);
    violations(end+1) = struct('name',name,'count',nnz(mask), ...
        'firstStep',firstStep,'firstColumn',firstColumn);
end
end

function counts=uniqueActions(mask,ids)
counts = zeros(1,8);
for robot=1:8
    counts(robot) = numel(unique(ids(mask(:,robot) & ids(:,robot)>0,robot)));
end
end

function counts=risingCount(mask)
counts = sum(mask & ~[false(1,size(mask,2)); mask(1:end-1,:)],1);
end
