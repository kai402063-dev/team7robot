function report=validate_stage1(outDir)
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);
diary(fullfile(outDir,'matlab.log'));c=onCleanup(@()diary('off'));
r=runtests('tests/test_algorithms.m');
writeJson(fullfile(outDir,'tests.json'),struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]));
assertSuccess(r);
names={'goToPose','kickSkill','robotModel','ballModel','collisions','rulesCheck','roleAssignment','actionSelection','laneClear','angWrap','kickoffReset'};
report=struct('status','PASS','casesPerFunction',1000,'tolerance',1e-12,'functions',{names},'screening',[]);
for k=1:numel(names)
 try
  if isempty(which('coder.screener'))
   error('TDP:ScreenerUnavailable','coder.screener is unavailable in this MATLAB installation.');
  end
  info=coder.screener(['tdp.' names{k}]);
  messages=evalc('disp(info.Messages)');
  for j=1:numel(info.Messages)
   messages=[messages newline char(string(info.Messages(j).Type)) ': ' char(string(info.Messages(j).Identifier)) newline char(string(info.Messages(j).Text))]; %#ok<AGROW>
  end
  entry=struct('name',names{k},'status','PASS','unsupportedCalls',numel(info.UnsupportedCalls), ...
   'messageCount',numel(info.Messages),'reviewRequired',~isempty(info.Messages),'messages',messages);
  % Nonempty diagnostic messages require review; do not infer their severity.
  if ~isempty(info.Messages),entry.status='BLOCKED';end
  if ~isempty(info.UnsupportedCalls),entry.status='FAIL';end
 catch e
  status='FAIL';
  if strcmp(e.identifier,'TDP:ScreenerUnavailable') || contains(lower(e.identifier),'license')
   status='BLOCKED';
  end
  entry=struct('name',names{k},'status',status,'unsupportedCalls',-1,'messageCount',-1, ...
   'reviewRequired',false,'messages',getReport(e,'extended','hyperlinks','off'));
 end
 report.screening=[report.screening entry];
end
if any(strcmp({report.screening.status},'FAIL'))
 report.status='FAIL';
elseif any(strcmp({report.screening.status},'BLOCKED'))
 report.status='BLOCKED';
end
writeJson(fullfile(outDir,'receipt.json'),report);disp(report);
assertStage1Gate(report);
end
