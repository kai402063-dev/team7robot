function receipt=tdpRun(P,outDir)
%TDPRUN Save a match trace, V1 decisions and the parameters needed for replay.
if nargin<1, P=tdp.v1Config(); end
if nargin<2
    outDir=fullfile('build',['run-' char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'))]);
end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Refusing to overwrite a run');
mkdir(outDir);
diary(fullfile(outDir,'matlab.log'));
closeLog=onCleanup(@()diary('off')); %#ok<NASGU>
started=tic;
receipt=struct('status','RUNNING','parameters',P);
writeJson(fullfile(outDir,'receipt.json'),receipt);
try
    [trace,tactics,recovery]=runMatch(P);
    save(fullfile(outDir,'trace.mat'),'trace','tactics','P');
    if ~isempty(recovery)
        save(fullfile(outDir,'trace.mat'),'recovery','-append');
    end
    receipt.metrics=matchMetrics(trace,P);
    receipt.tacticsFrames=size(tactics,1)*(size(tactics,2)>0);
    receipt.status='COMPLETED';
catch failure
    receipt.status='FAIL';
    receipt.error=getReport(failure,'extended','hyperlinks','off');
    receipt.elapsedSeconds=toc(started);
    writeJson(fullfile(outDir,'receipt.json'),receipt);
    rethrow(failure);
end
receipt.elapsedSeconds=toc(started);
writeJson(fullfile(outDir,'receipt.json'),receipt);
end
