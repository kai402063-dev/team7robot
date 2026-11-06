function receipt=reproduce_m2(outDir)
%REPRODUCE_M2 Run all available M2 gates with honest product blockers.
root=tdpSetup();cd(root);assert(~isfolder(outDir),'Use a new M2 attempt directory');mkdir(outDir);
started=datetime('now');receipt=struct('status','RUNNING');writeJson(fullfile(outDir,'receipt.json'),receipt);
try
 command('world','python3 scripts/build_webots.py');
 command('colcon',['./scripts/run_ros.sh colcon --log-base ' shellQuote(fullfile(outDir,'colcon-log')) ...
  ' build --base-paths ros2 --build-base build/colcon/build --install-base build/colcon/install']);
 command('python-tests','python3 -m unittest discover -s tests -p test_webots.py -v');
 receipt.adapter=validate_ros_adapter(fullfile(outDir,'adapter'));
 rosDir=fullfile(outDir,'ros');command('ros',['./scripts/run_ros.sh python3 scripts/validate_ros.py ' shellQuote(rosDir)]);
 receipt.ros=jsondecode(fileread(fullfile(rosDir,'receipt.json')));
 motionDir=fullfile(outDir,'motion');command('motion',['./scripts/run_ros.sh python3 scripts/run_webots.py ' shellQuote(motionDir) ' --mode motion']);
 motion=jsondecode(fileread(fullfile(motionDir,'webots-receipt.json')));
 assert(motion.executions==1&&motion.kickResults.motionEnded&&~motion.kickResults.ballMoved,'TDP:MotionOnly','Separate motion/ball gate failed');
 receipt.motionOnly=motion;
 webotsDir=fullfile(outDir,'webots');command('webots',['./scripts/run_ros.sh python3 scripts/run_webots.py ' shellQuote(webotsDir)]);
 analysisFile=fullfile(outDir,'webots-analysis.json');command('analysis',['python3 scripts/analyze_webots.py ' shellQuote(webotsDir) ' --output ' shellQuote(analysisFile)]);
 receipt.webots=jsondecode(fileread(analysisFile));
 receipt.webotsReplay=validate_webots_replay(webotsDir,fullfile(outDir,'replay'));
 receipt.camera=validate_camera(webotsDir,fullfile(outDir,'camera'));
 for relative={'evidence/4/mutation-integration-01/receipt.json','evidence/5/mutation-executor-01/receipt.json','evidence/5/mutation-trace-01/receipt.json'}
  mutation=jsondecode(fileread(relative{1}));assert(mutation.detected,'Mutation audit failed');
 end
 receipt.nativeRosToolbox='BLOCKED: ROS Toolbox not installed';receipt.generatedNode='BLOCKED: Simulink Coder and MATLAB Coder not installed';
 receipt.nativeReadImage='BLOCKED: ROS Toolbox not installed';receipt.modelValidation='NOT_ESTABLISHED: V5 simulation, uncalibrated parameters';
 receipt.status='PASS_AVAILABLE_M2_GATES_WITH_DEPENDENCY_BLOCKERS';
catch e
 receipt.status='FAIL';receipt.error=getReport(e,'extended','hyperlinks','off');
 receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(outDir,'receipt.json'),receipt);rethrow(e);
end
receipt.elapsedSeconds=seconds(datetime('now')-started);writeJson(fullfile(outDir,'receipt.json'),receipt);
 function command(label,cmd)
  fprintf('M2 %s\n',label);[status,output]=system(cmd);f=fopen(fullfile(outDir,[label '.log']),'w');fprintf(f,'%s',output);fclose(f);assert(status==0,'TDP:M2Command','%s failed: %s',label,output);
 end
end
