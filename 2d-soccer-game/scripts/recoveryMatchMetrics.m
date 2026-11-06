function report=recoveryMatchMetrics(tactics,recovery,P)
%RECOVERYMATCHMETRICS Check actual grants against health and request lifetimes.
c=v1TraceColumns();
h=v1RecoveryColumns();
time=tactics(:,c.time);
assert(size(recovery,1)==numel(time) && all(isfinite(recovery),'all') && ...
    isequal(recovery(:,h.time),time),'TDP:RecoveryLog','Invalid recovery timebase or samples.');
for team=1:2
    st=4*team;
    mf=st-1;
    takeover=logical(tactics(:,c.takeover(team)));
    entries=find(diff([false;takeover])==1);
    returns=find(diff([false;takeover])==-1);
    lockedId=recovery(:,h.releaseId(team));
    locked=lockedId~=0;
    draining=locked & logical(tactics(:,c.recovering(team)));
    cancel=logical(recovery(:,h.cancelPending(team)));
    kind=tactics(:,c.kind(mf));
    id=tactics(:,c.requestId(mf));
    kick=ismember(kind,double([TdpAction.Kick TdpAction.Tap]));
    automatic=tdp.recoveryTeamSelected(P,team);
    if automatic
        assert(all(id(locked)==lockedId(locked)) && all(~locked | takeover), ...
            'TDP:RecoveryId','The MF changed ID before release.');
        assert(all(~locked | tactics(:,c.chaser(team))~=st),'TDP:DoubleGrant','ST regained the grant with an MF request outstanding.');
        assert(all(~cancel | (locked & kind==double(TdpAction.Stop))),'TDP:RecoveryStop','Missing same-ID cancellation.');
        assert(all(~locked | ~kick | time<=recovery(:,h.releaseDeadline(team))+1e-10), ...
            'TDP:RecoveryDeadline','A retained kick exceeded its original deadline.');
        % At sample k the coordinator consumes the health produced at k-1.
        % Audit the full run of consecutive usable samples before every release.
        stamp=recovery(:,h.stamp(st));
        healthy=tactics(2:end,c.available(st))~=0 & recovery(1:end-1,h.ready(st))~=0 & ...
            recovery(1:end-1,h.activeId(st))==0 & stamp(1:end-1)<=time(2:end) & ...
            time(2:end)-stamp(1:end-1)<=P.dt+1e-10;
        for k=returns'
            onset=entries(find(entries<k,1,'last'));
            first=k-ceil((P.v1RecoveryHealthySeconds-1e-10)/P.dt);
            assert(first>=max(2,onset) && all(healthy(first-1:k-1)) && ...
                stamp(k-1)-stamp(first-1)>=P.v1RecoveryHealthySeconds-1e-10, ...
                'TDP:EarlyRecovery','Team %d released the handback before a continuous healthy interval at %.4f s.',team,time(k));
        end
    end
    ended=[returns;numel(time)+1];
    durations=zeros(size(entries));
    for n=1:numel(entries)
        durations(n)=(ended(find(ended>entries(n),1))-entries(n))*P.dt;
    end
    report.entries(team)=numel(entries);
    report.returns(team)=numel(returns);
    report.stillTakenOverAtEnd(team)=takeover(end);
    report.maximumTakeoverSeconds(team)=max([0;durations]);
    report.mfKicksDuringHandback(team)=nnz(draining & tactics(:,c.kicker)==mf);
    report.cancelSamples(team)=nnz(cancel);
end
end
