function [health,feedback]=RecoveryFeedback2D(deviceHealth,deviceFeedback,heldHealth,heldFeedback,tSim,P)
%RECOVERYFEEDBACK2D Model a lost return link by retaining the entire last packet.
health=deviceHealth;
feedback=deviceFeedback;
for i=1:8
    if tdp.recoveryTeamSelected(P,1+(i>4)) && ...
            tSim>=P.v1HealthDropWindow(i,1) && tSim<P.v1HealthDropWindow(i,2)
        health(i)=heldHealth(i);
        feedback(i)=heldFeedback(i);
    end
end
end
