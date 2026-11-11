function result=exportReplayVideo(source,outFile,opts)
%EXPORTREPLAYVIDEO Render a recorded match (or a time interval) to an H.264 MP4.
%   result = exportReplayVideo(source,outFile)
%   result = exportReplayVideo(source,outFile,opts)
%
% source   trace.mat path, build/animation-* folder, or a struct returned by
%          loadReplayRecording
% outFile  target path ending in .mp4; an existing file is never overwritten
%          unless opts.Overwrite is true
% opts     StartTime  first simulation second to include (default: start)
%          EndTime    last simulation second to include (default: end)
%          Stride     use every Stride-th recorded row (default 1)
%          FrameRate  video frames per second (default 1/(dt*Stride), real time)
%          CRF        libx264 quality, lower is better (default 18)
%          FFmpeg     ffmpeg executable (default 'ffmpeg')
%          KeepFrames keep the PNG frames (default false)
%          Overwrite  allow replacing outFile (default false)
%
% Method: the recorded rows are drawn one by one by MatchReplay2D (the same
% window the user sees, including the inspector), each frame is captured with
% getframe, and FFmpeg encodes the PNG sequence. Nothing is re-simulated and the
% trace file is only read. Rendering is by row number, not by wall clock, so the
% video contains exactly the selected rows in order, however slow the machine.
%
% Time mapping (also written to <outFile>.map.csv and <outFile>.map.json):
%   video frame k (1-based) shows trace row rows(k)
%   video time of frame k  = (k-1) / FrameRate         seconds
%   simulation time        = trace(rows(k),61)         seconds
%   playback speed         = dt*Stride*FrameRate       (1 means real time)
% The simulation clock is also drawn inside every frame.
%
% Errors use the identifier TDP:ReplayExport.
if nargin<3,opts=struct();end
start=option(opts,'StartTime',-Inf);
finish=option(opts,'EndTime',Inf);
stride=option(opts,'Stride',1);
crf=option(opts,'CRF',18);
ffmpeg=option(opts,'FFmpeg','ffmpeg');
keepFrames=option(opts,'KeepFrames',false);
overwrite=option(opts,'Overwrite',false);
outFile=char(outFile);
if isstruct(source) && isfield(source,'Trace')
    rec=source;
else
    try
        rec=loadReplayRecording(source);
    catch problem
        error('TDP:ReplayExport','无法读取录像来源：%s',problem.message);
    end
end
checkScalar(start,'StartTime',true);checkScalar(finish,'EndTime',true);
checkScalar(stride,'Stride',false);checkScalar(crf,'CRF',false);
assert(stride>=1 && stride==round(stride),'TDP:ReplayExport','Stride 必须是正整数。');
assert(crf>=0 && crf<=51 && crf==round(crf),'TDP:ReplayExport','CRF 必须是 0..51 的整数。');
frameRate=option(opts,'FrameRate',1/(rec.Dt*stride));
checkScalar(frameRate,'FrameRate',false);
assert(frameRate>0,'TDP:ReplayExport','FrameRate 必须为正。');
[folder,~,extension]=fileparts(outFile);
assert(strcmpi(extension,'.mp4'),'TDP:ReplayExport','输出文件必须以 .mp4 结尾：%s',outFile);
if isfile(outFile) && ~overwrite
    error('TDP:ReplayExport','输出文件已存在，不会覆盖：%s',outFile);
end
if ~isempty(folder) && ~isfolder(folder)
    [made,why]=mkdir(folder);
    assert(made,'TDP:ReplayExport','无法创建输出目录 %s：%s',folder,why);
end

times=rec.Times;
first=find(times>=start-1e-6,1,'first');
last=find(times<=finish+1e-6,1,'last');
if isempty(first) || isempty(last) || last<first
    error('TDP:ReplayExport','选定区间 [%g, %g] s 内没有记录帧（记录范围 %g–%g s）。', ...
        start,finish,times(1),times(end));
end
rows=first:stride:last;
count=numel(rows);

shell=['env -u LD_LIBRARY_PATH -u LD_PRELOAD ' shellQuote(ffmpeg)];
[status,text]=system([shell ' -version']);
if status~=0
    error('TDP:ReplayExport','找不到可运行的 ffmpeg（%s）。输出：%s',ffmpeg,strtrim(text));
end

work=tempname;
mkdir(work);
cleanup=onCleanup(@()removeWork(work,keepFrames)); %#ok<NASGU>
renderTimer=tic;
player=MatchReplay2D(rec.P,rec.Trace,'export','off',rec.Tactics);
figureCleanup=onCleanup(@()deleteFigure(player.Figure)); %#ok<NASGU>
player.Pause();
for k=1:count
    player.SeekFrame(rows(k));
    captured=getframe(player.Figure);
    imwrite(captured.cdata,fullfile(work,sprintf('frame_%06d.png',k)));
end
renderSeconds=toc(renderTimer);

encodeTimer=tic;
pattern=fullfile(work,'frame_%06d.png');
command=sprintf(['%s -y -loglevel error -framerate %.10g -i %s ' ...
    '-vf %s -c:v libx264 -pix_fmt yuv420p -crf %d %s'], ...
    shell,frameRate,shellQuote(pattern),shellQuote('scale=trunc(iw/2)*2:trunc(ih/2)*2'), ...
    crf,shellQuote(outFile));
[status,text]=system(command);
encodeSeconds=toc(encodeTimer);
info=dir(outFile);
if status~=0 || isempty(info) || info.bytes==0
    error('TDP:ReplayExport','ffmpeg 编码失败（状态 %d）：%s',status,strtrim(text));
end

mapCsv=[outFile '.map.csv'];
mapJson=[outFile '.map.json'];
fid=fopen(mapCsv,'w');
assert(fid>=0,'TDP:ReplayExport','无法写入时间对照表 %s',mapCsv);
fprintf(fid,'video_frame,video_time_s,trace_row,sim_time_s\n');
for k=1:count
    fprintf(fid,'%d,%.6f,%d,%.6f\n',k,(k-1)/frameRate,rows(k),times(rows(k)));
end
fclose(fid);
speed=rec.Dt*stride*frameRate;
writeJson(mapJson,struct('source',rec.File,'sourceBytes',fileBytes(rec.File), ...
    'sourceSha256',fileSha256(rec.File),'video',outFile,'videoFrames',count, ...
    'videoFrameRate',frameRate,'videoSeconds',count/frameRate,'traceStepSeconds',rec.Dt, ...
    'stride',stride,'firstTraceRow',rows(1),'lastTraceRow',rows(end), ...
    'simStartSeconds',times(rows(1)),'simEndSeconds',times(rows(end)),'playbackSpeed',speed, ...
    'mapping','video_time = (k-1)/videoFrameRate ; sim_time = trace(row_k,61) ; row_k = firstTraceRow + (k-1)*stride', ...
    'perFrameTable',mapCsv,'hasTactics',rec.HasTactics, ...
    'renderSeconds',renderSeconds,'encodeSeconds',encodeSeconds));
result=struct('OutFile',outFile,'MappingCsv',mapCsv,'MappingJson',mapJson, ...
    'Frames',count,'Rows',rows,'SimStart',times(rows(1)),'SimEnd',times(rows(end)), ...
    'FrameRate',frameRate,'Stride',stride,'Speed',speed,'VideoSeconds',count/frameRate, ...
    'RenderSeconds',renderSeconds,'EncodeSeconds',encodeSeconds,'Bytes',info.bytes);
end

function checkScalar(value,name,allowInf)
ok=isnumeric(value) && isscalar(value) && isreal(value) && ~isnan(value);
if ~allowInf,ok=ok && isfinite(value);end
if ~ok,error('TDP:ReplayExport','%s 必须是标量数值。',name);end
end

function value=option(opts,name,default)
if isfield(opts,name),value=opts.(name);else,value=default;end
end

function removeWork(work,keep)
if ~keep && isfolder(work),rmdir(work,'s');end
end

function deleteFigure(fig)
if isgraphics(fig),delete(fig);end
end

function bytes=fileBytes(file)
info=dir(file);bytes=info.bytes;
end

function digest=fileSha256(file)
[status,text]=system(['sha256sum ' shellQuote(file)]);
digest='';
if status==0,digest=strtok(strtrim(text));end
end
