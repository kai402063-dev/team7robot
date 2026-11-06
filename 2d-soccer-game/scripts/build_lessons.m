function build_lessons()
%BUILD_LESSONS Generate the two small hand-construction teaching models.
root=tdpSetup();P=tdp.defaultConfig();n='tdpDelayLesson';
if bdIsLoaded(n),close_system(n,0);end
new_system(n);configure_model(n);w=get_param(n,'ModelWorkspace');assignin(w,'P',P);set_param(n,'StopTime','0.2');
add_block('simulink/Sources/Constant',[n '/Target'],'Value','1','Position',[20 80 70 110]);
add_block('simulink/Math Operations/Sum',[n '/Error'],'Inputs','+-','Position',[130 80 155 110]);
add_block('simulink/Math Operations/Gain',[n '/Kp'],'Gain','0.8','Position',[220 80 270 110]);
add_block('simulink/Math Operations/Gain',[n '/dt'],'Gain','P.dt','Position',[320 80 370 110]);
add_block('simulink/Math Operations/Sum',[n '/Integrate'],'Inputs','++','Position',[420 80 445 110]);
add_block('simulink/Discrete/Unit Delay',[n '/PositionMemory'],'InitialCondition','0','SampleTime','P.dt','Position',[510 80 580 110]);
add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[650 80 750 110]);
links={'Target/1','Error/1';'PositionMemory/1','Error/2';'Error/1','Kp/1';'Kp/1','dt/1';'dt/1','Integrate/1';'PositionMemory/1','Integrate/2';'Integrate/1','PositionMemory/1';'PositionMemory/1','Records/1'};
for i=1:size(links,1),add_line(n,links{i,1},links{i,2},'autorouting','on');end
save_system(n,fullfile(root,'models',[n '.slx']));close_system(n,0);
n='tdpFlatLesson';if bdIsLoaded(n),close_system(n,0);end
new_system(n);configure_model(n);w=get_param(n,'ModelWorkspace');assignin(w,'P',P);set_param(n,'StopTime','0.2');
add_block('simulink/Sources/Digital Clock',[n '/Clock'],'SampleTime','P.dt','Position',[20 20 70 50]);
add_block('simulink/Sources/Step',[n '/BallSeen'],'Time','0.1','Before','0','After','1','SampleTime','P.dt','Position',[20 110 70 140]);
add_block('sflib/Chart',[n '/Flat'],'Position',[160 20 350 170]);ch=find(sfroot,'-isa','Stateflow.Chart','Path',[n '/Flat']);ch.ActionLanguage='MATLAB';ch.ChartUpdate='DISCRETE';ch.SampleTime='P.dt';
d=Stateflow.Data(ch);d.Name='tSim';d.Scope='Input';d.Port=1;
d=Stateflow.Data(ch);d.Name='seen';d.Scope='Input';d.Port=2;
d=Stateflow.Data(ch);d.Name='phase';d.Scope='Output';d.DataType='Enum: TdpPhase';
s1=Stateflow.State(ch);s1.LabelString=sprintf('Idle\nen,du: phase=TdpPhase.Idle;');s1.Position=[30 60 130 80];
s2=Stateflow.State(ch);s2.LabelString=sprintf('Search\nen,du: phase=TdpPhase.Search;');s2.Position=[230 60 140 80];
s3=Stateflow.State(ch);s3.LabelString=sprintf('Approach\nen,du: phase=TdpPhase.Approach;');s3.Position=[440 60 150 80];
tr=Stateflow.Transition(ch);tr.Destination=s1;tr.DestinationOClock=0;tr.SourceEndPoint=[95 10];tr.MidPoint=[95 30];
tr=Stateflow.Transition(ch);tr.Source=s1;tr.Destination=s2;tr.LabelString='[tSim>=0.05]';tr.SourceOClock=3;tr.DestinationOClock=9;
tr=Stateflow.Transition(ch);tr.Source=s2;tr.Destination=s3;tr.LabelString='[seen~=0]';tr.SourceOClock=3;tr.DestinationOClock=9;
tr=Stateflow.Transition(ch);tr.Source=s3;tr.Destination=s2;tr.LabelString='[seen==0]';tr.SourceOClock=6;tr.DestinationOClock=6;tr.MidPoint=[400 200];
add_block('simulink/Signal Attributes/Data Type Conversion',[n '/NumericPhase'],'OutDataTypeStr','double','Position',[400 70 470 100]);
add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[520 70 620 100]);
add_line(n,'Clock/1','Flat/1');add_line(n,'BallSeen/1','Flat/2');add_line(n,'Flat/1','NumericPhase/1');add_line(n,'NumericPhase/1','Records/1');
save_system(n,fullfile(root,'models',[n '.slx']));close_system(n,0);
end
