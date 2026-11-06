function build_replay(name,outFolder)
%BUILD_REPLAY Model for input-only controller tests.
root=tdpSetup();if nargin<1,name='tdpReplay';end
if nargin<2,outFolder=fullfile(root,'models');end
if ~isfolder(outFolder),mkdir(outFolder);end
if bdIsLoaded(name),close_system(name,0);end
new_system(name);configure_model(name);P=tdp.defaultConfig();P.mode=TdpMode.Delayed;
w=get_param(name,'ModelWorkspace');assignin(w,'P',P);assignin(w,'scenario',makeScenario(P,2));
add_block('simulink/Sources/Digital Clock',[name '/Clock'],'SampleTime','P.dt','Position',[20 50 70 80]);
add_matlab_block([name '/Replay'],sprintf(['function [obs,intent,feedback]=f(tSim,scenario,P)\n' ...
 'k=min(numel(scenario),max(1,round(tSim/P.dt)+1));\nobs=scenario(k).obs;intent=scenario(k).intent;feedback=scenario(k).feedback;\nend']), ...
 [140 30 290 180],{'obs','Bus: ObservationBus','Output';'intent','Bus: IntentBus','Output';'feedback','Bus: FeedbackBus','Output';'scenario','Inherit: Same as Simulink','Parameter';'P','Inherit: Same as Simulink','Parameter'});
load_system('ControllerCore');add_block('ControllerCore/Core',[name '/ControllerCore'],'Position',[370 30 600 210]);
for k=1:3,add_line(name,sprintf('Replay/%d',k),sprintf('ControllerCore/%d',k));end
add_line(name,'Clock/1','Replay/1');add_line(name,'Clock/1','ControllerCore/4');
add_matlab_block([name '/Record'],sprintf(['function y=f(req,phase)\ny=[double(req.kind) double(req.requestId) double(phase) ' ...
 'req.velocity req.target req.speed req.stamp req.validUntil];\nend']), ...
 [680 60 820 170],{'req','Bus: RequestBus','Input';'phase','Enum: TdpPhase','Input'});
add_line(name,'ControllerCore/1','Record/1');add_line(name,'ControllerCore/2','Record/2');
add_block('simulink/Sinks/To Workspace',[name '/Records'],'VariableName','records','SaveFormat','Array','Position',[900 90 1000 120]);
add_line(name,'Record/1','Records/1');save_system(name,fullfile(outFolder,[name '.slx']));close_system(name,0);
end
