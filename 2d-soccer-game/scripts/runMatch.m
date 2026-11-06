function [trace,tactics,recovery]=runMatch(P)
%RUNMATCH Run eight controller instances and return one row per control step.
if nargin==0
    P=tdp.v1Config();
end
previousRng=rng;
restoreRng=onCleanup(@()rng(previousRng)); %#ok<NASGU>
rng(P.seed,'twister');
[input,model]=matchSimulationInput(P);
output=sim(input);
trace=recordRows(output.records);
if nargout>1
    if ~strcmp(model,'tdpMatch')
        tactics=recordRows(output.tacticsRecords);
    else
        tactics=zeros(size(trace,1),0);
    end
end
if nargout>2
    if strcmp(model,'tdpRecoveryMatch') || strcmp(model,'tdpTeamRecoveryMatch')
        recovery=recordRows(output.recoveryRecords);
    else
        recovery=zeros(size(trace,1),0);
    end
end
end
