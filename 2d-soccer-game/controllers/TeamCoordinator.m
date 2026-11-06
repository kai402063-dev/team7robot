function [plans,striker]=TeamCoordinator(obs,team,previous,P)
%TEAMCOORDINATOR Own one team's role memory, using observations only.
[plans,m]=tdp.teamBehaviour(obs.robots,obs.ball,team,struct('striker',previous),P);
striker=m.striker;
if P.fixedStriker
 roles=[TdpRole.GK TdpRole.ST TdpRole.DF TdpRole.SP];
 plans=tdp.actionSelection(obs.robots,obs.ball,team,roles,P);striker=2;
end
end
