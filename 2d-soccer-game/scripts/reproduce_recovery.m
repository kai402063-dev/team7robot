function receipt=reproduce_recovery(outDir)
%REPRODUCE_RECOVERY Rebuild the experiment and compare both 40-match policies.
root=tdpSetup();
if nargin<1
    stamp=char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'));
    outDir=fullfile(root,'build',['recovery-comparison-' stamp]);
end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory.');
mkdir(outDir);[~,info]=fileattrib(outDir);outDir=info.Name;
started=tic;
receipt=struct('status','RUNNING','matlabVersion',version);
file=fullfile(outDir,'receipt.json');writeJson(file,receipt);
try
    build_recovery_match();
    suites={'test_recovery_tactics','test_recovery_actuator','test_recovery_model', ...
        'test_v1_tactics','test_v1_model','test_v1_matrix','test_actuator'};
    names=cellfun(@(s)fullfile(root,'tests',[s '.m']),suites,'UniformOutput',false);
    r=runtests(names);
    writeJson(fullfile(outDir,'tests.json'),struct('names',{{r.Name}},'passed',[r.Passed], ...
        'failed',[r.Failed],'incomplete',[r.Incomplete]));
    assertSuccess(r);
    validate_v1_matrix(fullfile(outDir,'v1'),[.05 .04],1:20,tdp.v1Config());
    validate_v1_matrix(fullfile(outDir,'recovery'),[.05 .04],1:20,tdp.recoveryConfig());
    script=fullfile(root,'scripts','compare_recovery.py');
    [exitCode,message]=system(['python3 ' shellQuote(script) ' ' shellQuote(outDir)]);
    assert(exitCode==0,'TDP:RecoveryComparison','%s',message);
    receipt.status='PASS';receipt.matches=80;receipt.pairedCases=40;receipt.tests=numel(r);
catch failure
    receipt.status='FAIL';receipt.error=getReport(failure,'extended','hyperlinks','off');
    receipt.elapsedSeconds=toc(started);writeJson(file,receipt);rethrow(failure);
end
receipt.elapsedSeconds=toc(started);writeJson(file,receipt);
fprintf('Recovery comparison: 40 matched pairs. %s\n',file);
end
