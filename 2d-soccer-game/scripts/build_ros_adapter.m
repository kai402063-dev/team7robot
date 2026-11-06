function build_ros_adapter()
%BUILD_ROS_ADAPTER Reuse Core with identical frame decoding in both transports.
root=tdpSetup();
for online=[false true]
 if online,name='tdpRosProxy';else,name='tdpFrameReplay';end
 if bdIsLoaded(name),close_system(name,0);end
 new_system(name);configure_model(name);P=tdp.defaultConfig();P.dt=0.04;P.mode=TdpMode.Delayed;
 w=get_param(name,'ModelWorkspace');assignin(w,'P',P);assignin(w,'frames',makeBridgeFrames(P,101));
 add_block('simulink/Sources/Digital Clock',[name '/Schedule'],'SampleTime','P.dt','Position',[20 30 70 60]);
 if online
  script=sprintf('function frame=f(t)\ncoder.extrinsic(''BridgeRead'');\nframe=zeros(1,20);frame=BridgeRead();\nend');types={};
 else
  script=sprintf('function frame=f(t,frames,P)\nk=min(size(frames,1),round(t/P.dt)+1);frame=frames(k,:);\nend');
  types={'frames','Inherit: Same as Simulink','Parameter';'P','Inherit: Same as Simulink','Parameter'};
 end
 if isempty(types),add_matlab_block([name '/Receive'],script,[110 20 240 90]);
 else,add_matlab_block([name '/Receive'],script,[110 20 240 90],types);end
 set_data_size([name '/Receive'],'frame','[1 20]');
 add_line(name,'Schedule/1','Receive/1');
 add_block('simulink/Discrete/Unit Delay',[name '/LastAcceptedFrame'],'InitialCondition','zeros(1,20)','SampleTime','P.dt','Position',[270 260 410 300]);
 add_matlab_block([name '/Decode'],sprintf('function [obs,intent,fb,tSim,quality,held]=f(frame,previous,P)\n[obs,intent,fb,tSim,quality,held]=BridgeDecode(frame,previous,P);\nend'), ...
 [300 20 470 210],{'P','Inherit: Same as Simulink','Parameter';'obs','Bus: ObservationBus','Output';'intent','Bus: IntentBus','Output';'fb','Bus: FeedbackBus','Output'});
 for field={'frame','previous','held'},set_data_size([name '/Decode'],field{1},'[1 20]');end
 set_data_size([name '/Decode'],'quality','[1 6]');
 add_line(name,'Receive/1','Decode/1');add_line(name,'LastAcceptedFrame/1','Decode/2');add_line(name,'Decode/6','LastAcceptedFrame/1');
 load_system('ControllerCore');add_block('ControllerCore/Core',[name '/ControllerCore'],'Position',[550 20 770 200]);
 for k=1:4,add_line(name,sprintf('Decode/%d',k),sprintf('ControllerCore/%d',k));end
 add_matlab_block([name '/Record'],sprintf(['function y=f(req,phase)\ny=[double(req.kind) double(req.requestId) double(phase) ' ...
 'req.velocity req.target req.speed req.stamp req.validUntil];\nend']),[820 40 940 150],{'req','Bus: RequestBus','Input';'phase','Enum: TdpPhase','Input'});
 add_line(name,'ControllerCore/1','Record/1');add_line(name,'ControllerCore/2','Record/2');
 for entry={'records','quality'}
  label=entry{1};add_block('simulink/Sinks/To Workspace',[name '/' label],'VariableName',label,'SaveFormat','Array','Position',[1020 30+80*strcmp(label,'quality') 1120 60+80*strcmp(label,'quality')]);
 end
 add_line(name,'Record/1','records/1');add_line(name,'Decode/5','quality/1');
 if online
  add_matlab_block([name '/Send'],sprintf('function ack=f(y)\ncoder.extrinsic(''BridgeWrite'');\nack=0;ack=BridgeWrite(y);\nend'),[820 250 940 290]);
  add_line(name,'Record/1','Send/1');add_block('simulink/Sinks/Terminator',[name '/Sent'],'Position',[1020 260 1040 280]);add_line(name,'Send/1','Sent/1');
 end
 save_system(name,fullfile(root,'models',[name '.slx']));close_system(name,0);
end
end
