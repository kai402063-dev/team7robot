function tests=test_validation_receipts
tests=functiontests(localfunctions);
end
function testStage1Pass(t)
r=screeningReport();verifyWarningFree(t,@()assertStage1Gate(r));
end
function testStage1BlockedCannotPass(t)
r=screeningReport();r.screening.status='BLOCKED';r.screening.unsupportedCalls=-1;
verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Blocked');
end
function testStage1UnsupportedCannotPass(t)
r=screeningReport();r.screening.unsupportedCalls=1;
verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Failed');
end
function testStage1MessagesRequireReview(t)
r=screeningReport();r.screening.messageCount=1;r.screening.messages='Unclassified diagnostic';
verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Blocked');
end
function testStage1FailDominatesBlocked(t)
r=screeningReport();r.screening(2)=r.screening;
r.screening(1).status='BLOCKED';r.screening(1).unsupportedCalls=-1;
r.screening(2).status='FAIL';r.screening(2).unsupportedCalls=1;
verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Failed');
end
function testStage1PartialAndMissingCannotPass(t)
r=screeningReport();r.status='PARTIAL';verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Failed');
r.status='PASS';r.screening=[];verifyError(t,@()assertStage1Gate(r),'TDP:Stage1Failed');
end
function r=screeningReport()
r=struct('status','PASS','screening',struct('name','goToPose','status','PASS','unsupportedCalls',0,'messageCount',0,'messages',''));
end
function testCameraFailureIsNotPass(t)
root=tdpSetup();previous=pwd;cd(root);cleanup=onCleanup(@()cd(previous)); %#ok<NASGU>
base=tempname(fullfile(root,'build'));mkdir(base);inputDir=fullfile(base,'input');mkdir(inputDir);outDir=fullfile(base,'output');
writeJson(fullfile(inputDir,'camera-ros.json'),struct('width',160,'height',120,'step',640,'encoding','mono8'));
f=fopen(fullfile(inputDir,'camera-ros.bgra'),'wb');fwrite(f,zeros(76800,1,'uint8'),'uint8');fclose(f);
threw=false;try,validate_camera(inputDir,outDir);catch,threw=true;end
verifyTrue(t,threw);r=jsondecode(fileread(fullfile(outDir,'camera-receipt.json')));
verifyEqual(t,r.status,'FAIL');verifyEqual(t,r.ErrorCode,1);
end
function testReplayFailureIsNotPass(t)
root=tdpSetup();previous=pwd;cd(root);cleanup=onCleanup(@()cd(previous)); %#ok<NASGU>
base=tempname(fullfile(root,'build'));mkdir(base);inputDir=fullfile(base,'input');mkdir(inputDir);outDir=fullfile(base,'output');
P=tdp.defaultConfig();P.dt=.04;P.mode=TdpMode.Delayed;P.kickTimeout=12;P.recoverTime=2;
frames=makeBridgeFrames(P,10);records=runFrameReplay(P,frames);
raw=repmat(struct('frame',zeros(1,20)),size(frames,1),1);for k=1:numel(raw),raw(k).frame=frames(k,:);end
writeJson(fullfile(inputDir,'proxy-records.json'),raw);records(1,1)=records(1,1)+1234;
writeJson(fullfile(inputDir,'matlab-actions.json'),records);
threw=false;try,validate_webots_replay(inputDir,outDir);catch,threw=true;end
verifyTrue(t,threw);r=jsondecode(fileread(fullfile(outDir,'replay-receipt.json')));
verifyEqual(t,r.status,'FAIL');verifyFalse(t,r.exactActions);
end
