function build_single()
%BUILD_SINGLE Generate an actual single-robot feedback loop with state delays.
root=tdpSetup();name='tdpSingleRobot';if bdIsLoaded(name),close_system(name,0);end
new_system(name);configure_model(name);set_param(name,'StopTime','15-P.dt');
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;T=tdpTemplates(P);world=T.World;
world.active(2:8)=false;world.robots(1).x=-1;world.robots(1).role=TdpRole.ST;
for i=2:8,world.robots(i).x=20+2*i;world.robots(i).y=20;end
intent=T.Intent;intent.type=TdpAction.Kick;intent.target=[4.5 0];intent.speed=P.shotSpeed;intent.role=TdpRole.ST;
w=get_param(name,'ModelWorkspace');assignin(w,'P',P);assignin(w,'world0',world);assignin(w,'singleIntent',intent);assignin(w,'feedback0',repmat(T.Feedback,1,8));
add_block('simulink/Sources/Digital Clock',[name '/Clock'],'SampleTime','P.dt','Position',[20 20 70 50]);
add_block('simulink/Math Operations/Bias',[name '/StepTime'],'Bias','P.dt','Position',[110 20 160 50]);
add_line(name,'Clock/1','StepTime/1');
add_block('simulink/Discrete/Unit Delay',[name '/WorldMemory'],'InitialCondition','world0','SampleTime','P.dt','Position',[50 160 110 210]);
add_block('simulink/Discrete/Unit Delay',[name '/FeedbackMemory'],'InitialCondition','feedback0','SampleTime','P.dt','Position',[500 400 570 440]);
add_matlab_block([name '/Observation2D'],sprintf('function obs=f(world,tSim,P)\nobs=Observation2D(world,1,tSim,P);\nend'),[190 140 330 220], ...
 {'world','Bus: WorldBus','Input';'obs','Bus: ObservationBus','Output';'P','Inherit: Same as Simulink','Parameter'});
add_block('simulink/Sources/Constant',[name '/Intent'],'Value','singleIntent','OutDataTypeStr','Bus: IntentBus','Position',[210 270 310 310]);
add_matlab_block([name '/Feedback1'],sprintf('function fb=f(allFeedback)\nfb=allFeedback(1);\nend'),[330 370 430 430], ...
 {'allFeedback','Bus: FeedbackBus','Input';'fb','Bus: FeedbackBus','Output'});
load_system('ControllerCore');add_block('ControllerCore/Core',[name '/ControllerCore'],'Position',[430 140 650 300]);
add_matlab_block([name '/RequestArray'],sprintf(['function requests=f(req)\nrequests=repmat(req,1,8);\n' ...
 'for i=2:8,requests(i).kind=TdpAction.Stop;requests(i).velocity=[0 0 0];end\nend']),[700 140 850 220], ...
 {'req','Bus: RequestBus','Input';'requests','Bus: RequestBus','Output'});
add_matlab_block([name '/Plant2D'],sprintf('function [next,feedback]=f(world,requests,tSim,P)\n[next,feedback]=Plant2D(world,requests,tSim,P);\nend'),[920 130 1110 290], ...
 {'world','Bus: WorldBus','Input';'requests','Bus: RequestBus','Input';'next','Bus: WorldBus','Output';'feedback','Bus: FeedbackBus','Output';'P','Inherit: Same as Simulink','Parameter'});
add_matlab_block([name '/Record'],sprintf(['function y=f(world,req,phase,fb)\nr=world.robots(1);b=world.ball;\n' ...
 'y=[r.x r.y r.th b.x b.y b.vx b.vy double(world.kickCount) double(req.kind) double(req.requestId) double(phase) double(fb(1).status) double(fb(1).requestId) double(world.actuator(1).executions)];\nend']), ...
 [920 370 1110 470],{'world','Bus: WorldBus','Input';'req','Bus: RequestBus','Input';'phase','Enum: TdpPhase','Input';'fb','Bus: FeedbackBus','Input'});
add_block('simulink/Sinks/To Workspace',[name '/Records'],'VariableName','records','SaveFormat','Array','Position',[1180 400 1280 430]);
lines={'WorldMemory/1','Observation2D/1';'StepTime/1','Observation2D/2';'Observation2D/1','ControllerCore/1';'Intent/1','ControllerCore/2'; ...
 'FeedbackMemory/1','Feedback1/1';'Feedback1/1','ControllerCore/3';'StepTime/1','ControllerCore/4';'ControllerCore/1','RequestArray/1'; ...
 'WorldMemory/1','Plant2D/1';'RequestArray/1','Plant2D/2';'StepTime/1','Plant2D/3';'Plant2D/1','WorldMemory/1'; ...
 'Plant2D/2','FeedbackMemory/1';'Plant2D/1','Record/1';'ControllerCore/1','Record/2';'ControllerCore/2','Record/3';'Plant2D/2','Record/4';'Record/1','Records/1'};
for k=1:size(lines,1),add_line(name,lines{k,1},lines{k,2},'autorouting','on');end
set_data_size([name '/Plant2D'],'feedback','[1 8]');
set_data_size([name '/Plant2D'],'requests','[1 8]');
set_data_size([name '/RequestArray'],'requests','[1 8]');
set_data_size([name '/Feedback1'],'allFeedback','[1 8]');
save_system(name,fullfile(root,'models',[name '.slx']));close_system(name,0);
end
