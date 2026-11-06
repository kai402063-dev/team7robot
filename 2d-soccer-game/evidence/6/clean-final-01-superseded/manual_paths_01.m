function receipt=manual_paths_01()
% Independent reader's implementation of docs/chapters/handson.md paths 1-6.
% GUI dragging is NOT performed. Model construction uses documented API.
root=tdpSetup; folder=fullfile(root,'build','learning');
if ~isfolder(folder),mkdir(folder);end
addpath(folder); out=fullfile(root,'build','independent-audit-01','manual-paths-01');
assert(~isfolder(out),'Preserve earlier manual attempts');mkdir(out);
started=datetime('now');receipt=struct('status','RUNNING','guiDragging','NOT_PERFORMED');
try
 receipt.matlabVersion=version;receipt.matlabRelease=version('-release');
 % Path 1: independently express the segment formula and tests from the manual.
 lane=sprintf(['function ok=laneClearLesson(a,b,obstacles,margin)\n' ...
 'ab=b-a; squaredLength=dot(ab,ab);ok=true;\n' ...
 'if squaredLength<1e-9,return;end %% Preserve documented source policy for a=b.\n' ...
 'for n=1:size(obstacles,1)\n' ...
 'fraction=max(0,min(1,dot(obstacles(n,:)-a,ab)/squaredLength));\n' ...
 'separation=norm(a+fraction*ab-obstacles(n,:));\n' ...
 'if separation < margin,ok=false;return;end\nend\nend\n']);
 writeText(fullfile(folder,'laneClearLesson.m'),lane);writeText(fullfile(out,'laneClearLesson-original.m'),lane);
 testText=sprintf(['function tests=test_laneClearLesson\ntests=functiontests(localfunctions);end\n' ...
 'function testInside(tc)\nverifyFalse(tc,laneClearLesson([0 0],[2 0],repmat([1 .3],4,1),.4));end\n' ...
 'function testBeyond(tc)\nverifyTrue(tc,laneClearLesson([0 0],[2 0],repmat([3 .1],4,1),.4));end\n' ...
 'function testDegenerate(tc)\nverifyTrue(tc,laneClearLesson([0 0],[0 0],zeros(4,2),.4));end\n' ...
 'function testEquality(tc)\nverifyTrue(tc,laneClearLesson([0 0],[2 0],repmat([1 .4],4,1),.4));end\n']);
 writeText(fullfile(folder,'test_laneClearLesson.m'),testText);
 passed=runtests(fullfile(folder,'test_laneClearLesson.m'));assertSuccess(passed);
 receipt.laneOriginal=results(passed);
 mutant=strrep(lane,'if separation < margin','if separation > margin');
 writeText(fullfile(out,'laneClearLesson-mutant.m'),mutant);writeText(fullfile(folder,'laneClearLesson.m'),mutant);clear laneClearLesson;
 broken=runtests(fullfile(folder,'test_laneClearLesson.m'));
 receipt.laneMutation=results(broken);assert(any([broken.Failed]),'Mutation was not detected');
 writeText(fullfile(folder,'laneClearLesson.m'),lane);clear laneClearLesson;
 restored=runtests(fullfile(folder,'test_laneClearLesson.m'));assertSuccess(restored);
 receipt.laneRestored=results(restored);
 % Path 2: new model, explicit blocks and wires from the table.
 P=tdp.defaultConfig();n='readerDelay01';newModel(n,P);set_param(n,'StopTime','0.2');
 add_block('simulink/Sources/Constant',[n '/Target'],'Value','1','Position',[20 70 70 100]);
 add_block('simulink/Math Operations/Sum',[n '/Error'],'Inputs','+-','Position',[130 70 155 100]);
 add_block('simulink/Math Operations/Gain',[n '/Kp'],'Gain','0.8','Position',[210 70 260 100]);
 add_block('simulink/Math Operations/Gain',[n '/dt'],'Gain','P.dt','Position',[310 70 360 100]);
 add_block('simulink/Math Operations/Sum',[n '/Integrate'],'Inputs','++','Position',[410 70 440 100]);
 add_block('simulink/Discrete/Unit Delay',[n '/PositionMemory'],'InitialCondition','0','SampleTime','P.dt','Position',[510 70 580 100]);
 add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[650 70 750 100]);
 wires={'Target/1','Error/1';'PositionMemory/1','Error/2';'Error/1','Kp/1';'Kp/1','dt/1';'dt/1','Integrate/1';'PositionMemory/1','Integrate/2';'Integrate/1','PositionMemory/1';'PositionMemory/1','Records/1'};
 wire(n,wires);save_system(n,fullfile(folder,[n '.slx']));data=sim(n);
 receipt.unitDelay=reshape(data.records,1,[]);assert(max(abs(receipt.unitDelay-(1-(1-.8*.05).^(0:4))))<1e-12);close_system(n,0);
 % Path 3: new flat chart, explicit states and transitions.
 n='readerFlat01';newModel(n,P);set_param(n,'StopTime','0.2');
 add_block('simulink/Sources/Digital Clock',[n '/Clock'],'SampleTime','P.dt','Position',[20 20 70 50]);
 add_block('simulink/Sources/Step',[n '/BallSeen'],'Time','0.1','Before','0','After','1','SampleTime','P.dt','Position',[20 100 70 130]);
 add_block('sflib/Chart',[n '/Flat'],'Position',[160 20 350 170]);ch=find(sfroot,'-isa','Stateflow.Chart','Path',[n '/Flat']);
 ch.ActionLanguage='MATLAB';ch.ChartUpdate='DISCRETE';ch.SampleTime='P.dt';
 d=Stateflow.Data(ch);d.Name='tSim';d.Scope='Input';d.DataType='double';d.Port=1;
 d=Stateflow.Data(ch);d.Name='seen';d.Scope='Input';d.DataType='double';d.Port=2;
 d=Stateflow.Data(ch);d.Name='phase';d.Scope='Output';d.DataType='Enum: TdpPhase';d.Port=1;
 idle=state(ch,sprintf('Idle\nen,du: phase=TdpPhase.Idle;'),[40 60 150 90]);
 search=state(ch,sprintf('Search\nen,du: phase=TdpPhase.Search;'),[270 60 150 90]);
 approach=state(ch,sprintf('Approach\nen,du: phase=TdpPhase.Approach;'),[500 60 150 90]);
 tr=Stateflow.Transition(ch);tr.Destination=idle;tr.DestinationOClock=0;tr.SourceEndPoint=[115 10];tr.MidPoint=[115 35];
 transition(ch,idle,search,'[tSim>=0.05]',1);
 transition(ch,search,approach,'[seen~=0]',1);
 transition(ch,approach,search,'[seen==0]',1);
 add_block('simulink/Signal Attributes/Data Type Conversion',[n '/NumericPhase'],'OutDataTypeStr','double','Position',[400 70 470 100]);
 add_block('simulink/Sinks/To Workspace',[n '/Records'],'VariableName','records','SaveFormat','Array','Position',[520 70 620 100]);
 wire(n,{'Clock/1','Flat/1';'BallSeen/1','Flat/2';'Flat/1','NumericPhase/1';'NumericPhase/1','Records/1'});
 save_system(n,fullfile(folder,[n '.slx']));data=sim(n);receipt.flatPhase=reshape(data.records,1,[]);assert(isequal(receipt.flatPhase,[0 1 2 2 2]));close_system(n,0);
 % Path 4: use only the prescribed replay shell, delete all states and redraw.
 file=build_learning_replay('readerKick01',folder);load_system(file);
 ch=find(sfroot,'-isa','Stateflow.Chart','Path','readerKick01/ControllerCore/SkillStages');
 receipt.originalStates=numel(find(ch,'-isa','Stateflow.State'));
 tr=find(ch,'-isa','Stateflow.Transition');for k=1:numel(tr),delete(tr(k));end
 nodes=find(ch,'-isa','Stateflow.State');
 for k=1:numel(nodes),if isvalid(nodes(k)) && isa(getParent(nodes(k)),'Stateflow.State'),delete(nodes(k));end,end
 nodes=find(ch,'-isa','Stateflow.State');for k=1:numel(nodes),delete(nodes(k));end
 receipt.emptyStates=numel(find(ch,'-isa','Stateflow.State'));assert(receipt.emptyStates==0);
 assert(isempty(find(ch,'-isa','Stateflow.Transition')));
 % Copy state/transition text from linked generated/stateflow.json, not source builder.
 spec=jsondecode(fileread(fullfile(root,'docs','generated','stateflow.json')));
 names=fieldnames(spec.states);texts=struct();
 for k=1:numel(names),s=spec.states.(names{k});parts=splitlines(s);texts.(parts{1})=s;end
 nodes=struct();nodes.Idle=state(ch,texts.Idle,[30 400 180 100]);nodes.Active=state(ch,texts.Active,[300 50 1500 900]);
 nodes.Search=state(nodes.Active,texts.Search,[350 150 180 100]);
 nodes.Approach=state(nodes.Active,texts.Approach,[650 150 180 100]);
 nodes.Align=state(nodes.Active,texts.Align,[950 150 180 100]);
 nodes.Kick=state(nodes.Active,texts.Kick,[1250 150 180 100]);
 nodes.Recover=state(nodes.Active,texts.Recover,[1250 600 180 100]);
 for k=1:numel(spec.transitions)
  row=spec.transitions(k);dest=nodes.(row.destination);
  if strcmp(row.source,'DEFAULT')
   parent=getParent(dest);tr=Stateflow.Transition(parent);tr.Destination=dest;tr.DestinationOClock=0;
   p=dest.Position;tr.SourceEndPoint=[p(1)+p(3)/2 p(2)-60];tr.MidPoint=[p(1)+p(3)/2 p(2)-30];tr.LabelString=row.text;tr.ExecutionOrder=str2double(row.priority);
  else
   source=nodes.(row.source);parent=ch;
   if ~any(strcmp(row.source,{'Active','Idle'})),parent=nodes.Active;end
   tr=transition(parent,source,dest,row.text,str2double(row.priority));
  end
 end
 receipt.redrawnStates=numel(find(ch,'-isa','Stateflow.State'));receipt.redrawnTransitions=numel(find(ch,'-isa','Stateflow.Transition'));
 assert(receipt.redrawnStates==7 && receipt.redrawnTransitions==14);
 save_system('readerKick01',file);
 P.mode=TdpMode.Delayed;s=makeScenario(P,2);
 own=runReplay(P,s,'readerKick01');reference=runReplay(P,s);assert(isequaln(own,reference));
 writematrix(own,fullfile(out,'own-no-feedback.csv'));writematrix(reference,fullfile(out,'reference-no-feedback.csv'));
 k=find(own(:,1)==double(TdpAction.Kick),1);j=k+2;id=uint32(own(k,2));
 s(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*P.dt);
 finished=runReplay(P,s,'readerKick01');assert(finished(j,3)==double(TdpPhase.Recover));
 s(j).feedback.requestId=id-uint32(1);late=runReplay(P,s,'readerKick01');assert(late(j,3)==double(TdpPhase.Kick));
 writematrix(finished,fullfile(out,'same-id-done.csv'));writematrix(late,fullfile(out,'old-id-done.csv'));
 receipt.hierarchical=struct('equalToReference',true,'requestId',double(id),'sameIdDonePhase',finished(j,3),'oldIdDonePhase',late(j,3));
 save_system('readerKick01',file);close_system('readerKick01',0);
 % Path 5 plus manual-prescribed equivalent verification.
 s=makeScenario(P,2);a=runReplay(P,s);b=runReplay(P,s);assert(isequaln(a,b));
 r=runtests('tests/test_controller.m');assertSuccess(r);receipt.controller=results(r);
 build_lessons;r=runtests('tests/test_lessons.m');assertSuccess(r);receipt.lessons=results(r);
 % Path 6 MATLAB age example exactly as described; CLI handled separately.
 P=tdp.defaultConfig();f=makeBridgeFrames(P,1);[~,~,~,~,q,held]=BridgeDecode(f,zeros(1,20),P);
 f(2)=.6;[stale,~,~,~,after]=BridgeDecode(f,held,P);
 assert(q(1)==1 && after(1)==0 && after(3)==1 && ~stale.selfValid);
 r=runtests('tests/test_ros_adapter.m');assertSuccess(r);receipt.rosAdapter=results(r);
 receipt.stale=struct('initialQuality',q,'repeatedAfterClockAdvance',after,'selfValid',stale.selfValid);
 receipt.status='PASS_API_MANUAL_PATHS_GUI_NOT_PERFORMED';
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
assert(~bdIsLoaded(n));new_system(n);set_param(n,'Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','P.dt','AlgebraicLoopMsg','error','ReturnWorkspaceOutputs','on');
w=get_param(n,'ModelWorkspace');assignin(w,'P',P);
end
function wire(n,pairs)
for k=1:size(pairs,1),add_line(n,pairs{k,1},pairs{k,2},'autorouting','on');end
end
function s=state(parent,label,position)
s=Stateflow.State(parent);s.LabelString=label;s.Position=position;
end
function tr=transition(parent,source,destination,label,order)
tr=Stateflow.Transition(parent);tr.Source=source;tr.Destination=destination;
tr.SourceOClock=3;tr.DestinationOClock=9;
a=source.Position;b=destination.Position;tr.MidPoint=[(a(1)+a(3)/2+b(1)+b(3)/2)/2 (a(2)+a(4)/2+b(2)+b(4)/2)/2];
tr.LabelString=label;tr.ExecutionOrder=order;
end
