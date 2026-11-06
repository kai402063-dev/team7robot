function audit = run_chart_retry
root=tdpSetup();cd(root);
out=fullfile(root,'build','manual-revision-chart-retry-01');
learning=fullfile(root,'build','learning');addpath(learning);
timer=tic;
audit=struct('status','RUNNING','startedUTC',utcNow(),'matlab',version,'root',root);
audit.scope='Own-chart API retry only; prior 24 project tests and laneClear cycle are preserved, not repeated';
audit.priorAttemptReceipt=fullfile(root,'build','manual-revision-audit','receipt.json');
previous=jsondecode(fileread(audit.priorAttemptReceipt));
assert(all(previous.targetedTests.passed) && ~any(previous.targetedTests.incomplete));
audit.targetedTestCount=numel(previous.targetedTests.names);
writeJson(fullfile(out,'receipt.json'),audit);
try
    step = tic;
    file = build_learning_replay('myKickReplayRetry01',learning);
    load_system(file);
    chart = find(sfroot,'-isa','Stateflow.Chart','Path','myKickReplayRetry01/ControllerCore/SkillStages');
    assert(numel(chart)==1);
    assert(strcmp(get_param('myKickReplayRetry01/ControllerCore','LinkStatus'),'none'));
    definitions = jsondecode(fileread(fullfile(root,'build','manual-revision-audit','chart-from-manual.json')));
    oldTransitions = find(chart,'-isa','Stateflow.Transition');
    oldStates = find(chart,'-isa','Stateflow.State');
    oldData = find(chart,'-isa','Stateflow.Data');
    audit.redraw.originalStatesRemoved = numel(oldStates);
    audit.redraw.originalTransitionsRemoved = numel(oldTransitions);
    beforeDeletion = repmat(struct('name','','label','','path','','id',0),1,numel(oldStates));
    for i=1:numel(oldStates)
        beforeDeletion(i)=struct('name',oldStates(i).Name,'label',oldStates(i).LabelString, ...
            'path',oldStates(i).Path,'id',oldStates(i).Id);
    end
    writeJson(fullfile(out,'deletion-before.json'),beforeDeletion);
    for i=1:numel(oldTransitions),oldTransitions(i).delete();end
    deletionOrder={'Search','Approach','Align','Kick','Recover','Idle','Active'};
    deletionCounts=zeros(1,numel(deletionOrder));
    for i=1:numel(deletionOrder)
        current=find(chart,'-isa','Stateflow.State');found=false;
        for j=1:numel(current)
            labelLines=splitlines(string(current(j).LabelString));
            if strcmp(strtrim(labelLines(1)),deletionOrder{i})
                current(j).delete();found=true;break
            end
        end
        assert(found,'TDP:AuditDeletion','Documented state was not found: %s',deletionOrder{i});
        deletionCounts(i)=numel(find(chart,'-isa','Stateflow.State'));
    end
    audit.redraw.deletionOrder=deletionOrder;
    audit.redraw.statesRemainingAfterEachDeletion=deletionCounts;
    writeJson(fullfile(out,'deletion-after.json'),struct('remaining',deletionCounts));
    assert(isempty(find(chart,'-isa','Stateflow.State')));
    assert(isempty(find(chart,'-isa','Stateflow.Transition')));
    audit.redraw.emptyChartConfirmed = true;
    % Positions are independently selected; all child edges stay in Active.
    positions = [30 80 180 100;280 40 1200 700;350 160 180 90; ...
        650 160 190 90;1000 160 190 90;1000 410 280 180;620 440 220 120];
    states = struct;
    for i=1:numel(definitions.states)
        definition = definitions.states(i);
        if ismember(definition.name,{'Idle','Active'}),parent=chart;else,parent=states.Active;end
        state = Stateflow.State(parent);
        state.Name = definition.name;
        state.LabelString = definition.label;
        state.Position = positions(i,:);
        states.(definition.name) = state;
    end
    for i=1:numel(definitions.transitions)
        definition = definitions.transitions(i);
        if ismember(definition.destination,{'Idle','Active'}),parent=chart;else,parent=states.Active;end
        transition = Stateflow.Transition(parent);
        transition.Destination = states.(definition.destination);
        if strcmp(definition.source,'DEFAULT')
            transition.DestinationOClock = 0;
            transition.SourceEndPoint = transition.DestinationEndPoint-[0 35];
            transition.MidPoint = transition.DestinationEndPoint-[0 17];
        else
            transition.Source = states.(definition.source);
            transition.SourceOClock = 3;
            transition.DestinationOClock = 9;
            transition.MidPoint = (transition.SourceEndPoint+transition.DestinationEndPoint)/2;
        end
        transition.LabelString = definition.label;
        transition.ExecutionOrder = definition.priority;
    end
    assert(numel(find(chart,'-isa','Stateflow.State'))==7);
    assert(numel(find(chart,'-isa','Stateflow.Transition'))==14);
    assert(numel(find(chart,'-isa','Stateflow.Data'))==numel(oldData));
    save_system('myKickReplayRetry01',file);
    audit.redraw.recreatedStates = 7;
    audit.redraw.recreatedTransitions = 14;
    audit.redraw.method = 'Stateflow API reconstruction from Markdown labels; no GUI dragging';
    audit.redraw.source = definitions.source;
    audit.redraw.sourceSHA256 = definitions.sha256;

    P=tdp.defaultConfig(); P.mode=TdpMode.Delayed;
    s=makeScenario(P,2);
    own=runReplay(P,s,'myKickReplayRetry01');
    reference=runReplay(P,s);
    assert(isequaln(own,reference));
    k=find(own(:,1)==double(TdpAction.Kick),1);
    j=k+2; id=uint32(own(k,2));
    s(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*P.dt);
    finished=runReplay(P,s,'myKickReplayRetry01');
    assert(finished(j,3)==double(TdpPhase.Recover));
    s(j).feedback.requestId=id-uint32(1);
    late=runReplay(P,s,'myKickReplayRetry01');
    assert(late(j,3)==double(TdpPhase.Kick));
    save_system('myKickReplayRetry01',file);

    timeout=find(chart,'-isa','Stateflow.Transition','LabelString','[tSim-kickStart>=P.kickTimeout]');
    assert(numel(timeout)==1); originalLabel=timeout.LabelString;
    timeoutGuard=onCleanup(@()restoreLabel(timeout,originalLabel));
    timeout.LabelString='[tSim-kickStart>=P.kickTimeout/2]';
    plain=makeScenario(P,2);
    changed=runReplay(P,plain,'myKickReplayRetry01');
    referenceAfter=runReplay(P,plain);
    originalRecover=find(own(:,3)==double(TdpPhase.Recover),1);
    changedRecover=find(changed(:,3)==double(TdpPhase.Recover),1);
    assert(changedRecover<originalRecover);
    assert(isequaln(referenceAfter,reference));
    clear timeoutGuard
    save_system('myKickReplayRetry01',file);
    restoredOwn=runReplay(P,plain,'myKickReplayRetry01');
    assert(isequaln(restoredOwn,own));
    overwriteRejected=false;
    try
        build_learning_replay('myKickReplayRetry01',learning);
    catch e
        assert(strcmp(e.identifier,'TDP:ExistingLearningModel'));overwriteRejected=true;
    end
    assert(overwriteRejected);
    save(fullfile(out,'own-chart-replays.mat'),'P','s','own','reference','finished','late', ...
        'changed','referenceAfter','restoredOwn');
    audit.path4=struct('status','PASS_API_REBUILT_OWN_CHART', ...
        'model',file,'noFeedbackEqualsReference',isequaln(own,reference), ...
        'kickRequestId',double(id),'matchingDoneRecovers',true,'oldDoneIgnored',true, ...
        'originalRecoverSeconds',(originalRecover-1)*P.dt, ...
        'changedRecoverSeconds',(changedRecover-1)*P.dt, ...
        'originalLibraryUnaffected',isequaln(referenceAfter,reference), ...
        'ownChartRestored',isequaln(restoredOwn,own),'overwriteRejected',overwriteRejected, ...
        'elapsedSeconds',toc(step));
    a=runReplay(P,plain); b=runReplay(P,plain); assert(isequaln(a,b));
    audit.path5=struct('status','PASS','deterministic',true,'recordSize',size(a));
    audit.path2='PASS_AUTOMATED_EQUIVALENT: testClosedLoopUnitDelay';
    audit.path3='PASS_AUTOMATED_EQUIVALENT: testFlatStates';
    audit.path6='BLOCKED: missing ROS Toolbox/Coders and M2 not implemented';
    audit.path7='BLOCKED: M2 Webots path not implemented in this commit';
    audit.guiDragging='NOT_RUN';
    audit.status='PASS_API_REBUILT_OWN_CHART';
catch e
    audit.status='FAIL';audit.error=getReport(e,'extended','hyperlinks','off');
    audit.endedUTC=utcNow();audit.elapsedSeconds=toc(timer);
    writeJson(fullfile(out,'receipt.json'),audit);rethrow(e);
end
audit.endedUTC=utcNow();audit.elapsedSeconds=toc(timer);
writeJson(fullfile(out,'receipt.json'),audit);
fprintf('CHART_RETRY %s in %.1f seconds. Receipt: %s\n',audit.status,audit.elapsedSeconds,fullfile(out,'receipt.json'));
end
function value=utcNow()
value=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
function restoreLabel(transition,label)
transition.LabelString=label;
end
