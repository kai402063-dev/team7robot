function receipt=validate_stage0(outDir)
%VALIDATE_STAGE0 Run 20 complete matches for each noise setting, twice.
if nargin<1,outDir=fullfile('evidence','0',['attempt-' char(datetime('now','Format','yyyyMMdd-HHmmssSSS'))]);end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);
diary(fullfile(outDir,'matlab.log'));c=onCleanup(@()diary('off'));
check_environment(outDir);results=runtests('tests/test_baseline.m');assertSuccess(results);
summary=repmat(struct('seed',0,'kickNoise',0,'duration',600,'identical',false,'score',[0 0],'shots',[0 0],'firstTouch',0,'traceFile',''),40,1);
index=0;
for noise=[0 deg2rad(6)]
 for seed=1:20
  index=index+1;fprintf('Baseline %d/40: seed %d noise %.17g\n',index,seed,noise);
  a=runA(seed,noise,600);b=runA(seed,noise,600);assert(isequaln(a,b),'TDP:Replay','Replay differs');
  traceFile=fullfile('build',sprintf('baseline-%02d-%02d.mat',index,seed));save(traceFile,'a','-v7');
  summary(index)=struct('seed',seed,'kickNoise',noise,'duration',600,'identical',true, ...
   'score',a.state.score,'shots',a.state.shots,'firstTouch',a.firstTouch,'traceFile',traceFile);
 end
end
receipt=struct('status','PASS','matches',80,'stepsPerMatch',12000,'summary',summary);
writeJson(fullfile(outDir,'receipt.json'),receipt);
end
