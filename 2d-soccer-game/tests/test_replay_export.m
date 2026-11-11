function tests=test_replay_export
%TEST_REPLAY_EXPORT MP4 export: validity, time mapping, argument errors, failures.
% Each rendered frame costs about one second on this software-rendered setup,
% so the tests export only a handful of frames.
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'scripts'),fullfile(root,'algorithms'),fullfile(root,'interfaces'), ...
    fullfile(root,'environment'));
set(groot,'DefaultFigureVisible','off');
t.TestData.root=root;
t.TestData.long=fullfile(root,'build','animation-20261106-151829-226','trace.mat');
[status,~]=system('env -u LD_LIBRARY_PATH -u LD_PRELOAD ffmpeg -version');
assumeEqual(t,status,0,'ffmpeg is required for the export tests');
[status,~]=system('env -u LD_LIBRARY_PATH -u LD_PRELOAD ffprobe -version');
assumeEqual(t,status,0,'ffprobe is required to inspect exported files');
end

function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end

function testExportedFileIsPlayableAndTimeMappingIsExact(t)
rec=writeSynthetic(t,30);                              % 1.5 s of simulation time
out=fullfile(t.TestData.folder,'clip.mp4');
before=fileDigest(rec.File);
result=exportReplayVideo(rec,out,struct('StartTime',0.5,'EndTime',1.0));
verifyTrue(t,isfile(out));
verifyEqual(t,result.Frames,11);
verifyEqual(t,result.Rows,10:20);
verifyEqual(t,result.FrameRate,20);
verifyEqual(t,result.Speed,1,'AbsTol',1e-12);
info=probe(out);
verifyEqual(t,info.codec_name,'h264');
verifyEqual(t,info.pix_fmt,'yuv420p');
verifyEqual(t,str2double(info.nb_frames),11);
verifyEqual(t,info.r_frame_rate,'20/1');
verifyEqual(t,mod([info.width info.height],2),[0 0],'even dimensions for yuv420p');
verifyEqual(t,str2double(info.duration),11/20,'AbsTol',1e-6);
% Mapping table: video_time=(k-1)/fps and sim_time equals the source row's time.
map=readmatrix(result.MappingCsv,'NumHeaderLines',1);
verifyEqual(t,size(map),[11 4]);
verifyEqual(t,map(:,1)',1:11);
verifyEqual(t,map(:,2)',((1:11)-1)/20,'AbsTol',1e-6);
verifyEqual(t,map(:,3)',10:20);
verifyEqual(t,map(:,4),rec.Times(10:20),'AbsTol',1e-6);
meta=jsondecode(fileread(result.MappingJson));
verifyEqual(t,meta.firstTraceRow,10);verifyEqual(t,meta.simStartSeconds,0.5,'AbsTol',1e-9);
verifyEqual(t,meta.sourceSha256,before);
verifyEqual(t,fileDigest(rec.File),before,'the source recording is untouched');
end

function testStrideChangesFrameRateAndSpeedConsistently(t)
rec=writeSynthetic(t,30);
out=fullfile(t.TestData.folder,'stride.mp4');
result=exportReplayVideo(rec,out,struct('StartTime',0.5,'EndTime',1.0,'Stride',5));
verifyEqual(t,result.Rows,[10 15 20]);
verifyEqual(t,result.FrameRate,4,'AbsTol',1e-12);       % 1/(0.05*5)
verifyEqual(t,result.Speed,1,'AbsTol',1e-12);
verifyEqual(t,str2double(probe(out).nb_frames),3);
result=exportReplayVideo(rec,fullfile(t.TestData.folder,'fast.mp4'), ...
    struct('StartTime',0.5,'EndTime',1.0,'Stride',5,'FrameRate',20));
verifyEqual(t,result.Speed,5,'AbsTol',1e-12);            % 5 rows per video frame at 20 fps
end

function testRealRecordingIntervalWithTactics(t)
assumeTrue(t,isfile(t.TestData.long),'600 s recording not present');
out=fullfile(t.TestData.folder,'real.mp4');
before=fileDigest(t.TestData.long);
result=exportReplayVideo(t.TestData.long,out,struct('StartTime',166.6,'EndTime',166.8));
fprintf('[timing] export %d frames of the 600 s match: render %.1f s, encode %.2f s\n', ...
    result.Frames,result.RenderSeconds,result.EncodeSeconds);
verifyEqual(t,result.Rows,3332:3336);
verifyEqual(t,result.SimStart,166.6,'AbsTol',1e-9);
verifyEqual(t,str2double(probe(out).nb_frames),5);
verifyEqual(t,fileDigest(t.TestData.long),before);
end

function testBadArgumentsFailClearlyAndCreateNothing(t)
rec=writeSynthetic(t,30);
folder=t.TestData.folder;
out=fullfile(folder,'a.mp4');
verifyError(t,@()exportReplayVideo(rec,fullfile(folder,'a.avi')),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('StartTime',50,'EndTime',60)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('StartTime',1,'EndTime',0.5)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('Stride',0)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('Stride',1.5)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('CRF',99)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('FrameRate',-1)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('FrameRate',NaN)),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(fullfile(folder,'missing.mat'),out),'TDP:ReplayExport');
verifyError(t,@()exportReplayVideo(rec,out,struct('FFmpeg','/nonexistent/ffmpeg')),'TDP:ReplayExport');
verifyFalse(t,isfile(out));
verifyEmpty(t,dir(fullfile(folder,'*.map.*')));
end

function testExistingOutputIsNeverOverwrittenByDefault(t)
rec=writeSynthetic(t,30);
out=fullfile(t.TestData.folder,'keep.mp4');
writelines("precious",out);
verifyError(t,@()exportReplayVideo(rec,out,struct('StartTime',0.5,'EndTime',0.5)),'TDP:ReplayExport');
verifyEqual(t,strtrim(fileread(out)),'precious');
end

function testEncoderFailureIsReportedAndLeavesNoVideo(t)
rec=writeSynthetic(t,30);
fake=fullfile(t.TestData.folder,'fake_ffmpeg.sh');
writelines(["#!/bin/sh";'case "$1" in -version) echo fake; exit 0;; esac';'echo "encoder exploded" >&2';'exit 1'],fake);
system(['chmod +x ' shellQuote(fake)]);
out=fullfile(t.TestData.folder,'fail.mp4');
verifyError(t,@()exportReplayVideo(rec,out,struct('StartTime',0.5,'EndTime',0.5,'FFmpeg',fake)),'TDP:ReplayExport');
verifyFalse(t,isfile(out));
end

function rec=writeSynthetic(t,rows)
c=replayColumns();
trace=zeros(rows,98);
trace(:,c.time)=(1:rows)'*0.05;
trace(:,c.role)=repmat([1 3 5 2 1 3 5 2],rows,1);
trace(:,c.x)=repmat(linspace(-3,3,8),rows,1);
P=tdp.defaultConfig();P.Tmatch=rows*P.dt;
file=fullfile(t.TestData.folder,'trace.mat');
save(file,'P','trace');
rec=loadReplayRecording(file);
end

function info=probe(file)
[status,text]=system(['env -u LD_LIBRARY_PATH -u LD_PRELOAD ffprobe -v error -select_streams v:0 ' ...
    '-show_entries stream=codec_name,pix_fmt,width,height,r_frame_rate,nb_frames,duration ' ...
    '-of json ' shellQuote(file)]);
assert(status==0,'ffprobe could not read %s: %s',file,text);
info=jsondecode(text).streams;
end

function digest=fileDigest(file)
[status,out]=system(['sha256sum ' shellQuote(file)]);
assert(status==0,'sha256sum failed');
digest=strtok(strtrim(out));
end
