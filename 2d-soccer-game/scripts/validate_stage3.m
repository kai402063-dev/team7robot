function report=validate_stage3(outDir)
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);
diary(fullfile(outDir,'matlab.log'));clean=onCleanup(@()diary('off'));started=datetime('now');
r=runtests('tests/test_match.m');writeJson(fullfile(outDir,'tests.json'),struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]));assertSuccess(r);
P=tdp.defaultConfig();rows=struct([]);
for ni=1:2
 for seed=1:20
  P.seed=seed;P.kickNoise=(ni-1)*deg2rad(6);
  a=runA(seed,P.kickNoise,600);b=runMatch(P);d=abs(a.trace-b);mask=d>1e-12;
  first=find(any(mask,2),1);column=0;firstStep=0;if ~isempty(first),firstStep=first;column=find(mask(first,:),1);end
  row=struct('seed',seed,'kickNoise',P.kickNoise,'maximumDifference',max(d,[],'all'), ...
   'firstDifferentStep',firstStep,'firstDifferentColumn',column,'exact',isequal(a.trace,b), ...
   'oracle',matchMetrics(a.trace,P),'migrated',matchMetrics(b,P));
  if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
  file=fullfile('build',sprintf('match-%02d-%02d.mat',ni,seed));save(file,'b','-v7');
  writeJson(fullfile(outDir,sprintf('match-%02d-%02d.json',ni,seed)),row);
  fprintf('noise=%g seed=%d first=%d max=%g goals=[%g %g]\n',P.kickNoise,seed,firstStep,row.maximumDifference,row.migrated.goals);
 end
end
P.dt=.04;P.seed=1;P.kickNoise=0;b=runMatch(P);m40=matchMetrics(b,P);save('build/match-forty-ms.mat','b');
report=struct('status','PASS','comparisons',rows,'fortyMilliseconds',m40,'elapsedSeconds',seconds(datetime('now')-started));
if any([rows.firstDifferentStep]>0),report.status='DIVERGENCE';end
if any(~arrayfun(@(x)x.migrated.finite,rows)) || ~m40.finite,report.status='FAIL';end
writeJson(fullfile(outDir,'receipt.json'),report);
end
