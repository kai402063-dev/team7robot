function audit = run_revision_audit
root = tdpSetup(); cd(root);
out = fullfile(root,'build','manual-revision-audit');
learning = fullfile(root,'build','learning'); addpath(learning);
timer = tic;
audit = struct('status','RUNNING','startedUTC',utcNow(), ...
    'matlab',version,'release',version('-release'),'root',root);
audit.scope = 'Targeted clean-clone revision verification; full one-key rerun deferred to final M2 snapshot';
writeJson(fullfile(out,'receipt.json'),audit);
try
    step = tic;
    build_all; export_manual;
    audit.buildElapsedSeconds = toc(step);
    names = {'runReplay','build_learning_replay','tdp.defaultConfig','CoreGeometry'};
    for i=1:numel(names)
        assert(startsWith(which(names{i}),[root filesep]), ...
            'Function resolves outside this clean clone');
    end
    step = tic;
    suites = {'tests/test_lessons.m','tests/test_extensions.m', ...
        'tests/test_manual_numbers.m','tests/test_controller.m'};
    results = runtests(suites); assertSuccess(results);
    audit.targetedTests = summarize(results);
    audit.testsElapsedSeconds = toc(step);

    step = tic;
    before = runtests(fullfile(learning,'test_laneClearLesson.m')); assertSuccess(before);
    lessonFile = fullfile(learning,'laneClearLesson.m'); original = fileread(lessonFile);
    corrupted = strrep(original,'if distance < margin','if distance > margin');
    assert(~strcmp(original,corrupted));
    guard = onCleanup(@()writeText(lessonFile,original));
    writeText(fullfile(out,'laneClearLesson-mutated.txt'),corrupted);
    writeText(lessonFile,corrupted); clear laneClearLesson; rehash;
    mutation = runtests(fullfile(learning,'test_laneClearLesson.m'));
    clear guard; clear laneClearLesson; rehash;
    assert(any([mutation.Failed]) && ~any([mutation.Incomplete]));
    restored = runtests(fullfile(learning,'test_laneClearLesson.m')); assertSuccess(restored);
    audit.path1 = struct('status','PASS','before',summarize(before), ...
        'mutation',summarize(mutation),'restored',summarize(restored),'elapsedSeconds',toc(step));

    step = tic;
    file = build_learning_replay('myKickReplay',learning);
    load_system(file);
    chart = find(sfroot,'-isa','Stateflow.Chart','Path','myKickReplay/ControllerCore/SkillStages');
    assert(numel(chart)==1);
    assert(strcmp(get_param('myKickReplay/ControllerCore','LinkStatus'),'none'));
    definitions = jsondecode(fileread(fullfile(out,'chart-from-manual.json')));
    oldTransitions = find(chart,'-isa','Stateflow.Transition');
    oldStates = find(chart,'-isa','Stateflow.State');
    oldData = find(chart,'-isa','Stateflow.Data');
    audit.redraw.originalStatesRemoved = numel(oldStates);
    audit.redraw.originalTransitionsRemoved = numel(oldTransitions);
    for i=1:numel(oldTransitions),delete(oldTransitions(i));end
    delete(find(chart,'-isa','Stateflow.State','Name','Idle'));
    delete(find(chart,'-isa','Stateflow.State','Name','Active'));
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
    save_system('myKickReplay',file);
    audit.redraw.recreatedStates = 7;
    audit.redraw.recreatedTransitions = 14;
    audit.redraw.method = 'Stateflow API reconstruction from Markdown labels; no GUI dragging';
    audit.redraw.source = definitions.source;
    audit.redraw.sourceSHA256 = definitions.sha256;

    P=tdp.defaultConfig(); P.mode=TdpMode.Delayed;
    s=makeScenario(P,2);
    own=runReplay(P,s,'myKickReplay');
    reference=runReplay(P,s);
    assert(isequaln(own,reference));
    k=find(own(:,1)==double(TdpAction.Kick),1);
    j=k+2; id=uint32(own(k,2));
    s(j).feedback=struct('requestId',id,'status',TdpStatus.Done,'stamp',(j-1)*P.dt);
    finished=runReplay(P,s,'myKickReplay');
    assert(finished(j,3)==double(TdpPhase.Recover));
    s(j).feedback.requestId=id-uint32(1);
    late=runReplay(P,s,'myKickReplay');
    assert(late(j,3)==double(TdpPhase.Kick));
    save_system('myKickReplay',file);

    timeout=find(chart,'-isa','Stateflow.Transition','LabelString','[tSim-kickStart>=P.kickTimeout]');
    assert(numel(timeout)==1); originalLabel=timeout.LabelString;
    timeoutGuard=onCleanup(@()restoreLabel(timeout,originalLabel));
    timeout.LabelString='[tSim-kickStart>=P.kickTimeout/2]';
    plain=makeScenario(P,2);
    changed=runReplay(P,plain,'myKickReplay');
    referenceAfter=runReplay(P,plain);
    originalRecover=find(own(:,3)==double(TdpPhase.Recover),1);
    changedRecover=find(changed(:,3)==double(TdpPhase.Recover),1);
    assert(changedRecover<originalRecover);
    assert(isequaln(referenceAfter,reference));
    clear timeoutGuard
    save_system('myKickReplay',file);
    restoredOwn=runReplay(P,plain,'myKickReplay');
    assert(isequaln(restoredOwn,own));
    overwriteRejected=false;
    try
        build_learning_replay('myKickReplay',learning);
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
    audit.status='PASS_REVISED_MANUAL_AND_TARGETED_BOUNDARY_SUITES';
catch e
    audit.status='FAIL';audit.error=getReport(e,'extended','hyperlinks','off');
    audit.endedUTC=utcNow();audit.elapsedSeconds=toc(timer);
    writeJson(fullfile(out,'receipt.json'),audit);rethrow(e);
end
audit.endedUTC=utcNow();audit.elapsedSeconds=toc(timer);
writeJson(fullfile(out,'receipt.json'),audit);
fprintf('REVISION_AUDIT %s in %.1f seconds. Receipt: %s\n', ...
    audit.status,audit.elapsedSeconds,fullfile(out,'receipt.json'));
end
function s=summarize(r)
s=struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed], ...
    'incomplete',[r.Incomplete],'durations',[r.Duration]);
end
function value=utcNow()
value=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
function writeText(file,contents)
fid=fopen(file,'w');assert(fid~=-1);guard=onCleanup(@()fclose(fid));fwrite(fid,contents,'char');
end
function restoreLabel(transition,label)
transition.LabelString=label;
end
