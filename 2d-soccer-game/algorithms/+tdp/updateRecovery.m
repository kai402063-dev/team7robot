function m=updateRecovery(m,prev,st,mf,stAvailable,mfEligible,requests,feedback,health,t,P)
%UPDATERECOVERY Return striker eligibility after fresh, continuously healthy telemetry.
h=health(st);
stFresh=freshHeartbeat(h,t,P.dt);
stOffline=~stAvailable || ~stFresh || (~h.ready && h.activeId==0);
request=requests(st);
fb=feedback(st);
newFailure=prev.chaser==st && isKick(request) && fb.status==TdpStatus.Failed && ...
    fb.requestId==request.requestId && fb.requestId>m.handledFailureId && ...
    fb.stamp>=request.stamp && fb.stamp<=request.validUntil && fb.stamp<=t && ...
    t-fb.stamp<=P.kickTimeout && t<=request.validUntil+P.dt+1e-12;
if newFailure
    m.failed=true;
    m.handledFailureId=fb.requestId;
    m.failureReason=TdpV1Reason.Subsystem;
    if stFresh && h.requestId==fb.requestId
        m.failureReason=h.reason;
    end
elseif stOffline
    m.failureReason=TdpV1Reason.Subsystem;
end
m.takeover=prev.takeover || stOffline || newFailure;
if ~m.takeover, return; end

% A fresh execution receipt is independent of the timestamp of its cached result.
% This lets a terminal event be retrieved after a communication interruption.
m=trackMidfielder(m,mf,requests(mf),feedback(mf),health(mf),prev.chaser,t,P);
if m.releaseId~=0 && (~mfEligible || ~m.ballKnown || ...
        ~freshHeartbeat(health(mf),t,P.dt) || t>m.releaseDeadline || ...
        (~health(mf).ready && health(mf).activeId==0) || ~isfinite(m.releaseDeadline))
    m.cancelPending=true;
end

healthy=~stOffline && h.ready && h.activeId==0;
qualified=false;
if ~healthy || newFailure
    m.healthTiming=false;
else
    advanced=~m.healthTiming || h.stamp>m.lastHealthyStamp;
    if ~m.healthTiming || h.stamp<m.lastHealthyStamp || h.stamp-m.lastHealthyStamp>P.dt+1e-10
        m.healthTiming=true;
        m.healthySince=t;
    end
    m.lastHealthyStamp=h.stamp;
    qualified=advanced && t-m.healthySince+1e-10>=P.v1RecoveryHealthySeconds;
end

if m.releaseId~=0
    m.recovering=qualified || prev.recovering || m.cancelPending;
elseif qualified
    m.takeover=false;
    m.failed=false;
    m.failureReason=TdpV1Reason.None;
    m.recovering=false;
    m.healthTiming=false;
else
    m.recovering=false;
end
end

function m=trackMidfielder(m,mf,request,fb,h,priorOwner,t,P)
if m.releaseId==0 && isKick(request) && priorOwner==mf
    m.releaseId=request.requestId;
    m.releaseStamp=request.stamp;
    m.releaseDeadline=min(request.validUntil,request.stamp+P.kickTimeout);
    m.cancelPending=false;
end
if m.releaseId==0 && h.activeId~=0 && freshHeartbeat(h,t,P.dt)
    % A live executor without a matching local request must be stopped by ID.
    m.releaseId=h.activeId;
    m.releaseStamp=h.stamp;
    m.releaseDeadline=t;
    m.cancelPending=true;
end
if m.releaseId==0, return; end
if h.activeId==m.releaseId && freshHeartbeat(h,t,P.dt)
    % A terminal result older than the last observed active heartbeat is stale.
    m.releaseStamp=max(m.releaseStamp,h.stamp);
end

% Rejection of a cancellation does not prove the original action ended.
terminal=fb.status==TdpStatus.Done || fb.status==TdpStatus.Failed || ...
    (fb.status==TdpStatus.Rejected && ~m.cancelPending && isKick(request));
confirmed=terminal && fb.requestId==m.releaseId && fb.stamp>=m.releaseStamp && ...
    fb.stamp<=t && freshHeartbeat(h,t,P.dt) && h.requestId==m.releaseId && ...
    h.activeId==0 && h.stamp>=fb.stamp;
if confirmed
    m.releaseId=uint32(0);
    m.releaseStamp=0;
    m.releaseDeadline=0;
    m.cancelPending=false;
elseif request.kind==TdpAction.Stop && request.requestId==m.releaseId
    m.cancelPending=true;
end
end

function yes=freshHeartbeat(h,t,dt)
age=t-h.stamp;
yes=isfinite(age) && age>=0 && age<=dt+1e-10;
end

function yes=isKick(request)
yes=(request.kind==TdpAction.Kick || request.kind==TdpAction.Tap) && request.requestId~=0;
end
