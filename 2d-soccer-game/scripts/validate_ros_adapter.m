function receipt=validate_ros_adapter(outDir)
%VALIDATE_ROS_ADAPTER Validate transport-independent freshness and Core replay.
if ~isfolder(outDir),mkdir(outDir);end
build_ros_adapter;r=runtests('tests/test_ros_adapter.m');
receipt=struct('names',{{r.Name}},'passed',[r.Passed],'nativeRosToolbox','BLOCKED: not installed','generatedNode','BLOCKED: Coders not installed');
writeJson(fullfile(outDir,'adapter-receipt.json'),receipt);assertSuccess(r);
P=tdp.defaultConfig();P.dt=0.04;P.mode=TdpMode.Delayed;frames=makeBridgeFrames(P,101);
writeJson(fullfile(outDir,'frames.json'),frames);[records,quality]=runFrameReplay(P,frames);
writeJson(fullfile(outDir,'offline-actions.json'),records);writeJson(fullfile(outDir,'offline-quality.json'),quality);
end
