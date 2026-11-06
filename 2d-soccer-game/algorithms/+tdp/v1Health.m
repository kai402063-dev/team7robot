function packet=v1Health()
%V1HEALTH Initial per-robot executor heartbeat in the recovery experiment.
packet=struct('reason',TdpV1Reason.None,'ready',true,'stamp',0, ...
    'requestId',uint32(0),'activeId',uint32(0));
end
