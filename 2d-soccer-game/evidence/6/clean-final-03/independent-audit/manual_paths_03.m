function receipt=manual_paths_03()
% Reader-created manual exercises. No GUI dragging; no imported model/cache.
root=tdpSetup;folder=fullfile(root,'build','learning','reader-attempt-01');assert(~isfolder(folder),'Preserve earlier manual models');mkdir(folder);
addpath(folder);out=fullfile(root,'build','independent-audit-03','manual-paths-01');assert(~isfolder(out));mkdir(out);
started=datetime('now');receipt=struct('status','RUNNING','guiDragging','NOT_PERFORMED','matlabVersion',version,'release',version('-release'));
try
 receipt.paths=struct('root',root,'setup',which('tdpSetup'),'runA',which('runA'),'runReplay',which('runReplay'),'preferences',prefdir);
 a=runA(1,0,0.05);receipt.firstStep=struct('forwardRequest',a.trace(1,76),'robot4x',a.robots(4).x);assert(abs(receipt.firstStep.forwardRequest-.44)<1e-12 && abs(receipt.firstStep.robot4x+.9875)<1e-12);
 % Exercise 1: segment projection, boundary cases, intentional mutation.
 lane=sprintf(['function ok=laneClearLesson(a,b,obstacles,margin)\n' ...
 'ab=b-a; squaredLength=dot(ab,ab);ok=true;\n' ...
 'if squaredLength<1e-9,return;end\n' ...
 'for n=1:size(obstacles,1)\n' ...
 'fraction=max(0,min(1,dot(obstacles(n,:)-a,ab)/squaredLength));\n' ...
 'separation=norm(a+fraction*ab-obstacles(n,:));\n' ...
 'if separation < margin,ok=false;return;end\nend\nend\n']);
 testText=sprintf(['function tests=test_laneClearLesson\ntests=functiontests(localfunctions);end\n' ...
 'function testInside(tc)\nverifyFalse(tc,laneClearLesson([0 0],[2 0],repmat([1 .3],4,1),.4));end\n' ...
 'function testBeyond(tc)\nverifyTrue(tc,laneClearLesson([0 0],[2 0],repmat([3 .1],4,1),.4));end\n' ...
 'function testDegenerate(tc)\nverifyTrue(tc,laneClearLesson([0 0],[0 0],zeros(4,2),.4));end\n' ...
 'function testEquality(tc)\nverifyTrue(tc,laneClearLesson([0 0],[2 0],repmat([1 .4],4,1),.4));end\n']);
 writeText(fullfile(folder,'laneClearLesson.m'),lane);writeText(fullfile(out,'lane-original.m'),lane);
 writeText(fullfile(folder,'test_laneClearLesson.m'),testText);
 r=runtests(fullfile(folder,'test_laneClearLesson.m'));assertSuccess(r);receipt.laneOriginal=results(r);
 mutant=strrep(lane,'if separation < margin','if separation > margin');writeText(fullfile(out,'lane-mutant.m'),mutant);writeText(fullfile(folder,'laneClearLesson.m'),mutant);clear laneClearLesson;
 r=runtests(fullfile(folder,'test_laneClearLesson.m'));receipt.laneMutation=results(r);assert(any([r.Failed]));
 writeText(fullfile(folder,'laneClearLesson.m'),lane);clear laneClearLesson;r=runtests(fullfile(folder,'test_laneClearLesson.m'));assertSuccess(r);receipt.laneRestored=results(r);
 % Exercise 2: every block and wire is constructed from the manual table.
 P=tdp.defaultConfig();n='readerDelay01';newModel(n,P);set_param(n,'StopTime','0.2');
 add_block('simulink/Sources/Constant',[n '/Target'],'Value','1','Position',[20 70 70 100]);
 add_block('simulink/Math Operations/Sum',[n '/Error'],'Inputs','+-','Position',[130 70 155 100]);
 add_block('simulink/Math Operations/Gain',[n '/Kp'],'Gain','0.8','Position',[210 70 260 100]);
 add_block('simulink/Math Operations/Gain',[n '/dt'],'Gain','P.dt','Position',[310 70 360 100]);
 add_block('simulink/Math Operations/Sum',[n '/Integrate'],'Inputs','++','Position',[410 70 440 100]);
 add_block('simulink/Discrete/Unit Delay',[n '/PositionMemory'],'InitialCondition','0','SampleTime','P.dt','Position',[510 70 580 100]);
 add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[650 70 750 100]);
 wire(n,{'Target/1','Error/1';'PositionMemory/1','Error/2';'Error/1','Kp/1';'Kp/1','dt/1';'dt/1','Integrate/1';'PositionMemory/1','Integrate/2';'Integrate/1','PositionMemory/1';'PositionMemory/1','Records/1'});
 save_system(n,fullfile(folder,[n '.slx']));data=sim(n);receipt.unitDelay=reshape(data.records,1,[]);
 assert(max(abs(receipt.unitDelay-(1-(1-.8*.05).^(0:4))))<1e-12);close_system(n,0);
 % Exercise 3: flat chart from blank; scalar enum output is recorded as double.
 n='readerFlat01';newModel(n,P);set_param(n,'StopTime','0.2');
 add_block('simulink/Sources/Digital Clock',[n '/Clock'],'SampleTime','P.dt','Position',[20 20 70 50]);
 add_block('simulink/Sources/Step',[n '/BallSeen'],'Time','0.1','Before','0','After','1','SampleTime','P.dt','Position',[20 100 70 130]);
 add_block('sflib/Chart',[n '/Flat'],'Position',[160 20 350 170]);ch=find(sfroot,'-isa','Stateflow.Chart','Path',[n '/Flat']);ch.ActionLanguage='MATLAB';ch.ChartUpdate='DISCRETE';ch.SampleTime='P.dt';
 d=Stateflow.Data(ch);d.Name='tSim';d.Scope='Input';d.DataType='double';d.Port=1;
 d=Stateflow.Data(ch);d.Name='seen';d.Scope='Input';d.DataType='double';d.Port=2;
 d=Stateflow.Data(ch);d.Name='phase';d.Scope='Output';d.DataType='Enum: TdpPhase';d.Port=1;
 idle=state(ch,sprintf('Idle\nen,du: phase=TdpPhase.Idle;'),[40 60 150 90]);
 search=state(ch,sprintf('Search\nen,du: phase=TdpPhase.Search;'),[270 60 150 90]);
 approach=state(ch,sprintf('Approach\nen,du: phase=TdpPhase.Approach;'),[500 60 150 90]);
 tr=Stateflow.Transition(ch);tr.Destination=idle;tr.DestinationOClock=0;tr.SourceEndPoint=[115 10];tr.MidPoint=[115 35];
 transition(ch,idle,search,'[tSim>=0.05]',1);transition(ch,search,approach,'[seen~=0]',1);transition(ch,approach,search,'[seen==0]',1);
 add_block('simulink/Signal Attributes/Data Type Conversion',[n '/NumericPhase'],'OutDataTypeStr','double','Position',[400 70 470 100]);
 add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[520 70 620 100]);
 wire(n,{'Clock/1','Flat/1';'BallSeen/1','Flat/2';'Flat/1','NumericPhase/1';'NumericPhase/1','Records/1'});
 save_system(n,fullfile(folder,[n '.slx']));data=sim(n);receipt.flatPhase=reshape(data.records,1,[]);assert(isequal(receipt.flatPhase,[0 1 2 2 2]));close_system(n,0);
 % Exercise 4: manual-prescribed editable shell, then genuinely empty the chart.
 file=build_learning_replay('readerKick01',folder);load_system(file);ch=find(sfroot,'-isa','Stateflow.Chart','Path','readerKick01/ControllerCore/SkillStages');
 receipt.originalStates=numel(find(ch,'-isa','Stateflow.State'));ts=find(ch,'-isa','Stateflow.Transition');for k=1:numel(ts),delete(ts(k));end
 nodes=find(ch,'-isa','Stateflow.State');for k=1:numel(nodes),if isa(getParent(nodes(k)),'Stateflow.State'),delete(nodes(k));end,end
 nodes=find(ch,'-isa','Stateflow.State');for k=1:numel(nodes),delete(nodes(k));end
 receipt.emptyStates=numel(find(ch,'-isa','Stateflow.State'));assert(receipt.emptyStates==0 && isempty(find(ch,'-isa','Stateflow.Transition')));
 spec=jsondecode(fileread(fullfile(root,'docs','generated','stateflow.json')));keys=fieldnames(spec.states);texts=struct();
 for k=1:numel(keys),s=spec.states.(keys{k});lines=splitlines(s);texts.(lines{1})=s;end
 nodes=struct();nodes.Idle=state(ch,texts.Idle,[30 400 180 100]);nodes.Active=state(ch,texts.Active,[300 50 1500 900]);
 nodes.Search=state(nodes.Active,texts.Search,[350 150 180 100]);nodes.Approach=state(nodes.Active,texts.Approach,[650 150 180 100]);
 nodes.Align=state(nodes.Active,texts.Align,[950 150 180 100]);nodes.Kick=state(nodes.Active,texts.Kick,[1250 150 180 100]);nodes.Recover=state(nodes.Active,texts.Recover,[1250 600 180 100]);
 transitionHandles=cell(1,numel(spec.transitions));
 for k=1:numel(spec.transitions)
  row=spec.transitions(k);dest=nodes.(row.destination);
  if strcmp(row.source,'DEFAULT')
   tr=Stateflow.Transition(getParent(dest));tr.Destination=dest;tr.DestinationOClock=0;p=dest.Position;tr.SourceEndPoint=[p(1)+p(3)/2 p(2)-60];tr.MidPoint=[p(1)+p(3)/2 p(2)-30];tr.LabelString=row.text;
  else
   parent=ch;if ~any(strcmp(row.source,{'Active','Idle'})),parent=nodes.Active;end
   tr=transition(parent,nodes.(row.source),dest,row.text,[]);
  end
  transitionHandles{k}=tr;
 end
 priorities=arrayfun(@(r)str2double(r.priority),spec.transitions);[~,order]=sort(priorities);
 for k=reshape(order,1,[]),transitionHandles{k}.ExecutionOrder=priorities(k);end
 receipt.transitionPriorities=struct('expected',reshape(priorities,1,[]),'actual',cellfun(@(t)t.ExecutionOrder,transitionHandles));assert(isequal(receipt.transitionPriorities.expected,receipt.transitionPriorities.actual));
 receipt.redrawnStates=numel(find(ch,'-isa','Stateflow.State'));receipt.redrawnTransitions=numel(find(ch,'-isa','Stateflow.Transition'));assert(receipt.redrawnStates==7 && receipt.redrawnTransitions==14);save_system('readerKick01',file);
 P.mode=TdpMode.Delayed;s=makeScenario(P,2);own=runReplay(P,s,'readerKick01');reference=runReplay(P,s);assert(isequaln(own,reference));
 writematrix(own,fullfile(out,'own-no-feedback.csv'));writematrix(reference,fullfile(out,'reference-no-feedback.csv'));
 k=find(own(:,1)==double(TdpAction.Kick),1);j=k+2;id=uint32(own(k,2));s(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*P.dt);
 finished=runReplay(P,s,'readerKick01');assert(finished(j,3)==double(TdpPhase.Recover));s(j).feedback.requestId=id-uint32(1);late=runReplay(P,s,'readerKick01');assert(late(j,3)==double(TdpPhase.Kick));
 writematrix(finished,fullfile(out,'same-id-done.csv'));writematrix(late,fullfile(out,'old-id-done.csv'));
 % Prove the selected replay really executes the reader's own graph.
 ts=find(ch,'-isa','Stateflow.Transition');timeout=[];
 for k=1:numel(ts),if strcmp(ts(k).LabelString,'[tSim-kickStart>=P.kickTimeout]'),timeout=ts(k);break;end,end
 assert(~isempty(timeout));originalTimeout=timeout.LabelString;timeout.LabelString='[tSim-kickStart>=0.5*P.kickTimeout]';s=makeScenario(P,2);
 half=runReplay(P,s,'readerKick01');unchanged=runReplay(P,s);assert(isequaln(unchanged,reference));
 ownRecover=find(own(:,3)==double(TdpPhase.Recover),1);halfRecover=find(half(:,3)==double(TdpPhase.Recover),1);assert(halfRecover<ownRecover);
 timeout.LabelString=originalTimeout;save_system('readerKick01',file);writematrix(half,fullfile(out,'own-half-timeout.csv'));
 receipt.hierarchical=struct('equalToReference',true,'requestId',double(id),'sameIdDonePhase',finished(j,3),'oldIdDonePhase',late(j,3),'originalRecoverRow',ownRecover,'halfTimeoutRecoverRow',halfRecover,'originalLibraryUnaffected',true);close_system('readerKick01',0);
 % Exercise 5 and manual-prescribed regression on the repository lessons.
 a=runReplay(P,s);b=runReplay(P,s);assert(isequaln(a,b));r=runtests('tests/test_controller.m');assertSuccess(r);receipt.controller=results(r);
 build_lessons;r=runtests('tests/test_lessons.m');assertSuccess(r);receipt.lessons=results(r);
 % Exercise 6 is local age adaptation, not an asynchronous ROS watchdog.
 P=tdp.defaultConfig();f=makeBridgeFrames(P,1);[~,~,~,~,q,held]=BridgeDecode(f,zeros(1,20),P);f(2)=.6;[stale,~,~,~,after]=BridgeDecode(f,held,P);
 assert(q(1)==1 && after(1)==0 && after(3)==1 && ~stale.selfValid);receipt.stale=struct('initialQuality',q,'repeatedAfterClockAdvance',after,'selfValid',stale.selfValid,'asynchronousStopPublishingWatchdog','NOT_VERIFIED');
 r=runtests('tests/test_ros_adapter.m');assertSuccess(r);receipt.rosAdapter=results(r);receipt.status='PASS_API_MANUAL_PATHS_GUI_NOT_PERFORMED';
catch e
 receipt.status='FAIL';receipt.error=getReport(e,'extended','hyperlinks','off');receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(out,'receipt.json'),receipt);rethrow(e);
end
receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(out,'receipt.json'),receipt);
end
function writeText(path,text)
f=fopen(path,'w');assert(f>=0);cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',text);
end
function s=results(r)
s=struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]);
end
function newModel(n,P)
assert(~bdIsLoaded(n));new_system(n);set_param(n,'Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','P.dt','AlgebraicLoopMsg','error','ReturnWorkspaceOutputs','on');assignin(get_param(n,'ModelWorkspace'),'P',P);
end
function wire(n,pairs)
for k=1:size(pairs,1),add_line(n,pairs{k,1},pairs{k,2},'autorouting','on');end
end
function s=state(parent,label,position)
s=Stateflow.State(parent);s.LabelString=label;s.Position=position;
end
function tr=transition(parent,source,destination,label,order)
tr=Stateflow.Transition(parent);tr.Source=source;tr.Destination=destination;tr.SourceOClock=3;tr.DestinationOClock=9;
a=source.Position;b=destination.Position;tr.MidPoint=[(a(1)+a(3)/2+b(1)+b(3)/2)/2 (a(2)+a(4)/2+b(2)+b(4)/2)/2];tr.LabelString=label;if ~isempty(order),tr.ExecutionOrder=order;end
end
