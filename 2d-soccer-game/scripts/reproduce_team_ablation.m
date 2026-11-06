function receipt=reproduce_team_ablation(outDir,referenceDir)
%REPRODUCE_TEAM_ABLATION Compare red-only, then blue-only, with both archived endpoints.
root=tdpSetup();
if nargin<1
    stamp=char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'));
    outDir=fullfile(root,'build',['team-ablation-' stamp]);
end
if nargin<2
    referenceDir=fullfile(root,'evidence','recovery-v1','clean-01');
end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory.');
mkdir(outDir);[~,info]=fileattrib(outDir);outDir=info.Name;
started=tic;
receipt=struct('status','RUNNING','matlabVersion',version,'stage','build');
file=fullfile(outDir,'receipt.json');writeJson(file,receipt);
try
    build_team_recovery_match();
    receipt.stage='tests';writeJson(file,receipt);
    results=runtests(fullfile(root,'tests','test_team_ablation.m'));
    writeJson(fullfile(outDir,'tests.json'),struct('names',{{results.Name}}, ...
        'passed',[results.Passed],'failed',[results.Failed],'incomplete',[results.Incomplete]));
    assertSuccess(results);
    receipt.stage='red-only';writeJson(file,receipt);
    validate_v1_matrix(fullfile(outDir,'red-only'),[.05 .04],1:20,tdp.teamRecoveryConfig([false true]));
    receipt.stage='blue-only';writeJson(file,receipt);
    validate_v1_matrix(fullfile(outDir,'blue-only'),[.05 .04],1:20,tdp.teamRecoveryConfig([true false]));
    % A fresh installation may only have the small committed receipts.
    receipt.stage='reference';writeJson(file,receipt);
    receipt.regeneratedReference=~hasReferenceArtifacts(referenceDir);
    if receipt.regeneratedReference
        referenceDir=fullfile(outDir,'reference');
        reproduce_recovery(referenceDir);
    end
    receipt.referenceDirectory=referenceDir;receipt.stage='analysis';writeJson(file,receipt);
    for name={'analyze_team_ablation.py','audit_team_onset.py'}
        tool=fullfile(root,'scripts',name{1});
        args={'python3',shellQuote(tool),shellQuote(outDir),'--reference',shellQuote(referenceDir)};
        [exitCode,message]=system(strjoin(args,' '));
        assert(exitCode==0,'TDP:TeamComparison','%s: %s',name{1},message);
    end
    receipt.status='PASS';receipt.stage='complete';
    receipt.officialNewMatches=80;receipt.referenceMatches=80;receipt.pairedConfigurations=40;
    receipt.newMatrixReplays=4;receipt.newMatrixSteps=1080000;receipt.tests=numel(results);
catch failure
    receipt.status='FAIL';receipt.error=getReport(failure,'extended','hyperlinks','off');
    receipt.elapsedSeconds=toc(started);writeJson(file,receipt);rethrow(failure);
end
receipt.elapsedSeconds=toc(started);writeJson(file,receipt);
fprintf('Single-team comparison complete: %s\n',fullfile(outDir,'summary.md'));
end

function available=hasReferenceArtifacts(referenceDir)
available=false;
for policy={'v1','recovery'}
    folder=fullfile(referenceDir,policy{1});
    workerFile=fullfile(folder,'receipt.json');
    if ~isfile(workerFile),return;end
    worker=jsondecode(fileread(workerFile));
    matches=dir(fullfile(folder,'dt*-seed*','receipt.json'));
    if numel(matches)~=40,return;end
    for i=1:numel(matches)
        match=jsondecode(fileread(fullfile(matches(i).folder,matches(i).name)));
        if ~isfile(fullfile(worker.executionRoot,match.artifact)),return;end
    end
end
available=true;
end
