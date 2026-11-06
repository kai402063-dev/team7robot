function receipt=reproduce_v1(outDir,rebuild)
%REPRODUCE_V1 Rebuild and verify Team 7's V1 tactics on the actual 4v4 model.
root=tdpSetup();
if nargin<1
    stamp=char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'));
    outDir=fullfile(root,'build',['reproduce-v1-' stamp]);
end
if nargin<2, rebuild=true; end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory.');
mkdir(outDir);
[ok,info]=fileattrib(outDir);
assert(ok,'TDP:Output','Could not resolve the output directory.');
outDir=info.Name;
receiptPath=fullfile(outDir,'receipt.json');
started=tic;
receipt=struct('status','RUNNING','rebuild',rebuild,'matlabVersion',version);
writeJson(receiptPath,receipt);
try
    if rebuild
        build_controller();
        build_v1_match();
    end
    receipt.modelPreparationSeconds=toc(started);
    testFiles={'test_v1_tactics.m','test_v1_model.m','test_v1_matrix.m'};
    for index=1:numel(testFiles)
        testFiles{index}=fullfile(root,'tests',testFiles{index});
    end
    results=runtests(testFiles);
    tests=struct('names',{{results.Name}},'passed',[results.Passed], ...
                 'failed',[results.Failed],'incomplete',[results.Incomplete]);
    writeJson(fullfile(outDir,'tests.json'),tests);
    assertSuccess(results);
    receipt.testCount=numel(results);
    writeJson(receiptPath,receipt);
    matches=fullfile(outDir,'matches');
    worker=validate_v1_matrix(matches,[.05 .04],1:20);
    assert(worker.completedMatches==40,'TDP:V1Matrix','Expected forty complete matches.');
    summary=fullfile(outDir,'summary');
    aggregator=fullfile(root,'scripts','v1_matrix_evidence.py');
    command=['python3 ' shellQuote(aggregator) ' summarize ' shellQuote(summary) ' ' shellQuote(matches)];
    [code,output]=system(command);
    assert(code==0,'TDP:V1Summary','%s',output);
    verified=jsondecode(fileread(fullfile(summary,'receipt.json')));
    receipt.officialMatches=verified.officialMatches;
    receipt.totalOfficialSteps=verified.totalOfficialSteps;
    receipt.summary='summary/receipt.json';
    receipt.status='PASS';
catch failure
    receipt.status='FAIL';
    receipt.error=getReport(failure,'extended','hyperlinks','off');
    receipt.elapsedSeconds=toc(started);
    writeJson(receiptPath,receipt);
    rethrow(failure);
end
receipt.elapsedSeconds=toc(started);
writeJson(receiptPath,receipt);
fprintf('V1 verification: %d matches, %d steps. %s\n', ...
        receipt.officialMatches,receipt.totalOfficialSteps,receiptPath);
end
