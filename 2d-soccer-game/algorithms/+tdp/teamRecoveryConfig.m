function P=teamRecoveryConfig(automaticByTeam)
%TEAMRECOVERYCONFIG Select the existing recovery policy for [blue red].
assert(islogical(automaticByTeam) && isequal(size(automaticByTeam),[1 2]), ...
    'TDP:TeamRecoveryMask','Provide a 1-by-2 logical row [blue red].');
P=tdp.recoveryConfig();
P.v1AutoRecoveryTeams=automaticByTeam;
end
