function [plans,state]=teamPolicyPlans(obs,team,previous,requests,feedback,health,P)
%TEAMPOLICYPLANS Route each coordinator to its original policy interface.
if tdp.recoveryTeamSelected(P,team)
    [plans,state]=tdp.v1TeamPlans(obs,team,previous,requests,feedback,false,P,health);
else
    t=obs(1).tSim;
    recovered=t>=P.v1RecoveryWindow(team,1) && t<P.v1RecoveryWindow(team,2);
    [plans,state]=tdp.v1TeamPlans(obs,team,previous,requests,feedback,recovered,P);
end
end
