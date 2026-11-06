function [input,model]=matchSimulationInput(P)
%MATCHSIMULATIONINPUT Configure the same match for unattended and live use.
tdp.validateConfig(P);
assert(P.observationDelay==0 && P.observationNoise==0,'TDP:SensorAdapter', ...
    'Use sensorReplay for the delayed/noisy sensor experiment.');
model='tdpMatch';
if isfield(P,'v1Enabled') && P.v1Enabled
    tdp.validateV1Config(P);
    model='tdpV1Match';
    if isfield(P,'v1AutoRecovery') && P.v1AutoRecovery
        model='tdpRecoveryMatch';
    end
end
if bdIsLoaded(model)
    root=fileparts(fileparts(mfilename('fullpath')));
    assert(strcmp(get_param(model,'FileName'),fullfile(root,'models',[model '.slx'])), ...
        'TDP:MatchModel','A different copy of %s is loaded. Use a separate MATLAB process.',model);
    assert(strcmp(get_param(model,'SimulationStatus'),'stopped'), ...
        'TDP:MatchBusy','%s is already running.',model);
end
input=Simulink.SimulationInput(model);
input=input.setVariable('P',P,'Workspace',model);
templates=tdpTemplates(P);
input=input.setVariable('world0',templates.World,'Workspace',model);
input=input.setModelParameter('StopTime',num2str(P.Tmatch-P.dt,17));
end
