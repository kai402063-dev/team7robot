function m=qinBehaviourMetrics(trace,tactics,P,options)
%QINBEHAVIOURMETRICS Offline Q1/Q2 metrics. Never runs or changes a simulation.
% Samples represent (t-dt,t], using end-of-step truth and same-step decisions.
% Possession is an explicitly provisional geometric estimate, not lastTouch.
c=replayColumns(); q=v1TraceColumns(); n=size(trace,1);
if nargin<4,options=struct();end
assert(isstruct(options)&&isscalar(options)&&all(ismember(fieldnames(options),{'centreBandMetres'})), ...
    'Qin:Options','Only centreBandMetres is supported.');
midTol=1e-9;if isfield(options,'centreBandMetres'),midTol=options.centreBandMetres;end
assert(isnumeric(midTol)&&isscalar(midTol)&&isfinite(midTol)&&midTol>=0&&midTol<P.L/2, ...
    'Qin:Options','centreBandMetres must be nonnegative and smaller than half the pitch.');
assert(isnumeric(trace)&&isreal(trace)&&n>0&&size(trace,2)==98&&all(isfinite(trace),'all'), ...
    'Qin:Trace','Expected a nonempty finite N-by-98 physical trace.');
assert(isscalar(P.dt)&&isfinite(P.dt)&&P.dt>0,'Qin:Time','Invalid dt.');
t=trace(:,c.time); tol=max(1e-9,P.dt*1e-6);
assert(all(abs(t-(1:n)'*P.dt)<tol)&&t(end)<=P.Tmatch+tol, ...
    'Qin:Time','Require a contiguous recording starting at dt; gaps/crops are rejected.');
hasTactics=~isempty(tactics);
if hasTactics
    assert(isnumeric(tactics)&&isreal(tactics)&&isequal(size(tactics),[n 171]), ...
        'Qin:Tactics','Expected N-by-171 tactics.');
    needed=[q.time q.running q.available q.skill q.chaser];
    assert(all(isfinite(tactics(:,needed)),'all')&&all(abs(tactics(:,q.time)-t)<tol), ...
        'Qin:Tactics','Invalid or misaligned tactical fields.');
    assert(all(ismember(tactics(:,q.running),[0 1]))&&all(ismember(tactics(:,q.available),[0 1]),'all') ...
        &&all(ismember(tactics(:,q.skill),0:5),'all') ...
        &&all(ismember(tactics(:,q.chaser(1)),0:4)) ...
        &&all(ismember(tactics(:,q.chaser(2)),[0 5:8])), ...
        'Qin:Tactics','Invalid state, availability or global chaser ID.');
    running=logical(tactics(:,q.running));
else
    % The controller reads the PREVIOUS referee state. Do not use this row's
    % pauseUntil: goal/out reset has already happened when this row is saved.
    running=t >= [0;trace(1:end-1,c.pauseUntil)]-tol;
    if isfield(P,'v1StopWindow')
        running=running & ~(t>=P.v1StopWindow(1)&t<P.v1StopWindow(2));
    end
end
reset=trace(:,c.pauseUntil)>[0;trace(1:end-1,c.pauseUntil)]+tol;
outside=abs(trace(:,c.ballX))>P.L/2+P.ballR+tol | abs(trace(:,c.ballY))>P.W/2+P.ballR+tol;
% End-of-step reset rows cannot reveal the pre-reset ball location.
eligible=running & ~reset & ~outside;
left=eligible & trace(:,c.ballX)<-midTol;
right=eligible & trace(:,c.ballX)>midTol;
centre=eligible & abs(trace(:,c.ballX))<=midTol;
half=[sum(left) sum(centre) sum(right) sum(~running) sum(running&reset) sum(running&~reset&outside)]*P.dt;
assert(abs(sum(half)-n*P.dt)<tol,'Qin:Invariant','Half-time partition failed.');
scores=trace(:,c.score); delta=diff([zeros(1,2);scores]);
assert(all(delta>=0 & delta==fix(delta),'all'),'Qin:Score','Scores must be nonnegative cumulative integer counts.');
m=struct(); m.schemaVersion='qin-metrics-2';m.steps=n;m.dt=P.dt;
m.recordedSeconds=n*P.dt;m.plannedSeconds=P.Tmatch;m.complete=abs(n*P.dt-P.Tmatch)<tol;
m.hasTactics=hasTactics;m.runningSeconds=sum(running)*P.dt;m.analysisSeconds=sum(eligible)*P.dt;
m.goals=scores(end,:);m.goalEvents=sum(delta,1);m.shots=trace(end,c.shots);
m.resultBlueRed=sign(m.goals(1)-m.goals(2));
m.halfSeconds=half;m.halfLabels={'left','centre','right','paused','restartTransition','outside'};
m.halfFractionOfAnalysis=half(1:3)/max(m.analysisSeconds,eps);
if m.analysisSeconds==0,m.halfFractionOfAnalysis(:)=NaN;end
assert(isequal(P.dirSign,[1 -1]),'Qin:Direction', ...
    'Current referee/initial-state contract requires blue +x and red -x. Swap policies, not dirSign.');
m.attackHalfSeconds=[half(3) half(1)];
m.lastTouchSeconds=trace(end,c.touchTime); % Diagnostic only. NEVER possession.
looseSpeed=0.35;if isfield(P,'v1LooseSpeed'),looseSpeed=P.v1LooseSpeed;end
m.thresholds=struct('centreToleranceMetres',midTol,'movingSpeed',0.02, ...
    'possessionRange',P.kickRange,'possessionHeading',P.kickAlign,'possessionBallSpeed',looseSpeed);
robotSeconds=nan(8,8);possession=nan(1,4);noChaser=nan(1,2);
if hasTactics
    available=logical(tactics(:,q.available)); skill=tactics(:,q.skill);
    dx=trace(:,c.ballX)-trace(:,c.x);dy=trace(:,c.ballY)-trace(:,c.y);
    dist=hypot(dx,dy);bearing=atan2(dy,dx);
    heading=abs(atan2(sin(bearing-trace(:,c.th)),cos(bearing-trace(:,c.th))));
    candidates=available & eligible & dist<=P.kickRange+tol & heading<=P.kickAlign+tol ...
        & hypot(trace(:,c.ballVx),trace(:,c.ballVy))<=looseSpeed+tol;
    blue=any(candidates(:,1:4),2);red=any(candidates(:,5:8),2);
    contested=blue&red;owners=false(n,8);
    distances=dist;distances(~candidates)=Inf;
    [~,nearest]=min(distances,[],2); % Same-team ties use the lower global ID.
    for i=1:8,owners(:,i)=nearest==i & xor(blue,red);end
    possession=[sum(blue&~red) sum(red&~blue) sum(contested) sum(eligible&~blue&~red)]*P.dt;
    authorized=[tactics(:,q.chaser(1))==(1:4) tactics(:,q.chaser(2))==(5:8)] & available & eligible;
    idle=skill==0 & available & eligible;
    chasing=authorized & ismember(skill,[2 3]);
    moving=chasing & hypot(trace(:,c.vxw),trace(:,c.vyw))>0.02;
    % Independent indicators may overlap. This partition has precedence
    % possession > chasing > idle > other, on available eligible robot time.
    partitionChase=chasing&~owners;partitionIdle=idle&~owners&~chasing;
    other=available&eligible&~owners&~partitionChase&~partitionIdle;
    robotSeconds=[sum(idle);sum(authorized);sum(chasing);sum(moving);sum(owners); ...
        sum(partitionChase);sum(partitionIdle);sum(other)]'*P.dt;
    assert(all(abs(sum(robotSeconds(:,5:8),2)-sum(available&eligible,1)'*P.dt)<tol), ...
        'Qin:Invariant','Robot-time partition failed.');
    for team=1:2,noChaser(team)=sum(eligible & tactics(:,q.chaser(team))==0)*P.dt;end
    assert(abs(sum(possession)-m.analysisSeconds)<tol,'Qin:Invariant','Possession partition failed.');
end
m.robotSeconds=robotSeconds;
m.robotLabels={'idleState','authorized','chasingState','chasingMoving','possessionEstimate','exclusiveChasing','exclusiveIdle','other'};
m.possessionSeconds=possession;m.possessionLabels={'blue','red','contested','free'};
m.noAuthorizedChaserSeconds=noChaser;
% Handoff additions: keep v1 indicators unchanged; never silently replace
% Stateflow Idle with physical stationarity or Approach/Align with Kick.
m.policyIds=[];if isfield(P,'v12Policy'),m.policyIds=P.v12Policy;end
m.defendSeconds=nan(1,2);m.defendNoChaserSeconds=nan(1,2);m.defendNoChaserRatio=nan(1,2);
m.chasingIncludingKickSeconds=nan(1,8);
m.stationarySeconds=nan(8,4);
m.stationaryLabels={'total','effectiveStop','effectiveGoto','otherRequest'};
if hasTactics
    assert(all(ismember(tactics(:,q.phase),0:4),'all')&&all(ismember(tactics(:,q.kind),0:4),'all'), ...
        'Qin:Tactics','Invalid team phase or effective request.');
    for team=1:2
        defend=running & tactics(:,q.phase(team))==1;
        m.defendSeconds(team)=sum(defend)*P.dt;
        m.defendNoChaserSeconds(team)=sum(defend&tactics(:,q.chaser(team))==0)*P.dt;
        if any(defend),m.defendNoChaserRatio(team)=m.defendNoChaserSeconds(team)/m.defendSeconds(team);end
    end
    permitted=[tactics(:,q.chaser(1))==(1:4) tactics(:,q.chaser(2))==(5:8)];
    m.chasingIncludingKickSeconds=sum(running&available&permitted&ismember(skill,[2 3 4]),1)*P.dt;
    stationary=running&available&hypot(trace(:,c.vxw),trace(:,c.vyw))<=0.02;
    stop=stationary&tactics(:,q.kind)==0;hold=stationary&tactics(:,q.kind)==1;
    m.stationarySeconds=[sum(stationary);sum(stop);sum(hold);sum(stationary&~stop&~hold)]'*P.dt;
end
% Decision-time location comes from trace(k-1), not trace(k). Initial world
% may have been overridden, so the missing first pre-state remains unknown.
prevX=[NaN;trace(1:end-1,c.ballX)];prevY=[NaN;trace(1:end-1,c.ballY)];
known=isfinite(prevX)&isfinite(prevY);
prevInside=abs(prevX)<=P.L/2+P.ballR+tol&abs(prevY)<=P.W/2+P.ballR+tol;
decisionEligible=running&known&prevInside;
m.decisionHalfSeconds=[sum(decisionEligible&prevX < -midTol) ...
    sum(decisionEligible&abs(prevX)<=midTol) sum(decisionEligible&prevX>midTol)]*P.dt;
m.decisionHalfUnknownSeconds=sum(running&~known)*P.dt;
m.decisionHalfOutsideSeconds=sum(running&known&~prevInside)*P.dt;
m.halfSampling='physical: end-of-step; decision: previous trace row; first pre-state unknown';
m.notes={'Possession is an unapproved geometric proxy, not measured control.', ...
    'Idle means Stateflow Idle, not physical immobility.', ...
    'No-chaser time is descriptive, not automatically a tactical defect.', ...
    'Reset rows are excluded because recorded ball coordinates are already reset.', ...
    'Missing tactics yields unavailable (NaN), not zero, behaviour and possession.'};
end
