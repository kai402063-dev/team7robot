function receipt=validate_webots_replay(inputDir,outDir)
%VALIDATE_WEBOTS_REPLAY Replay the real recorded Webots observations through Core.
if ~isfolder(outDir),mkdir(outDir);end
raw=jsondecode(fileread(fullfile(inputDir,'proxy-records.json')));frames=zeros(numel(raw),20);
for k=1:numel(raw),frames(k,:)=reshape(raw(k).frame,1,20);end
config=jsondecode(fileread('config/webots.json'));
P=tdp.defaultConfig();P.dt=.04;P.mode=TdpMode.Delayed;P.kickTimeout=config.kickTimeoutSeconds;P.recoverTime=config.recoverTimeSeconds;
[a,q]=runFrameReplay(P,frames);b=jsondecode(fileread(fullfile(inputDir,'matlab-actions.json')));
receipt=struct('status','PASS','frames',size(frames,1),'exactActions',isequal(a,b));
if ~receipt.exactActions,receipt.status='FAIL';end
writeJson(fullfile(outDir,'replay-receipt.json'),receipt);
assert(receipt.exactActions,'TDP:WebotsReplay','Recorded and replayed actions differ.');
writeJson(fullfile(outDir,'offline-quality.json'),q);
end
