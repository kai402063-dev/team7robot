function requests=V1AuthorizeRequests(raw,plans,obs,blue,red,previous,feedback,P)
%V1AUTHORIZEREQUESTS Revoke frozen kicks before the actuator can finish them.
requests=raw;
for i=1:8
    state=blue;
    if i>4, state=red; end
    owner=state.chaser;
    t=obs(i).tSim;
    self=obs(i).robots(i);
    available=obs(i).selfValid && obs(i).robotValid(i) && fresh(t,obs(i).robotStamp(i),P) ...
        && isfinite(self.x) && isfinite(self.y) && isfinite(self.th);
    ballFresh=obs(i).ballValid && fresh(t,obs(i).ballStamp,P) ...
        && isfinite(obs(i).ball.x) && isfinite(obs(i).ball.y) ...
        && isfinite(obs(i).ball.vx) && isfinite(obs(i).ball.vy);
    revoke=~available || ~obs(i).gameRunning || plans(i).type==TdpAction.Stop;
    if kicking(raw(i).kind)
        revoke=revoke || i~=owner || ~ballFresh || ~kicking(plans(i).type) ...
            || t<raw(i).stamp || t>raw(i).validUntil;
    elseif raw(i).kind==TdpAction.Search
        revoke=revoke || i~=owner;
    end
    pending=kicking(previous(i).kind) && feedback(i).status==TdpStatus.Running ...
        && feedback(i).requestId==previous(i).requestId;
    interrupted=pending && (~kicking(raw(i).kind) || raw(i).requestId~=previous(i).requestId);
    locked=false;
    if isfield(state,'cancelPending') && (i==3 || i==7)
        locked=state.releaseId~=0;
        if locked
            revoke=revoke || state.cancelPending || ~kicking(raw(i).kind) || ...
                raw(i).requestId~=state.releaseId || t>state.releaseDeadline;
        end
    end
    if revoke || interrupted
        requests(i).kind=TdpAction.Stop;
        requests(i).velocity=[0 0 0];
        requests(i).target=[0 0];
        requests(i).speed=0;
        requests(i).stamp=t;
        requests(i).validUntil=t+P.walkValidity;
        if locked
            requests(i).requestId=state.releaseId;
        elseif pending
            requests(i).requestId=previous(i).requestId;
        end
    end
end
end

function yes=fresh(t,stamp,P)
yes=isfinite(stamp) && stamp<=t && t-stamp<=P.maxObservationAge;
end

function yes=kicking(action)
yes=action==TdpAction.Kick || action==TdpAction.Tap;
end
