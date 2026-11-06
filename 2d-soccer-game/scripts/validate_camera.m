function receipt=validate_camera(inputDir,outDir)
%VALIDATE_CAMERA Decode an actual received ROS Image and save measured evidence.
if ~isfolder(outDir),mkdir(outDir);end
r=runtests('tests/test_camera.m');assertSuccess(r);
meta=jsondecode(fileread(fullfile(inputDir,'camera-ros.json')));
f=fopen(fullfile(inputDir,'camera-ros.bgra'),'rb');cleanup=onCleanup(@()fclose(f));bytes=fread(f,inf,'*uint8');
encoding=uint8(strcmp(meta.encoding,'bgra8'));
[rgb,ErrorCode]=DecodeBgra(bytes,meta.width,meta.height,meta.step,encoding);
receipt=struct('status','PASS_CUSTOM_DECODER','ErrorCode',ErrorCode,'meta',meta, ...
 'nativeReadImage','BLOCKED: ROS Toolbox not installed','tests',struct('names',{{r.Name}},'passed',[r.Passed]));
if ErrorCode~=0,receipt.status='FAIL';end
writeJson(fullfile(outDir,'camera-receipt.json'),receipt);
assert(ErrorCode==0,'TDP:CameraDecode','Camera decoding failed with ErrorCode %d.',ErrorCode);
imwrite(rgb,fullfile(outDir,'camera.png'));
end
