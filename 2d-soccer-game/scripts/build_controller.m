function build_controller()
%BUILD_CONTROLLER Author the shared hierarchical Stateflow library from blank.
root=tdpSetup();build_types();name='ControllerCore';
if bdIsLoaded(name),close_system(name,0);end
new_system(name,'Library');set_param(name,'DataDictionary','TdpTypes.sldd');
sub=[name '/Core'];add_block('simulink/Ports & Subsystems/Subsystem',sub,'Position',[100 100 420 320]);
Simulink.SubSystem.deleteContents(sub);
ports={'obs','intent','feedback','tSim'};
for k=1:4
 add_block('simulink/Sources/In1',[sub '/' ports{k}],'Port',num2str(k),'Position',[20 30+70*k 50 50+70*k]);
end
add_matlab_block([sub '/Geometry'],sprintf('function g=f(obs,intent,tSim,P)\ng=CoreGeometry(obs,intent,tSim,P);\nend'), ...
 [120 70 260 150],{'obs','Bus: ObservationBus','Input';'intent','Bus: IntentBus','Input';'P','Inherit: Same as Simulink','Parameter';'g','Bus: GeometryBus','Output'});
add_block('sflib/Chart',[sub '/SkillStages'],'Position',[330 100 540 250]);
ch=find(sfroot,'-isa','Stateflow.Chart','Path',[sub '/SkillStages']);ch.ActionLanguage='MATLAB';
ch.ChartUpdate='DISCRETE';ch.SampleTime='P.dt';
addData(ch,'g','Input','Bus: GeometryBus','1');addData(ch,'fb','Input','Bus: FeedbackBus','1');addData(ch,'tSim','Input','double','1');
addData(ch,'P','Parameter','Inherit: Same as Simulink','1');
addData(ch,'phase','Output','Enum: TdpPhase','1');addData(ch,'requestId','Output','uint32','1');
addData(ch,'kickStart','Output','double','1');addData(ch,'kickTarget','Output','double','[1 2]');addData(ch,'kickSpeed','Output','double','1');
addData(ch,'recoverStart','Local','double','1');
idle=state(ch,'Idle',sprintf('Idle\nen,du:\n phase=TdpPhase.Idle;\n requestId=requestId+uint32(1);'),[40 50 190 100]);
active=state(ch,'Active',sprintf('Active\nen,du:\n if P.mode==TdpMode.Compat || phase~=TdpPhase.Kick\n requestId=requestId+uint32(1);\n end'),[240 50 1050 620]);
search=state(active,'Search',sprintf('Search\nen: phase=TdpPhase.Search;'),[320 150 180 90]);
approach=state(active,'Approach',sprintf('Approach\nen: phase=TdpPhase.Approach;'),[610 150 180 90]);
align=state(active,'Align',sprintf('Align\nen: phase=TdpPhase.Align;'),[940 150 180 90]);
kick=state(active,'Kick',sprintf(['Kick\nen:\n phase=TdpPhase.Kick;\n requestId=requestId+uint32(1);\n kickStart=tSim;\n kickTarget=g.target;\n kickSpeed=g.speed;']),[910 340 250 180]);
recover=state(active,'Recover',sprintf('Recover\nen:\n phase=TdpPhase.Recover;\n recoverStart=tSim;'),[490 390 220 120]);
t0=default(ch,idle);t0.LabelString='{requestId=uint32(0);kickStart=0;kickTarget=[0 0];kickSpeed=0;recoverStart=0;}';default(ch,search);
trans(ch,idle,active,'[g.safe && (g.running || P.mode==TdpMode.Compat)]',1);
trans(ch,active,idle,'[~g.safe || (~g.running && P.mode==TdpMode.Delayed)]',1);
trans(ch,search,approach,'[g.ballVisible || g.intent==TdpAction.Goto]',1);
trans(ch,approach,search,'[~g.ballVisible && g.intent~=TdpAction.Goto]',1);
trans(ch,approach,align,'[g.distance<P.alignEnter && g.intent~=TdpAction.Goto]',2);
trans(ch,align,search,'[~g.ballVisible]',1);
trans(ch,align,approach,'[g.distance>P.alignExit || g.intent==TdpAction.Goto]',2);
trans(ch,align,kick,'[g.ready]',3);
trans(ch,kick,recover,'[fb.requestId==requestId && (fb.status==TdpStatus.Done || fb.status==TdpStatus.Failed || fb.status==TdpStatus.Rejected)]',1);
trans(ch,kick,recover,'[tSim-kickStart>=P.kickTimeout]',2);
trans(ch,kick,recover,'[~g.ballVisible]',3);
trans(ch,recover,search,'[tSim-recoverStart>=P.recoverTime]',1);
add_matlab_block([sub '/Request'],sprintf('function req=f(g,phase,id,kickStart,target,speed,tSim,P)\nreq=EmitRequest(g,phase,id,kickStart,target,speed,tSim,P);\nend'), ...
 [620 80 800 260],{'g','Bus: GeometryBus','Input';'phase','Enum: TdpPhase','Input';'id','uint32','Input';'P','Inherit: Same as Simulink','Parameter';'req','Bus: RequestBus','Output'});
add_block('simulink/Sinks/Out1',[sub '/request'],'Port','1','Position',[900 120 930 140]);
add_block('simulink/Sinks/Out1',[sub '/phase'],'Port','2','Position',[900 200 930 220]);
add_line(sub,'obs/1','Geometry/1');add_line(sub,'intent/1','Geometry/2');
add_line(sub,'tSim/1','Geometry/3');add_line(sub,'Geometry/1','SkillStages/1');add_line(sub,'feedback/1','SkillStages/2');add_line(sub,'tSim/1','SkillStages/3');
add_line(sub,'Geometry/1','Request/1');
for k=1:5,add_line(sub,sprintf('SkillStages/%d',k),sprintf('Request/%d',k+1));end
add_line(sub,'tSim/1','Request/7');add_line(sub,'Request/1','request/1');add_line(sub,'SkillStages/1','phase/1');
save_system(name,fullfile(root,'models',[name '.slx']));close_system(name,0);
end
function d=addData(ch,name,scope,type,sz)
d=Stateflow.Data(ch);d.Name=name;d.Scope=scope;d.DataType=type;d.Props.Array.Size=sz;
end
function s=state(parent,name,label,pos)
s=Stateflow.State(parent);s.Name=name;s.LabelString=label;s.Position=pos;
end
function t=trans(ch,a,b,label,priority)
t=Stateflow.Transition(ch);t.Source=a;t.Destination=b;t.LabelString=label;
t.SourceOClock=3;t.DestinationOClock=9;t.MidPoint=(t.SourceEndPoint+t.DestinationEndPoint)/2;t.ExecutionOrder=priority;
end
function t=default(ch,s)
t=Stateflow.Transition(ch);t.Destination=s;t.DestinationOClock=0;
t.SourceEndPoint=t.DestinationEndPoint-[0 30];t.MidPoint=t.DestinationEndPoint-[0 15];
end
