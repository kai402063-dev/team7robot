function report=validate_stage2(outDir)
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new evidence directory');mkdir(outDir);
diary(fullfile(outDir,'matlab.log'));c=onCleanup(@()diary('off'));
r=runtests({'tests/test_actuator.m','tests/test_controller.m'});
report=struct('status','PASS','names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]);
if any(~[r.Passed]),report.status='FAIL';end
writeJson(fullfile(outDir,'receipt.json'),report);assertSuccess(r);
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;records=runReplay(P,makeScenario(P,2));
writeJson(fullfile(outDir,'timeout-replay.json'),struct('dt',P.dt,'columns',{{'kind','requestId','phase','vx','vy','w','targetX','targetY','speed','stamp','validUntil'}},'records',records));
end
