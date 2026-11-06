function player = MatchReplay2D(P,trace,displayName,visible)
%MATCHREPLAY2D Play recorded match samples in their original time order.
if nargin < 4, visible = 'on'; end
assert(isnumeric(trace) && isreal(trace) && ismatrix(trace) && ...
    ~isempty(trace) && size(trace,2) == 98 && all(isfinite(trace),'all'), ...
    'TDP:ReplayTrace','比赛轨迹需要包含 98 列有效数据。');
times = trace(:,61);
assert(all(diff(times) > 0),'TDP:ReplayTrace','比赛记录的时间必须逐帧递增。');

pitch = LiveViewer2D(P,'off',1,trace(1,:));
fig = pitch.Figure;
player = struct('Figure',fig);
frame = 1;
lastFrame = size(trace,1);
rates = [0.25 0.5 1 2 4 8];
rate = 1;
anchorTime = times(1);
wall = tic;

try
    clock = timer('Name','TDP match replay','ExecutionMode','fixedSpacing', ...
        'Period',0.04,'TimerFcn',@advance);
    set(fig,'Name',['TDP 足球回放 | ' char(displayName)], ...
        'DeleteFcn',@(~,~)releaseTimer(clock));
    set(pitch.StartButton,'String','从头播放','Callback',@restart);
    set(pitch.PauseButton,'String','暂停','Enable','on','Callback',@togglePlayback);
    set(pitch.StopButton,'String','关闭','Enable','on','Callback',@(~,~)close(fig));
    set(pitch.SpeedControl,'String',{'0.25x','0.5x','1x','2x','4x','8x'}, ...
        'Value',3,'Callback',@changeSpeed);
    timeline = uicontrol(fig,'Style','slider','Units','normalized', ...
        'Position',[0.08 0.136 0.82 0.027],'Min',1,'Max',max(2,lastFrame), ...
        'SliderStep',min([1 100]/max(1,lastFrame-1),1),'Value',1, ...
        'TooltipString','拖动到比赛中的任意时刻','Callback',@seek);
    set(fig,'Visible',visible);
    if lastFrame == 1
        set(timeline,'Enable','off');
        holdPlayback();
    else
        play();
    end
catch err
    if isgraphics(fig), delete(fig); end
    rethrow(err)
end

    function play()
        wall = tic;
        set(pitch.PauseButton,'String','暂停','Enable','on');
        pitch.setStatus('正在回放');
        if strcmp(clock.Running,'off'), start(clock); end
    end

    function holdPlayback()
        if strcmp(clock.Running,'on'), stop(clock); end
        if frame == lastFrame
            set(pitch.PauseButton,'String','继续','Enable','off');
            pitch.setStatus('回放结束');
        else
            set(pitch.PauseButton,'String','继续','Enable','on');
            pitch.setStatus('已暂停');
        end
    end

    function show(index)
        if index ~= frame
            frame = index;
            pitch.showFrame(trace(frame,:),true);
        end
        set(timeline,'Value',frame);
    end

    function t = playbackTime()
        t = min(times(end),anchorTime + toc(wall)*rate);
    end

    function advance(~,~)
        if ~isgraphics(fig) || strcmp(clock.Running,'off'), return; end
        t = playbackTime();
        show(find(times <= t,1,'last'));
        if frame == lastFrame, holdPlayback(); end
    end

    function togglePlayback(~,~)
        if strcmp(clock.Running,'on')
            anchorTime = playbackTime();
            show(find(times <= anchorTime,1,'last'));
            holdPlayback();
        else
            play();
        end
    end

    function changeSpeed(src,~)
        if strcmp(clock.Running,'on')
            anchorTime = playbackTime();
            wall = tic;
        end
        rate = rates(get(src,'Value'));
    end

    function seek(src,~)
        show(round(get(src,'Value')));
        anchorTime = times(frame);
        wall = tic;
        if frame == lastFrame || strcmp(clock.Running,'off'), holdPlayback(); end
    end

    function restart(~,~)
        show(1);
        anchorTime = times(1);
        if lastFrame > 1, play(); end
    end
end

function releaseTimer(clock)
if isvalid(clock)
    stop(clock);
    delete(clock);
end
end
