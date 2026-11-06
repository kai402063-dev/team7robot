function report=validate_repairs(outDir,includeIntegration)
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);diary(fullfile(outDir,'matlab.log'));c=onCleanup(@()diary('off'));
suites={'tests/test_source_defects.m','tests/test_repairs.m'};
if nargin<2 || includeIntegration,suites=[suites {'tests/test_match.m','tests/test_actuator.m','tests/test_controller.m'}];end
r=runtests(suites);
report=struct('status','PASS','names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]);
writeJson(fullfile(outDir,'tests.json'),report);assertSuccess(r);
for dt=[.05 .04]
 P=tdp.defaultConfig();P.dt=dt;P.rulesProfile=TdpRules.CourseSimplified;P.seed=13;
 b=runMatch(P);m=matchMetrics(b,P);assert(m.finite && m.overlapSteps==0 && m.outsideBorderRobotSamples==0);
 writeJson(fullfile(outDir,sprintf('long-run-%02dms.json',round(1000*dt))),m);
 save(fullfile('build',sprintf('repaired-%02dms.mat',round(1000*dt))),'b');
end
writeJson(fullfile(outDir,'receipt.json'),report);
end
