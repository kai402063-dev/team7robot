function m=recoveryTeamMemory()
%RECOVERYTEAMMEMORY Extra state used only by the automatic recovery experiment.
m=tdp.v1TeamMemory();
m.healthTiming=false;
m.healthySince=0;
m.lastHealthyStamp=0;
m.cancelPending=false;
m.releaseDeadline=0;
m.failureReason=TdpV1Reason.None;
end
