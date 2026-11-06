function req=EmitRequest(g,phase,id,kickStart,kickTarget,kickSpeed,tSim,P)
%EMITREQUEST Convert skill phase to the fixed request contract.
req=struct('requestId',id,'kind',TdpAction.Stop,'velocity',[0 0 0], ...
 'target',[0 0],'speed',0,'stamp',tSim,'validUntil',tSim+P.walkValidity);
if ~g.safe,return;end
if P.mode==TdpMode.Compat
 if P.freezeDuringPause && ~g.running,return;end
 req.kind=TdpAction.Goto;req.velocity=g.command;
 if g.ready
  req.kind=TdpAction.Kick;req.target=g.target;req.speed=g.speed;
  if g.intent==TdpAction.Tap,req.kind=TdpAction.Tap;end
 end
 return
end
if ~g.running,return;end
if phase==TdpPhase.Search
 req.kind=TdpAction.Search;req.velocity=[0 0 P.searchTurnRate];
elseif phase==TdpPhase.Approach || phase==TdpPhase.Align
 req.kind=TdpAction.Goto;req.velocity=g.command;
elseif phase==TdpPhase.Kick
 req.kind=TdpAction.Kick;req.target=kickTarget;req.speed=kickSpeed;
 if g.intent==TdpAction.Tap,req.kind=TdpAction.Tap;end
 req.stamp=kickStart;req.validUntil=kickStart+P.kickTimeout;
end
end
