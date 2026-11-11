function build_match(n)
%BUILD_MATCH Generate eight independent library cores and two coordinators.
root=tdpSetup();
if nargin<1,n='tdpMatch';end
teamPolicy=strcmp(n,'tdpTeamRecoveryMatch');
recovery=strcmp(n,'tdpRecoveryMatch') || teamPolicy;
v1=strcmp(n,'tdpV1Match') || recovery;
teamType='Bus: V1TeamBus';
assert(v1 || strcmp(n,'tdpMatch'),'TDP:MatchModel','Unknown match model');
if bdIsLoaded(n),close_system(n,0);end
new_system(n);configure_model(n);set_param(n,'StopTime','P.Tmatch-P.dt');
if recovery
 if teamPolicy, P=tdp.teamRecoveryConfig([false true]); else, P=tdp.recoveryConfig(); end
 set_param(n,'DataDictionary','TdpRecoveryTypes.sldd');
 teamType='Bus: RecoveryTeamBus';
elseif v1
 P=tdp.v1Config();set_param(n,'DataDictionary','TdpV1Types.sldd');
else
 P=tdp.defaultConfig();
end
T=tdpTemplates(P);w=get_param(n,'ModelWorkspace');
assignin(w,'P',P);assignin(w,'world0',T.World);assignin(w,'feedback0',repmat(T.Feedback,1,8));
add_block('simulink/Sources/Digital Clock',[n '/Clock'],'SampleTime','P.dt','Position',[20 20 70 50]);
add_matlab_block([n '/StepTime'],sprintf('function t=f(clock,P)\nt=round(clock/P.dt+1)*P.dt;\nend'),[120 20 180 50],{'P','Inherit: Same as Simulink','Parameter'});
add_line(n,'Clock/1','StepTime/1');
add_block('simulink/Discrete/Unit Delay',[n '/WorldMemory'],'InitialCondition','world0','SampleTime','P.dt','Position',[20 150 100 210]);
add_block('simulink/Discrete/Unit Delay',[n '/FeedbackMemory'],'InitialCondition','feedback0','SampleTime','P.dt','Position',[1200 900 1300 950]);
if v1
 observationScript=sprintf('function observations=f(world,tSim,P)\nobservations=V1Observation2D(world,tSim,P);\nend');
 assignin(w,'request0',repmat(T.Request,1,8));
 if recovery
  assignin(w,'v1Memory0',tdp.recoveryTeamMemory());
  assignin(w,'health0',repmat(tdp.v1Health(),1,8));
  add_block('simulink/Discrete/Unit Delay',[n '/HealthMemory'],'InitialCondition','health0','SampleTime','P.dt','Position',[1200 1010 1300 1060]);
  add_block('simulink/Discrete/Unit Delay',[n '/DeviceHealthMemory'],'InitialCondition','health0','SampleTime','P.dt','Position',[1720 1000 1820 1050]);
 else
  assignin(w,'v1Memory0',tdp.v1TeamMemory());
  % Draft v1.1 fallback monitor state and last tick's skill phases (inactive
  % unless P.v11Fallback is true; see tdp.v11FallbackConfig).
  assignin(w,'v11Memory0',tdp.v11FallbackMemory());assignin(w,'skill0',zeros(1,8));
  add_block('simulink/Discrete/Unit Delay',[n '/SkillMemory'],'InitialCondition','skill0','SampleTime','P.dt','Position',[1500 1100 1590 1150]);
 end
 add_block('simulink/Discrete/Unit Delay',[n '/RequestMemory'],'InitialCondition','request0','SampleTime','P.dt','Position',[1300 950 1410 1000]);
else
 observationScript=sprintf('function observations=f(world,tSim,P)\nobservations=repmat(Observation2D(world,1,tSim,P),1,8);\nfor i=1:8,observations(i)=Observation2D(world,i,tSim,P);end\nend');
end
add_matlab_block([n '/Observation2D'],observationScript,[160 130 310 210], ...
 {'world','Bus: WorldBus','Input';'observations','Bus: ObservationBus','Output';'P','Inherit: Same as Simulink','Parameter'});
set_data_size([n '/Observation2D'],'observations','[1 8]');
add_line(n,'WorldMemory/1','Observation2D/1');add_line(n,'StepTime/1','Observation2D/2');
for team=1:2
 label=sprintf('Team%d',team);y=200+team*170;
 if v1
  addV1Team(n,label,team,y,recovery,teamType,teamPolicy);
 else
  mem=[label 'StrikerMemory'];
 add_block('simulink/Discrete/Unit Delay',[n '/' mem],'InitialCondition','0','SampleTime','P.dt','Position',[170 y 230 y+40]);
 script=sprintf('function [plans,striker]=f(observations,previous,P)\n[plans,striker]=TeamCoordinator(observations(%d),%d,previous,P);\nend',1+4*(team-1),team);
 add_matlab_block([n '/' label],script,[370 y 520 y+90],{'observations','Bus: ObservationBus','Input';'plans','Bus: IntentBus','Output';'P','Inherit: Same as Simulink','Parameter'});
 set_data_size([n '/' label],'observations','[1 8]');set_data_size([n '/' label],'plans','[1 4]');
 add_line(n,'Observation2D/1',[label '/1']);add_line(n,[mem '/1'],[label '/2']);add_line(n,[label '/2'],[mem '/1']);
 end
end
add_matlab_block([n '/JoinPlans'],sprintf('function plans=f(blue,red)\nplans=[blue red];\nend'),[560 350 670 430], ...
 {'blue','Bus: IntentBus','Input';'red','Bus: IntentBus','Input';'plans','Bus: IntentBus','Output'});
set_data_size([n '/JoinPlans'],'blue','[1 4]');set_data_size([n '/JoinPlans'],'red','[1 4]');set_data_size([n '/JoinPlans'],'plans','[1 8]');
add_line(n,'Team1/1','JoinPlans/1');add_line(n,'Team2/1','JoinPlans/2');
add_matlab_block([n '/KickArbiter'],sprintf('function observations=f(raw,plans,tSim,P)\nobservations=KickArbiter2D(raw,plans,tSim,P);\nend'),[560 120 720 240], ...
 {'raw','Bus: ObservationBus','Input';'plans','Bus: IntentBus','Input';'observations','Bus: ObservationBus','Output';'P','Inherit: Same as Simulink','Parameter'});
for key={'raw','plans','observations'},set_data_size([n '/KickArbiter'],key{1},'[1 8]');end
add_line(n,'Observation2D/1','KickArbiter/1');add_line(n,'JoinPlans/1','KickArbiter/2');add_line(n,'StepTime/1','KickArbiter/3');
load_system('ControllerCore');
for i=1:8
 label=sprintf('Robot%d',i);sel=[label 'Inputs'];y=80+(i-1)*140;
 script=sprintf('function [obs,intent,fb]=f(observations,plans,feedback)\nobs=observations(%d);intent=plans(%d);fb=feedback(%d);\nend',i,i,i);
 add_matlab_block([n '/' sel],script,[800 y 940 y+110],{'observations','Bus: ObservationBus','Input';'plans','Bus: IntentBus','Input';'feedback','Bus: FeedbackBus','Input';'obs','Bus: ObservationBus','Output';'intent','Bus: IntentBus','Output';'fb','Bus: FeedbackBus','Output'});
 for key={'observations','plans','feedback'},set_data_size([n '/' sel],key{1},'[1 8]');end
 add_block('ControllerCore/Core',[n '/' label],'Position',[1010 y 1200 y+110]);
 if ~v1
  add_block('simulink/Sinks/Terminator',[n '/' label 'Phase'],'Position',[1250 y+75 1270 y+95]);
  add_line(n,[label '/2'],[label 'Phase/1']);
 end
 add_line(n,'KickArbiter/1',[sel '/1']);add_line(n,'JoinPlans/1',[sel '/2']);add_line(n,'FeedbackMemory/1',[sel '/3']);
 for j=1:3,add_line(n,sprintf('%s/%d',sel,j),sprintf('%s/%d',label,j));end
 add_line(n,'StepTime/1',[label '/4']);
end
add_matlab_block([n '/JoinRequests'],sprintf('function requests=f(a,b,c,d,e,f,g,h)\nrequests=[a b c d e f g h];\nend'),[1350 300 1480 700], ...
 {'a','Bus: RequestBus','Input';'b','Bus: RequestBus','Input';'c','Bus: RequestBus','Input';'d','Bus: RequestBus','Input';'e','Bus: RequestBus','Input';'f','Bus: RequestBus','Input';'g','Bus: RequestBus','Input';'h','Bus: RequestBus','Input';'requests','Bus: RequestBus','Output'});
set_data_size([n '/JoinRequests'],'requests','[1 8]');
for i=1:8,add_line(n,sprintf('Robot%d/1',i),sprintf('JoinRequests/%d',i));end
if v1
 addV1Authorization(n,teamType);
 plantScript=sprintf('function [next,feedback,kicker]=f(world,requests,plans,tSim,P)\n[next,feedback,kicker]=V1Plant2D(world,requests,plans,tSim,P);\nend');
 requestSource='AuthorizeRequests/1';
 strikerPort='/3';
else
 plantScript=sprintf('function [next,feedback]=f(world,requests,plans,tSim,P)\n[next,feedback]=MatchPlant2D(world,requests,plans,tSim,P);\nend');
 requestSource='JoinRequests/1';
 strikerPort='/2';
end
plantPorts={'world','Bus: WorldBus','Input';'requests','Bus: RequestBus','Input';'plans','Bus: IntentBus','Input';'next','Bus: WorldBus','Output';'feedback','Bus: FeedbackBus','Output';'P','Inherit: Same as Simulink','Parameter'};
feedbackSource='Plant2D/2';
if recovery
 plantScript=sprintf('function [next,feedback,kicker,health]=f(world,requests,plans,tSim,previousHealth,P)\n[next,feedback,kicker,health]=RecoveryPlant2D(world,requests,plans,tSim,previousHealth,P);\nend');
 plantPorts=[plantPorts;{'previousHealth','Bus: V1HealthBus','Input';'health','Bus: V1HealthBus','Output'}];
 feedbackSource='RecoveryFeedback/2';
end
add_matlab_block([n '/Plant2D'],plantScript,[1550 300 1720 530],plantPorts);
if recovery
 set_data_size([n '/Plant2D'],'previousHealth','[1 8]');set_data_size([n '/Plant2D'],'health','[1 8]');
 addRecoveryFeedback(n);
end
for key={'requests','plans','feedback'},set_data_size([n '/Plant2D'],key{1},'[1 8]');end
add_matlab_block([n '/Record'],sprintf('function row=f(world,blue,red)\nrow=MatchRecord(world,blue,red);\nend'),[1800 300 1930 430],{'world','Bus: WorldBus','Input'});
add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[2000 350 2100 390]);
lines={'WorldMemory/1','Plant2D/1';requestSource,'Plant2D/2';'JoinPlans/1','Plant2D/3';'StepTime/1','Plant2D/4';'Plant2D/1','WorldMemory/1';feedbackSource,'FeedbackMemory/1';'Plant2D/1','Record/1';['Team1' strikerPort],'Record/2';['Team2' strikerPort],'Record/3';'Record/1','Records/1'};
for k=1:size(lines,1),add_line(n,lines{k,1},lines{k,2},'autorouting','on');end
if v1,addV1Log(n,teamType,feedbackSource);end
if v1 && ~recovery,add_line(n,'JoinSkills/1','SkillMemory/1','autorouting','on');end
if recovery,addRecoveryLog(n,teamType);end
save_system(n,fullfile(root,'models',[n '.slx']));close_system(n,0);
end

function addV1Team(n,label,team,y,recovery,teamType,teamPolicy)
memory=[label 'Memory'];
add_block('simulink/Discrete/Unit Delay',[n '/' memory], ...
    'InitialCondition','v1Memory0','SampleTime','P.dt','Position',[170 y 265 y+45]);
script=sprintf(['function [plans,state,localOwner]=f(obs,previous,requests,feedback,P)\n' ...
    't=obs(1).tSim;\n' ...
    'recovered=t>=P.v1RecoveryWindow(%d,1) && t<P.v1RecoveryWindow(%d,2);\n' ...
    '[plans,state]=tdp.v1TeamPlans(obs,%d,previous,requests,feedback,recovered,P);\n' ...
    'localOwner=0;\nif state.chaser>0,localOwner=state.chaser-%d;end\nend'],team,team,team,4*(team-1));
ports={'obs','Bus: ObservationBus','Input';'previous',teamType,'Input'; ...
    'requests','Bus: RequestBus','Input';'feedback','Bus: FeedbackBus','Input'; ...
    'plans','Bus: IntentBus','Output';'state',teamType,'Output'; ...
    'P','Inherit: Same as Simulink','Parameter'};
if recovery
    call=sprintf('tdp.v1TeamPlans(obs,%d,previous,requests,feedback,false,P,health)',team);
    if teamPolicy
        call=sprintf('tdp.teamPolicyPlans(obs,%d,previous,requests,feedback,health,P)',team);
    end
    script=sprintf(['function [plans,state,localOwner]=f(obs,previous,requests,feedback,health,P)\n' ...
        '[plans,state]=%s;\n' ...
        'localOwner=0;\nif state.chaser>0,localOwner=state.chaser-%d;end\nend'],call,4*(team-1));
    ports=[ports;{'health','Bus: V1HealthBus','Input'}];
end
if ~recovery
    % Same approved V1 call plus the opt-in V1.1 fallback monitor (9 inputs).
    script=sprintf(['function [plans,state,localOwner,v11]=f(obs,previous,requests,feedback,v11previous,skills,P)\n' ...
        't=obs(1).tSim;\n' ...
        'recovered=t>=P.v1RecoveryWindow(%d,1) && t<P.v1RecoveryWindow(%d,2);\n' ...
        '[plans,state,v11]=tdp.v1TeamPlans(obs,%d,previous,requests,feedback,recovered,P,skills,v11previous);\n' ...
        'localOwner=0;\nif state.chaser>0,localOwner=state.chaser-%d;end\nend'],team,team,team,4*(team-1));
    v11memory=[label 'V11Memory'];
    add_block('simulink/Discrete/Unit Delay',[n '/' v11memory], ...
        'InitialCondition','v11Memory0','SampleTime','P.dt','Position',[170 y+60 265 y+100]);
end
add_matlab_block([n '/' label],script,[365 y 540 y+110],ports);
if recovery,set_data_size([n '/' label],'health','[1 8]');end
for key={'obs','requests','feedback'},set_data_size([n '/' label],key{1},'[1 8]');end
set_data_size([n '/' label],'plans','[1 4]');
sources={'Observation2D/1',[memory '/1'],'RequestMemory/1','FeedbackMemory/1'};
if recovery,sources{end+1}='HealthMemory/1';end
if ~recovery,sources=[sources {[v11memory '/1'],'SkillMemory/1'}];end
wireInputs(n,label,sources);
add_line(n,[label '/2'],[memory '/1'],'autorouting','on');
if ~recovery,add_line(n,[label '/4'],[v11memory '/1'],'autorouting','on');end
end

function addV1Authorization(n,teamType)
script=sprintf(['function effective=f(raw,plans,obs,blue,red,previous,feedback,P)\n' ...
    'effective=V1AuthorizeRequests(raw,plans,obs,blue,red,previous,feedback,P);\nend']);
label='AuthorizeRequests';
add_matlab_block([n '/' label],script,[1450 720 1620 880], ...
    {'raw','Bus: RequestBus','Input';'plans','Bus: IntentBus','Input'; ...
    'obs','Bus: ObservationBus','Input';'blue',teamType,'Input'; ...
    'red',teamType,'Input';'previous','Bus: RequestBus','Input'; ...
    'feedback','Bus: FeedbackBus','Input';'effective','Bus: RequestBus','Output'; ...
    'P','Inherit: Same as Simulink','Parameter'});
for key={'raw','plans','obs','previous','feedback','effective'}
    set_data_size([n '/' label],key{1},'[1 8]');
end
wireInputs(n,label,{'JoinRequests/1','JoinPlans/1','KickArbiter/1','Team1/2','Team2/2','RequestMemory/1','FeedbackMemory/1'});
add_line(n,[label '/1'],'RequestMemory/1','autorouting','on');
end

function addV1Log(n,teamType,feedbackSource)
script=sprintf(['function row=f(a,b,c,d,e,f6,g,h)\n' ...
    'row=[double(a) double(b) double(c) double(d) double(e) double(f6) double(g) double(h)];\nend']);
add_matlab_block([n '/JoinSkills'],script,[1340 1100 1450 1330],{});
for i=1:8
    add_line(n,sprintf('Robot%d/2',i),sprintf('JoinSkills/%d',i),'autorouting','on');
end
script=sprintf(['function row=f(blue,red,obs,plans,raw,requests,feedback,skill,next,kicker,P)\n' ...
    'row=V1TacticsRecord(blue,red,obs,plans,raw,requests,feedback,skill,next,kicker,P);\nend']);
label='TacticsRecord';
add_matlab_block([n '/' label],script,[1800 560 1970 820], ...
    {'blue',teamType,'Input';'red',teamType,'Input'; ...
    'obs','Bus: ObservationBus','Input';'plans','Bus: IntentBus','Input'; ...
    'raw','Bus: RequestBus','Input';'requests','Bus: RequestBus','Input'; ...
    'feedback','Bus: FeedbackBus','Input';'next','Bus: WorldBus','Input'; ...
    'P','Inherit: Same as Simulink','Parameter'});
for key={'obs','plans','raw','requests','feedback'}
    set_data_size([n '/' label],key{1},'[1 8]');
end
wireInputs(n,label,{'Team1/2','Team2/2','KickArbiter/1','JoinPlans/1','JoinRequests/1', ...
    'AuthorizeRequests/1',feedbackSource,'JoinSkills/1','Plant2D/1','Plant2D/3'});
add_block('simulink/Sinks/To Workspace',[n '/TacticsRecords'], ...
    'VariableName','tacticsRecords','SaveFormat','Array','Position',[2020 640 2140 690]);
add_line(n,[label '/1'],'TacticsRecords/1');
end

function wireInputs(n,label,sources)
for port=1:numel(sources)
    add_line(n,sources{port},sprintf('%s/%d',label,port),'autorouting','on');
end
end

function addRecoveryFeedback(n)
label='RecoveryFeedback';
script=sprintf(['function [health,feedback]=f(deviceHealth,deviceFeedback,heldHealth,heldFeedback,tSim,P)\n' ...
    '[health,feedback]=RecoveryFeedback2D(deviceHealth,deviceFeedback,heldHealth,heldFeedback,tSim,P);\nend']);
ports={'deviceHealth','Bus: V1HealthBus','Input';'deviceFeedback','Bus: FeedbackBus','Input'; ...
    'heldHealth','Bus: V1HealthBus','Input';'heldFeedback','Bus: FeedbackBus','Input'; ...
    'health','Bus: V1HealthBus','Output';'feedback','Bus: FeedbackBus','Output'; ...
    'P','Inherit: Same as Simulink','Parameter'};
add_matlab_block([n '/' label],script,[1490 1000 1650 1150],ports);
for name={'deviceHealth','deviceFeedback','heldHealth','heldFeedback','health','feedback'}
    set_data_size([n '/' label],name{1},'[1 8]');
end
wireInputs(n,label,{'Plant2D/4','Plant2D/2','HealthMemory/1','FeedbackMemory/1','StepTime/1'});
add_line(n,'Plant2D/4','DeviceHealthMemory/1','autorouting','on');
add_line(n,'DeviceHealthMemory/1','Plant2D/5','autorouting','on');
add_line(n,[label '/1'],'HealthMemory/1','autorouting','on');
end

function addRecoveryLog(n,teamType)
label='RecoveryRecord';
script=sprintf(['function row=f(tSim,health,blue,red)\n' ...
    'row=RecoveryRecord(tSim,health,blue,red);\nend']);
ports={'health','Bus: V1HealthBus','Input';'blue',teamType,'Input';'red',teamType,'Input'};
add_matlab_block([n '/' label],script,[1820 890 1970 1010],ports);
set_data_size([n '/' label],'health','[1 8]');
wireInputs(n,label,{'StepTime/1','RecoveryFeedback/1','Team1/2','Team2/2'});
add_block('simulink/Sinks/To Workspace',[n '/RecoveryRecords'], ...
    'VariableName','recoveryRecords','SaveFormat','Array','Position',[2020 920 2140 960]);
add_line(n,[label '/1'],'RecoveryRecords/1');
end
