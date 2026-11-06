function selected=recoveryTeamSelected(P,team)
%RECOVERYTEAMSELECTED Apply the optional team mask inside a recovery component.
% The original recovery components apply to both teams when there is no mask.
selected=~isfield(P,'v1AutoRecoveryTeams') || P.v1AutoRecoveryTeams(team);
end
