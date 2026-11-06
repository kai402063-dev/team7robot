function report=validate_teaching(outDir,includeCompatibility)
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);diary(fullfile(outDir,'matlab.log'));c=onCleanup(@()diary('off'));
suites={'tests/test_lessons.m','tests/test_extensions.m'};
if nargin<2 || includeCompatibility,suites=[suites {'tests/test_match.m'}];end
r=runtests(suites);
report=struct('status','PASS','names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]);
if any(~[r.Passed]),report.status='FAIL';end
writeJson(fullfile(outDir,'receipt.json'),report);assertSuccess(r);
end
