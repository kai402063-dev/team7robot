function row=RecoveryRecord(tSim,health,blue,red)
%RECOVERYRECORD Log delivered heartbeats and both coordinators' current decisions.
c=v1RecoveryColumns();
row=zeros(1,53);
row(c.time)=tSim;
for i=1:8
    h=health(i);
    row(c.reason(i))=double(h.reason);
    row(c.ready(i))=h.ready;
    row(c.stamp(i))=h.stamp;
    row(c.requestId(i))=double(h.requestId);
    row(c.activeId(i))=double(h.activeId);
end
row(c.healthySince)=[blue.healthySince red.healthySince];
row(c.healthTiming)=[blue.healthTiming red.healthTiming];
row(c.releaseId)=double([blue.releaseId red.releaseId]);
row(c.cancelPending)=[blue.cancelPending red.cancelPending];
row(c.releaseDeadline)=[blue.releaseDeadline red.releaseDeadline];
row(c.failureReason)=[double(blue.failureReason) double(red.failureReason)];
end
