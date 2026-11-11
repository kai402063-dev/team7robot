function rec=loadReplayRecording(source)
%LOADREPLAYRECORDING Read and validate one saved match without altering it.
% source is a trace.mat path or a build/animation-* folder. The file is only
% opened for reading. rec fields:
%   File, P, Trace (N-by-98), Tactics (N-by-171, or [] when absent/unusable),
%   Times (N-by-1 seconds), Dt, HasTactics, Warnings (cellstr)
% A damaged or unusable file raises TDP:ReplayLoad with the reason.
file=char(source);
if isfolder(file),file=fullfile(file,'trace.mat');end
if ~isfile(file)
    error('TDP:ReplayLoad','找不到比赛记录文件：%s',file);
end
try
    info=whos('-file',file);
catch problem
    error('TDP:ReplayLoad','无法读取 MAT 文件 %s：%s',file,problem.message);
end
names={info.name};
for needed={'P','trace'}
    if ~ismember(needed{1},names)
        error('TDP:ReplayLoad','记录 %s 缺少变量 %s。',file,needed{1});
    end
end
wanted={'P','trace'};
if ismember('tactics',names),wanted{end+1}='tactics';end
try
    saved=load(file,wanted{:});
catch problem
    error('TDP:ReplayLoad','无法载入 %s：%s',file,problem.message);
end
trace=saved.trace;
if ~(isnumeric(trace) && isreal(trace) && ismatrix(trace) && size(trace,2)==98 && size(trace,1)>=1)
    error('TDP:ReplayLoad','%s 的 trace 必须是 N×98 的实数矩阵（N≥1）。',file);
end
if ~all(isfinite(trace),'all')
    error('TDP:ReplayLoad','%s 的 trace 含 NaN 或 Inf。',file);
end
c=replayColumns();
times=trace(:,c.time);
if any(diff(times)<=0)
    error('TDP:ReplayLoad','%s 的比赛时间不是逐帧严格递增。',file);
end
if ~(isstruct(saved.P) && isscalar(saved.P) && isfield(saved.P,'dt') && isfield(saved.P,'Tmatch'))
    error('TDP:ReplayLoad','%s 的参数 P 不完整（需要 dt 和 Tmatch）。',file);
end
rec=struct('File',file,'P',saved.P,'Trace',trace,'Tactics',[],'Times',times, ...
    'Dt',saved.P.dt,'HasTactics',false,'Warnings',{{}});
if isfield(saved,'tactics') && ~isempty(saved.tactics)
    k=saved.tactics;
    n=size(trace,1);
    if ~(isnumeric(k) && isreal(k) && isequal(size(k),[n 171]))
        rec.Warnings{end+1}=sprintf('tactics 尺寸 %s 与 trace 行数 %d 不匹配，战术信息已忽略。',mat2str(size(k)),n);
    elseif ~all(isfinite(k),'all')
        rec.Warnings{end+1}='tactics 含 NaN 或 Inf，战术信息已忽略。';
    elseif max(abs(k(:,1)-times))>1e-9
        rec.Warnings{end+1}='tactics 时间列与 trace 不一致，战术信息已忽略。';
    else
        rec.Tactics=k;rec.HasTactics=true;
    end
end
end
