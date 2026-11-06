function check_prebuilt()
root=tdpSetup();
outDir=fullfile(root,'build','shipped-command-01');
manifest=fullfile(root,'scripts','v1_matrix_evidence.py');
record={'python3',manifest,'sources',fullfile(outDir,'source-before.json')};
runCommand(record);
for period=[.05 .04]
    P=tdp.v1Config();
    P.seed=1;
    P.dt=period;
    P.Tmatch=600;
    start=tic;
    [trace,tactics]=runMatch(P);
    artifact=sprintf('prebuilt-%02dms.mat',round(1000*period));
    save(fullfile(outDir,artifact),'trace','tactics','P','-v7');
    info=sprintf('prebuilt-%02dms.json',round(1000*period));
    runCommand({'python3',manifest,'artifact',fullfile(outDir,artifact),fullfile(outDir,info)});
    [metrics,violations]=v1MatchMetrics(trace,tactics,P);
    result=struct('seed',P.seed,'period',P.dt,'seconds',P.Tmatch,'elapsedSeconds',toc(start), ...
         'parameters',P,'metrics',metrics,'violations',violations,'artifactHashFile',info);
    writeJson(fullfile(outDir,sprintf('run-%02dms.json',round(1000*period))),result);
    assert(metrics.passed,'TDP:Prebuilt','An invariant failed in the delivered model.');
    fprintf('PREBUILT %.3f %d actual steps, %.2f elapsed seconds\n',period,size(trace,1),toc(start));
end
runCommand({'python3',manifest,'sources',fullfile(outDir,'source-after.json')});
end

function runCommand(args)
parts=cellfun(@shellQuote,args,'UniformOutput',false);
[status,detail]=system(strjoin(parts,' '));
assert(status==0,'%s',detail);
end
