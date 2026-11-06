function receipt=validate_v1_matrix(outDir,periods,seeds,P)
%VALIDATE_V1_MATRIX Run actual V1 matches in a fresh output directory.
% Each period uses the same twenty seeds. Two processes may run disjoint
% periods with separate output, MATLAB preferences and Simulink caches.
root=tdpSetup();
if nargin<2, periods=[.05 .04]; end
if nargin<3, seeds=1:20; end
if nargin<4, P=tdp.v1Config(); end
tdp.validateV1Config(P);
automatic=isfield(P,'v1AutoRecovery') && P.v1AutoRecovery;
model='tdpV1Match';
if automatic, model='tdpRecoveryMatch'; end
assert(all(ismember(periods,[.05 .04])) && numel(unique(periods))==numel(periods) ...
    && ~isempty(periods),'TDP:V1Periods','Use one or both qualified periods.');
assert(all(ismember(seeds,1:20)) && numel(unique(seeds))==numel(seeds) ...
    && ~isempty(seeds),'TDP:V1Seeds','Use unique integer seeds 1 through 20.');
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory.');
mkdir(outDir);
[~,attributes]=fileattrib(outDir);
outDir=attributes.Name;
artifactBase=fullfile(root,'build','v1-matrix');
if ~isfolder(artifactBase), mkdir(artifactBase); end
[~,runId]=fileparts(tempname(artifactBase));
artifactRelative=fullfile('build','v1-matrix',runId);
mkdir(fullfile(root,artifactRelative));
diary(fullfile(outDir,'matlab.log'));
diaryCleanup=onCleanup(@()diary('off')); %#ok<NASGU>
started=tic;
receipt=struct('status','RUNNING','periods',periods,'seeds',seeds, ...
    'matchSeconds',600,'completedMatches',0,'elapsedSeconds',0, ...
    'startedAtUtc',utcNow(),'matlabVersion',version,'executionRoot',root, ...
    'cacheId',getenv('TDP_CACHE_ID'),'artifactDirectory',artifactRelative);
writeJson(fullfile(outDir,'started.json'),receipt);
try
    initialSources=fullfile(outDir,'source-before.json');
    evidenceCommand(root,'sources',initialSources);
    source=jsondecode(fileread(initialSources));
    receipt.sourceFingerprint=source.fingerprint;
    receipt.revision=source.revision;
    for dt=periods(:)'
        for seed=seeds(:)'
            P.dt=dt;
            P.seed=seed;
            P.Tmatch=600;
            game=sprintf('dt%02d-seed%02d',round(1000*dt),seed);
            gameDir=fullfile(outDir,game);
            mkdir(gameDir);
            gameReport=struct('status','RUNNING','model',model,'parameters',P, ...
                'sourceFingerprint',source.fingerprint,'revision',source.revision, ...
                'startedAtUtc',utcNow(),'matlabVersion',version);
            writeJson(fullfile(gameDir,'started.json'),gameReport);
            gameTimer=tic;
            try
                [trace,tactics,recovery]=runMatch(P);
                file=fullfile(artifactRelative,[game '.mat']);
                save(fullfile(root,file),'trace','tactics','P','-v7');
                if automatic
                    save(fullfile(root,file),'recovery','-append');
                end
                artifactJson=fullfile(gameDir,'artifact.json');
                evidenceCommand(root,'artifact',fullfile(root,file),artifactJson);
                gameReport.artifact=file;
                [gameReport.metrics,gameReport.violations]=v1MatchMetrics(trace,tactics,P);
                if ~gameReport.metrics.passed
                    error('TDP:V1MatchGate','%s: %s',game, ...
                        strjoin({gameReport.violations.name},', '));
                end
                if automatic
                    gameReport.recovery=recoveryMatchMetrics(tactics,recovery,P);
                end
                if seed==1
                    [secondTrace,secondTactics,secondRecovery]=runMatch(P);
                    gameReport.replay=struct('steps',size(secondTrace,1), ...
                        'samePhysicalTrace',isequal(trace,secondTrace), ...
                        'sameTacticalTrace',isequal(tactics,secondTactics));
                    assert(gameReport.replay.samePhysicalTrace && gameReport.replay.sameTacticalTrace, ...
                        'TDP:V1Replay','Same seed and configuration gave a different trace.');
                    if automatic
                        gameReport.replay.sameRecoveryTrace=isequal(recovery,secondRecovery);
                        assert(gameReport.replay.sameRecoveryTrace,'TDP:RecoveryReplay','Health or handback records differed.');
                    end
                    clear secondTrace secondTactics secondRecovery
                end
                gameReport.status='PASS';
            catch gameError
                gameReport.status='FAIL';
                gameReport.identifier=gameError.identifier;
                gameReport.error=getReport(gameError,'extended','hyperlinks','off');
                gameReport.elapsedSeconds=toc(gameTimer);
                writeJson(fullfile(gameDir,'receipt.json'),gameReport);
                rethrow(gameError)
            end
            gameReport.elapsedSeconds=toc(gameTimer);
            gameReport.finishedAtUtc=utcNow();
            writeJson(fullfile(gameDir,'receipt.json'),gameReport);
            receipt.completedMatches=receipt.completedMatches+1;
            fprintf('%s PASS (%d steps, score %d-%d, %d actual kicks, %.1f wall seconds)\n', ...
                game,size(trace,1),gameReport.metrics.goals(1),gameReport.metrics.goals(2), ...
                sum(gameReport.metrics.actualKicksByRobot),gameReport.elapsedSeconds);
            clear trace tactics
        end
    end
    finalSources=fullfile(outDir,'source-after.json');
    evidenceCommand(root,'sources',finalSources);
    after=jsondecode(fileread(finalSources));
    assert(strcmp(after.fingerprint,source.fingerprint),'TDP:V1SourceDrift', ...
        'Production or validation files changed during the run. Inspect both manifests.');
    receipt.status='PASS_SHARD';
catch failure
    receipt.status='FAIL';
    receipt.identifier=failure.identifier;
    receipt.error=getReport(failure,'extended','hyperlinks','off');
    receipt.elapsedSeconds=toc(started);
    writeJson(fullfile(outDir,'receipt.json'),receipt);
    rethrow(failure)
end
receipt.elapsedSeconds=toc(started);
receipt.finishedAtUtc=utcNow();
writeJson(fullfile(outDir,'receipt.json'),receipt);
end

function evidenceCommand(root,varargin)
args=[{'python3',fullfile(root,'scripts','v1_matrix_evidence.py')} varargin];
quoted=cellfun(@shellQuote,args,'UniformOutput',false);
[status,message]=system(strjoin(quoted,' '));
assert(status==0,'TDP:V1Evidence','Evidence tool failed: %s',message);
end

function stamp=utcNow()
stamp=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
