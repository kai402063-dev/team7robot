function player = MatchReplay2D(P,trace,displayName,visible,tactics)
%MATCHREPLAY2D Play recorded match samples in their original time order.
%   player = MatchReplay2D(P,trace,displayName,visible)
%   player = MatchReplay2D(P,trace,displayName,visible,tactics)
%
% trace    N-by-98 physical record (strictly increasing time in column 61)
% tactics  optional N-by-171 V1 tactics log; [] or omitted = not recorded
% Playback only shows recorded rows. It never reruns the simulator or the
% tactical controller, and it never writes to trace or tactics.
%
% The returned struct carries the figure and function handles that perform the
% same actions as the on-screen controls, so tests and the video exporter can
% drive the player without simulating mouse clicks:
%   Figure                the window
%   State()               struct Frame, Time, Playing, Rate, LastFrame
%   Pause() / Resume()    freeze / continue wall-clock playback
%   SeekFrame(f)          show row f (clamped to 1..N)
%   SeekTime(t)           show the latest recorded row with time <= t seconds
%   Step(n)               pause, then move n rows (negative = backwards)
%   SetRate(r)            r must be one of 0.25 0.5 1 2 4 8
%   Restart()             first row, playing
%   JumpToEvent(k)        pause and show the row of Events(k)
%   Events                struct array from replayEvents (see that file)
if nargin < 4, visible = 'on'; end
if nargin < 5, tactics = []; end
assert(isnumeric(trace) && isreal(trace) && ismatrix(trace) && ...
    ~isempty(trace) && size(trace,2) == 98 && all(isfinite(trace),'all'), ...
    'TDP:ReplayTrace','比赛轨迹需要包含 98 列有效数据。');
times = trace(:,61);
assert(all(diff(times) > 0),'TDP:ReplayTrace','比赛记录的时间必须逐帧递增。');
hasTactics = ~isempty(tactics);
if hasTactics
    assert(isnumeric(tactics) && isreal(tactics) && isequal(size(tactics),[size(trace,1) 171]) && ...
        all(isfinite(tactics),'all') && max(abs(tactics(:,1)-times)) <= 1e-9, ...
        'TDP:ReplayTactics','战术记录必须是与轨迹同行数、同时间的 N×171 有效数据。');
end
events = replayEvents(trace,tactics);
eventFrames = [events.frame];

pitch = LiveViewer2D(P,'off',1,trace(1,:));
fig = pitch.Figure;
frame = 1;
lastFrame = size(trace,1);
rates = [0.25 0.5 1 2 4 8];
rate = 1;
anchorTime = times(1);
wall = tic;
fixedFont = get(groot,'FixedWidthFontName');
bg = [.055 .085 .13]; fg = [.92 .95 .98];
infoBox = [];
eventList = [];
timeEdit = [];
player = struct('Figure',fig);

try
    clock = timer('Name','TDP match replay','ExecutionMode','fixedSpacing', ...
        'Period',0.04,'TimerFcn',@advance);
    set(fig,'Name',['TDP 足球回放 | ' char(displayName)], ...
        'DeleteFcn',@(~,~)releaseTimer(clock), ...
        'WindowKeyPressFcn',@figureKey);
    set(pitch.StartButton,'String','从头播放','Callback',@restart);
    set(pitch.PauseButton,'String','暂停','Enable','on','Callback',@togglePlayback);
    set(pitch.StopButton,'String','关闭','Enable','on','Callback',@(~,~)close(fig));
    set(pitch.SpeedControl,'String',{'0.25x','0.5x','1x','2x','4x','8x'}, ...
        'Value',3,'Callback',@changeSpeed);
    timeline = uicontrol(fig,'Style','slider','Units','normalized', ...
        'Position',[0.02 0.136 0.57 0.027],'Min',1,'Max',max(2,lastFrame), ...
        'SliderStep',min([1 100]/max(1,lastFrame-1),1),'Value',1, ...
        'TooltipString','拖动到比赛中的任意时刻','Callback',@seek);
    buildInspector();
    decorate();
    player = struct('Figure',fig,'State',@state,'Pause',@pausePlayback, ...
        'Resume',@resumePlayback,'SeekFrame',@seekFrame,'SeekTime',@seekTime, ...
        'Step',@stepFrames,'SetRate',@setRate,'Restart',@restartPlayback, ...
        'JumpToEvent',@jumpToEvent,'Events',events);
    set(fig,'Visible',visible);
    % The first paint of a visible window can take seconds. Finish it before the
    % wall clock starts, otherwise the first seconds of the recording are skipped.
    drawnow;
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

    function buildInspector()
        % Wider window: pitch on the left, recorded/decision/request/feedback
        % inspector and event list on the right. Existing controls are only moved.
        set(fig,'Position',[60 60 1600 800]);
        set(pitch.Axes,'Position',[.02 .17 .55 .68]);
        set(pitch.ScoreText,'Position',[.02 .91 .55 .06]);
        set(pitch.ClockText,'Position',[.02 .855 .55 .045]);
        set(pitch.StartButton,'Position',[.02 .075 .09 .055]);
        set(pitch.PauseButton,'Position',[.12 .075 .09 .055]);
        set(pitch.StopButton,'Position',[.22 .075 .09 .055]);
        set(findobj(fig,'Type','uicontrol','Style','text','String','Speed'), ...
            'Position',[.47 .08 .05 .035]);
        set(pitch.SpeedControl,'Position',[.52 .075 .07 .055]);
        uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.32 .075 .065 .055], ...
            'String','◀ 单帧','FontSize',11,'TooltipString','后退一帧（←）', ...
            'Callback',@(~,~)stepFrames(-1));
        uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.39 .075 .065 .055], ...
            'String','单帧 ▶','FontSize',11,'TooltipString','前进一帧（→）', ...
            'Callback',@(~,~)stepFrames(1));
        infoBox = uicontrol(fig,'Style','text','Units','normalized', ...
            'Position',[.585 .44 .405 .42],'HorizontalAlignment','left', ...
            'FontName',fixedFont,'FontSize',9,'BackgroundColor',bg,'ForegroundColor',fg);
        uicontrol(fig,'Style','text','Units','normalized','Position',[.585 .41 .405 .027], ...
            'HorizontalAlignment','left','FontSize',10,'BackgroundColor',bg, ...
            'ForegroundColor',[.66 .76 .86],'String', ...
            '事件列表  [R]=记录值发生变化   [I]=由规则推断（非直接记录）');
        labels = eventLabels(events);
        enabled = 'on';
        if isempty(labels), labels = {'（这份记录没有可列出的事件）'}; enabled = 'off'; end
        eventList = uicontrol(fig,'Style','listbox','Units','normalized', ...
            'Position',[.585 .17 .405 .235],'FontName',fixedFont,'FontSize',9, ...
            'String',labels,'Value',1,'Enable',enabled,'Callback',@pickEvent);
        uicontrol(fig,'Style','text','Units','normalized','Position',[.60 .082 .07 .035], ...
            'String','跳到 t(s)','FontSize',11,'BackgroundColor',bg,'ForegroundColor',fg);
        timeEdit = uicontrol(fig,'Style','edit','Units','normalized', ...
            'Position',[.675 .075 .08 .055],'FontSize',12,'String','', ...
            'TooltipString','输入仿真秒数，回车跳到不晚于该时刻的最近一帧','Callback',@seekFromEdit);
        uicontrol(fig,'Style','text','Units','normalized','Position',[.77 .075 .22 .055], ...
            'HorizontalAlignment','left','FontSize',9,'BackgroundColor',bg, ...
            'ForegroundColor',[.66 .76 .86],'String', ...
            '←/→ 单帧   空格 暂停/继续   [ ] 上/下一个事件');
    end

    function decorate()
        % Refresh the parts of the window that MatchReplay2D owns.
        t = times(frame);
        set(pitch.ClockText,'String',sprintf('%02d:%05.2f / %02d:%02d   |   帧 %d / %d   |   4 v 4', ...
            floor(t/60),mod(t,60),floor(P.Tmatch/60),round(mod(P.Tmatch,60)),frame,lastFrame));
        tacticsRow = [];
        if hasTactics, tacticsRow = tactics(frame,:); end
        set(infoBox,'String',replayInfoText(trace(frame,:),tacticsRow));
        if ~isempty(eventFrames)
            previous = find(eventFrames <= frame,1,'last');
            if ~isempty(previous)
                set(eventList,'Value',previous,'ListboxTop',max(1,previous-4));
            end
        end
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
            decorate();
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
            pausePlayback();
        else
            play();
        end
    end

    function pausePlayback()
        if strcmp(clock.Running,'on')
            anchorTime = playbackTime();
            show(find(times <= anchorTime,1,'last'));
        end
        holdPlayback();
    end

    function resumePlayback()
        if frame < lastFrame && strcmp(clock.Running,'off')
            anchorTime = times(frame);
            play();
        end
    end

    function changeSpeed(src,~)
        applyRate(rates(get(src,'Value')));
    end

    function setRate(newRate)
        index = find(rates == newRate,1);
        assert(isscalar(newRate) && ~isempty(index),'TDP:ReplayRate', ...
            '回放速度必须是 0.25、0.5、1、2、4、8 之一。');
        set(pitch.SpeedControl,'Value',index);
        applyRate(newRate);
    end

    function applyRate(newRate)
        if strcmp(clock.Running,'on')
            anchorTime = playbackTime();
            wall = tic;
        end
        rate = newRate;
    end

    function seek(src,~)
        seekFrame(round(get(src,'Value')));
    end

    function seekFrame(target)
        assert(isscalar(target) && isnumeric(target) && isfinite(target),'TDP:ReplaySeek', ...
            '帧号必须是有限数。');
        show(min(max(round(target),1),lastFrame));
        anchorTime = times(frame);
        wall = tic;
        if frame == lastFrame || strcmp(clock.Running,'off'), holdPlayback(); end
    end

    function seekTime(seconds)
        assert(isscalar(seconds) && isnumeric(seconds) && isreal(seconds) && isfinite(seconds), ...
            'TDP:ReplaySeek','时间必须是有限实数（秒）。');
        % Logged times are sums of dt, so 166.60 may be stored as 166.60000000000002.
        % A 1 microsecond tolerance keeps "seek to 166.60" from landing one row early.
        index = find(times <= seconds + 1e-6,1,'last');
        if isempty(index), index = 1; end
        seekFrame(index);
    end

    function seekFromEdit(src,~)
        seconds = str2double(get(src,'String'));
        if isnan(seconds)
            pitch.setStatus('请输入数字（仿真秒）。');
            return
        end
        seekTime(seconds);
    end

    function stepFrames(count)
        pausePlayback();
        show(min(max(frame + round(count),1),lastFrame));
        anchorTime = times(frame);
        holdPlayback();
    end

    function jumpToEvent(index)
        assert(isscalar(index) && index >= 1 && index <= numel(events) && index == round(index), ...
            'TDP:ReplaySeek','事件编号超出范围。');
        pausePlayback();
        show(events(index).frame);
        anchorTime = times(frame);
        holdPlayback();
    end

    function pickEvent(src,~)
        if ~isempty(events), jumpToEvent(get(src,'Value')); end
    end

    function figureKey(~,event)
        focus = get(fig,'CurrentObject');
        if ~isempty(focus) && isprop(focus,'Style') && strcmp(get(focus,'Style'),'edit')
            return   % typing a time into the edit box must not trigger shortcuts
        end
        switch event.Key
            case 'leftarrow',  stepFrames(-1);
            case 'rightarrow', stepFrames(1);
            case 'space',      togglePlayback();
            otherwise
                if isempty(events), return; end
                if strcmp(event.Character,']')
                    next = find(eventFrames > frame,1,'first');
                    if ~isempty(next), jumpToEvent(next); end
                elseif strcmp(event.Character,'[')
                    previous = find(eventFrames < frame,1,'last');
                    if ~isempty(previous), jumpToEvent(previous); end
                end
        end
    end

    function restart(~,~)
        restartPlayback();
    end

    function restartPlayback()
        show(1);
        anchorTime = times(1);
        if lastFrame > 1, play(); end
    end

    function s = state()
        s = struct('Frame',frame,'Time',times(frame), ...
            'Playing',strcmp(clock.Running,'on'),'Rate',rate,'LastFrame',lastFrame);
    end
end

function labels = eventLabels(events)
labels = cell(numel(events),1);
mark = struct('recorded','R','inferred','I');
for k = 1:numel(events)
    e = events(k);
    team = '-';
    if e.team > 0, team = num2str(e.team); end
    labels{k} = sprintf('%8.2fs [%s] T%s R%d %-10s %s',e.time,mark.(e.source),team,e.robot,e.type,e.detail);
end
end

function releaseTimer(clock)
if isvalid(clock)
    stop(clock);
    delete(clock);
end
end
