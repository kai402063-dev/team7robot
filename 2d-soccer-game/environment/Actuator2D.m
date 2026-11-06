function [memory,feedback,cmd,doKick,kickV,reason]=Actuator2D(memory,req,obs,tSim,P,allowKick,noiseSample,forceFailure)
%ACTUATOR2D Idempotent action execution with simulation-time deadlines.
reason=TdpV1Reason.None;
strict=isfield(P,'v1AutoRecovery') && P.v1AutoRecovery;
cmd=[0 0 0];doKick=false;kickV=[0 0];feedback=memory.feedback;
if (~obs.gameRunning && P.mode==TdpMode.Delayed) || req.kind==TdpAction.Stop
 if memory.active
  if strict && obs.gameRunning && req.kind==TdpAction.Stop && req.requestId~=memory.seenId
   feedback=struct('requestId',req.requestId,'status',TdpStatus.Rejected,'stamp',tSim);
   return
  end
  reason=TdpV1Reason.Canceled;
  memory.active=false;memory.feedback.status=TdpStatus.Failed;memory.feedback.stamp=tSim;
 end
 feedback=memory.feedback;return
end
if req.kind~=TdpAction.Kick && req.kind~=TdpAction.Tap
 if tSim>=req.stamp && tSim<=req.validUntil
  cmd=req.velocity;
 else
  reason=TdpV1Reason.Expired;
  feedback=struct('requestId',req.requestId,'status',TdpStatus.Rejected,'stamp',tSim);
 end
 return
end
if strict && memory.active && req.requestId==memory.seenId && tSim>req.validUntil
 memory.active=false;memory.feedback.status=TdpStatus.Failed;memory.feedback.stamp=tSim;
 feedback=memory.feedback;reason=TdpV1Reason.Expired;return
end
if req.requestId==0 || req.requestId<memory.seenId || (req.requestId<=memory.rejectedId && req.requestId~=memory.seenId)
 feedback=struct('requestId',req.requestId,'status',TdpStatus.Rejected,'stamp',tSim);return
end
if req.requestId>memory.seenId
 if memory.active || tSim<req.stamp || tSim>req.validUntil
  if tSim>req.validUntil,reason=TdpV1Reason.Expired;end
  memory.rejectedId=max(memory.rejectedId,req.requestId);
  feedback=struct('requestId',req.requestId,'status',TdpStatus.Rejected,'stamp',tSim);return
 end
 memory.seenId=req.requestId;memory.active=true;memory.start=tSim;
 memory.target=req.target;memory.speed=req.speed;memory.executions=memory.executions+uint32(1);
 memory.feedback=struct('requestId',req.requestId,'status',TdpStatus.Running,'stamp',tSim);
end
if memory.active && (P.mode==TdpMode.Compat || tSim-memory.start+1e-12>=P.kickPreparation)
 [~,ready,kv]=tdp.kickSkill(obs.robots(obs.selfIndex),obs.ball,memory.target,memory.speed, ...
  obs.robots,obs.selfIndex,allowKick && obs.gameRunning,P,noiseSample);
 memory.active=false;memory.feedback.stamp=tSim;
 if ready && ~forceFailure
  doKick=true;kickV=kv;memory.feedback.status=TdpStatus.Done;
 else
  memory.feedback.status=TdpStatus.Failed;
  if forceFailure
   reason=TdpV1Reason.Subsystem;
  elseif ~allowKick
   reason=TdpV1Reason.Arbitration;
  else
   reason=TdpV1Reason.Geometry;
  end
 end
end
feedback=memory.feedback;
end
