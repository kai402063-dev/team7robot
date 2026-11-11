function viewer = replay_2d()
%REPLAY_2D Choose a saved match and watch its recorded frames.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'scripts'), fullfile(root,'algorithms'), ...
    fullfile(root,'interfaces'), fullfile(root,'environment'));
matches = listReplayMatches(fullfile(root,'build'));
viewer = [];

picker = figure('Name','TDP Football - 比赛回放','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Resize','off','Visible','off', ...
    'Position',[100 100 740 390],'Tag','TdpReplayPicker', ...
    'WindowKeyPressFcn',@keyPressed);
cleanup = onCleanup(@()closePicker(picker)); %#ok<NASGU>
movegui(picker,'center');
hint = '选择一场比赛，双击或点「播放」。最近的比赛排在最上方。';
if isempty(matches)
    hint = '还没有可回放的比赛。运行一场二维比赛，结束后再打开这里。';
end
list = uicontrol(picker,'Style','listbox','Units','normalized', ...
    'Position',[.035 .23 .93 .59],'FontSize',11,'String',{matches.label}, ...
    'Callback',@listClicked);
uicontrol(picker,'Style','text','Units','normalized', ...
    'Position',[.035 .86 .93 .08],'HorizontalAlignment','left', ...
    'FontSize',12,'String',hint);
feedback = uicontrol(picker,'Style','text','Units','normalized', ...
    'Position',[.035 .025 .55 .17],'HorizontalAlignment','left','String','');
play = uicontrol(picker,'Style','pushbutton','Units','normalized', ...
    'Position',[.61 .07 .16 .10],'String','播放','FontSize',12,'Callback',@openMatch);
uicontrol(picker,'Style','pushbutton','Units','normalized', ...
    'Position',[.80 .07 .16 .10],'String','关闭','FontSize',12, ...
    'Callback',@(~,~)delete(picker));
if isempty(matches)
    set([list,play],'Enable','off');
end
set(picker,'Visible','on');
uiwait(picker);

    function listClicked(~,~)
        if strcmp(get(picker,'SelectionType'),'open')
            openMatch();
        end
    end

    function keyPressed(~,event)
        switch event.Key
            case 'escape'
                delete(picker);
            case 'return'
                openMatch();
        end
    end

    function openMatch(~,~)
        if isempty(matches) || strcmp(get(play,'Enable'),'off')
            return
        end
        match = matches(get(list,'Value'));
        set(play,'Enable','off');
        set(picker,'Pointer','watch');
        set(feedback,'String','正在读取比赛记录…');
        drawnow nocallbacks
        try
            rec = loadReplayRecording(match.file);
            for note = rec.Warnings, warning('TDP:ReplayLoad','%s',note{1}); end
            viewer = MatchReplay2D(rec.P,rec.Trace,match.label,'on',rec.Tactics);
        catch problem
            if isgraphics(picker)
                set(feedback,'String',['无法播放这场比赛。' newline problem.message]);
                set(picker,'Pointer','arrow');
                set(play,'Enable','on');
            end
            return
        end
        closePicker(picker);
    end
end

function closePicker(picker)
if isgraphics(picker)
    delete(picker);
end
end
