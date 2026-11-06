function [next,feedback,kicker,health]=RecoveryPlant2D(world,requests,plans,tSim,previousHealth,P)
%RECOVERYPLANT2D Publish executor state independently of a terminal feedback event.
fail=tSim>=P.v1FailWindow(:,1)' & tSim<P.v1FailWindow(:,2)';
for i=1:8
    world.robots(i).role=plans(i).role;
end
[next,feedback,kicker,reasons]=Plant2D(world,requests,tSim,P,fail);
health=repmat(tdp.v1Health(),1,8);
for i=1:8
    device=next.actuator(i);
    if ~world.active(i)
        if device.active
            device.active=false;
            device.feedback.status=TdpStatus.Failed;
            device.feedback.stamp=tSim;
            next.actuator(i)=device;
            reasons(i)=TdpV1Reason.Subsystem;
        end
        % V1 sends an empty receipt for an inactive device already at rest.
        if world.actuator(i).active || tdp.recoveryTeamSelected(P,1+(i>4))
            feedback(i)=device.feedback;
        end
    end
    fb=feedback(i);
    reason=reasons(i);
    if reason==TdpV1Reason.None && fb.status==TdpStatus.Failed && fb.requestId==previousHealth(i).requestId
        % A sticky terminal feedback keeps its cause even through a radio outage.
        reason=previousHealth(i).reason;
    end
    health(i).reason=reason;
    health(i).stamp=tSim;
    health(i).requestId=fb.requestId;
    health(i).ready=world.active(i) && ~fail(i) && ~device.active;
    if device.active
        health(i).activeId=device.seenId;
    end
end
end
