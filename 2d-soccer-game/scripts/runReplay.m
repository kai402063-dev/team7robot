function records=runReplay(P,scenario,model)
%RUNREPLAY Execute the actual library chart with supplied observations only.
if nargin<3,model='tdpReplay';end
input=Simulink.SimulationInput(model);
input=input.setVariable('P',P,'Workspace',model);input=input.setVariable('scenario',scenario,'Workspace',model);
input=input.setModelParameter('StopTime',num2str((numel(scenario)-1)*P.dt,17));
out=sim(input);records=recordRows(out.records);
end
