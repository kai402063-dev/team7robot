function receipt=reproduce_all(outDir)
%REPRODUCE_ALL Full baseline gates, generated manual and honest dependency status.
root=tdpSetup();cd(root);
if nargin<1,outDir=fullfile(root,'build',['reproduce-' char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'))]);end
assert(~isfolder(outDir),'TDP:ExistingAttempt','Use a new output directory');mkdir(outDir);
started=datetime('now');receipt=struct('status','RUNNING','outputDirectory',outDir);
writeJson(fullfile(outDir,'receipt.json'),receipt);
try
 build_all;export_manual;
 [status,output]=system('python3 scripts/audit_manual.py');assert(status==0,output);
 receipt.stage0=validate_stage0(fullfile(outDir,'stage0'));
 receipt.stage1=validate_stage1(fullfile(outDir,'stage1'));
 assertStage1Gate(receipt.stage1);
 receipt.stage2=validate_stage2(fullfile(outDir,'stage2'));
 receipt.stage3=validate_stage3(fullfile(outDir,'stage3'));
 zero=receipt.stage3.comparisons([receipt.stage3.comparisons.kickNoise]==0);
 assert(all([zero.maximumDifference]<=1e-12),'TDP:Compatibility','Zero-noise compatibility gate failed');
 assert(all(arrayfun(@(r)isequal(r.oracle.goals,r.migrated.goals)&&isequal(r.oracle.shots,r.migrated.shots)&&isequal(r.oracle.firstTouchSeconds,r.migrated.firstTouchSeconds),receipt.stage3.comparisons)),'TDP:Metrics','Comparison metrics changed');
 receipt.repairs=validate_repairs(fullfile(outDir,'repairs'),false);
 receipt.teaching=validate_teaching(fullfile(outDir,'teaching'),false);
 receipt.animation=validate_animation(fullfile(outDir,'animation'),'off');
 receipt.teamV1=reproduce_v1(fullfile(outDir,'team-v1'),false);
 r=runtests('tests/test_manual_numbers.m');assertSuccess(r);
 receipt.manual=struct('names',{{r.Name}},'passed',[r.Passed]);
 r=runtests('tests/test_validation_receipts.m');assertSuccess(r);
 receipt.validationReceipts=struct('names',{{r.Name}},'passed',[r.Passed]);
 [status,output]=system('python3 scripts/verify_mutations.py');assert(status==0,output);
 receipt.mutationAudit=output;
 receipt.rosOnline='BLOCKED: ROS Toolbox not installed; installation not authorized';
 receipt.rosStandalone='BLOCKED: Simulink Coder and MATLAB Coder not installed';
 receipt.status='PASS_2D_WITH_DOCUMENTED_NOISY_TRACE_DIFFERENCES';
 if isfile(fullfile(root,'scripts','reproduce_m2.m'))
  receipt.m2=reproduce_m2(fullfile(outDir,'m2'));
  receipt.status='PASS_AVAILABLE_M2_WITH_BLOCKERS_AND_NOISY_TRACE_DIFFERENCES';
 end
catch e
 receipt.status='FAIL';
 if strcmp(e.identifier,'TDP:Stage1Blocked'),receipt.status='BLOCKED';end
 if startsWith(e.identifier,'TDP:Stage1') && isfile(fullfile(outDir,'stage1','receipt.json'))
  receipt.stage1=jsondecode(fileread(fullfile(outDir,'stage1','receipt.json')));
 end
 receipt.errorIdentifier=e.identifier;receipt.error=getReport(e,'extended','hyperlinks','off');
 receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(outDir,'receipt.json'),receipt);rethrow(e);
end
receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(outDir,'receipt.json'),receipt);
fprintf('REPRODUCTION %s in %.1f seconds. Receipt: %s\n',receipt.status,receipt.elapsedSeconds,fullfile(outDir,'receipt.json'));
end
