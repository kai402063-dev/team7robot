% Replay the two hands-on examples from the V1 manual in a fresh process.
root=tdpSetup();
outDir=fullfile(root,'evidence','tactics-v1','handson-01');
started=tic;
report=struct('status','RUNNING','matlabVersion',version);
try
    % First exercise: issue distinct unavailability and recovery signals.
    P=tdp.v1Config();
    P.Tmatch=10;
    P.v1UnavailableWindow(4,:)=[2 4];
    P.v1RecoveryWindow(1,:)=[5 6];
    [trace,tactics]=runMatch(P);
    c=v1TraceColumns();
    t=tactics(:,c.time);
    sampleTimes=[1.95 2 3.95 4 4.95 5 5.05 5.10];
    rows=round(sampleTimes/P.dt);
    selected=tactics(rows,[c.time c.phase(1) c.chaser(1) c.available(4) ...
        c.takeover(1) c.recovering(1) c.failed(1)]);
    disp('seconds phase blueOwner strikerAvailable takeover recovering failed');
    disp(selected)
    assert(isequal(size(trace),[200 98]) && isequal(size(tactics),[200 171]));
    assert(all(tactics(t>=2 & t<4,c.available(4))==0));
    assert(all(tactics(t>=4 & t<5,c.available(4))==1));
    assert(all(tactics(t>=2 & t<5,c.takeover(1))==1));
    assert(any(tactics(t>=5 & t<6,c.takeover(1))==0));
    report.fault=struct('parameters',P,'traceShape',size(trace),'tacticsShape',size(tactics), ...
        'columns',{{'tSim','phase','globalChaser','strikerAvailable','takeover','recovering','failed'}}, ...
        'samples',selected,'lastTime',trace(end,61),'allFinite',all(isfinite([trace tactics]),'all'));

    % Second exercise: read back the saved forty-millisecond match.
    P=tdp.v1Config();
    P.Tmatch=10;
    P.dt=0.04;
    runDir=fullfile(root,'build','v1-handson-01','run-40ms');
    assert(~isfolder(runDir),'TDP:ExistingAttempt','Use a new handson attempt directory.');
    runReceipt=tdpRun(P,runDir);
    data=load(fullfile(runDir,'trace.mat'));
    assert(strcmp(runReceipt.status,'COMPLETED'));
    assert(isequal(size(data.trace),[250 98]) && isequal(size(data.tactics),[250 171]));
    assert(data.P.dt==0.04 && abs(data.trace(end,61)-10)<1e-12);
    assert(all(isfinite([data.trace data.tactics]),'all'));
    report.savedRun=struct('relativeDirectory','build/v1-handson-01/run-40ms', ...
        'status',runReceipt.status,'traceShape',size(data.trace), ...
        'tacticsShape',size(data.tactics),'matVariables',{fieldnames(data)'}, ...
        'lastTime',data.trace(end,61),'allFinite',true,'metrics',runReceipt.metrics);
    copyfile(fullfile(runDir,'receipt.json'),fullfile(outDir,'saved-run-receipt.json'));
    report.status='PASS';
catch failure
    report.status='FAIL';
    report.error=getReport(failure,'extended','hyperlinks','off');
    report.elapsedSeconds=toc(started);
    writeJson(fullfile(outDir,'receipt.json'),report);
    rethrow(failure)
end
report.elapsedSeconds=toc(started);
writeJson(fullfile(outDir,'receipt.json'),report);
fprintf('V1 hands-on PASS: %d fault frames and %d saved frames.\n',size(trace,1),size(data.trace,1));
