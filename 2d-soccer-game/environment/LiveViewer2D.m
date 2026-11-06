classdef LiveViewer2D < handle
    %LIVEVIEWER2D Read-only pitch display and wall-clock playback controls.
    % Simulation time and all physical state remain owned by Simulink.
    properties (SetAccess=private)
        Figure
        Axes
        Bodies
        Headings
        Labels
        Ball
        ClockText
        ScoreText
        StatusText
        StartButton
        PauseButton
        StopButton
        SpeedControl
        Parameters
        Speed = 1
        PauseRequested = false
        Paused = false
        StopRequested = false
        Closing = false
        Running = false
        LastRow = zeros(1,98)
        FrameCount = 0
        Trace = zeros(0,98)
        LastError = []
        RunDirectory = ''
        InitializationSeconds = NaN
        RunSeconds = NaN
        Events = struct('event',{},'simulationTime',{},'speed',{})
    end
    properties (Access=private)
        Circle
        TeamV1 = false
        WallTimer
        InitializationTimer
        PauseRequestTimer
        LastPaintWall = -Inf
        Speeds = [0.25 0.5 1 2 4 8 Inf]
    end
    methods
        function obj=LiveViewer2D(P,visible,speed,initialRow)
            if nargin<2,visible='on';end
            if nargin<3,speed=1;end
            assert(isscalar(speed) && isnumeric(speed) && isreal(speed) && speed>0,'TDP:AnimationSpeed','Speed must be positive.');
            tdp.validateConfig(P);obj.Parameters=P;
            obj.TeamV1=isfield(P,'v1Enabled') && P.v1Enabled;
            steps=P.Tmatch/P.dt;
            assert(isscalar(steps) && steps>=1 && abs(steps-round(steps))<1e-9, ...
                'TDP:AnimationDuration','Duration must be a positive multiple of the control period.');
            bg=[.055 .085 .13];fg=[.92 .95 .98];obj.Circle=linspace(0,2*pi,49);
            obj.Figure=figure('Name','TDP Football - Live 2D','NumberTitle','off', ...
                'Color',bg,'MenuBar','none','ToolBar','none','Visible',visible, ...
                'Position',[90 80 1120 800],'CloseRequestFcn',@(~,~)obj.close());
            obj.Axes=axes(obj.Figure,'Units','normalized','Position',[.045 .17 .91 .68]);
            obj.drawPitch(P);hold(obj.Axes,'on');
            obj.Bodies=gobjects(1,8);obj.Headings=gobjects(1,8);obj.Labels=gobjects(1,8);
            for i=1:8
                color=[.12 .47 1];if i>4,color=[1 .27 .31];end
                obj.Bodies(i)=fill(obj.Axes,P.robotR*cos(obj.Circle),P.robotR*sin(obj.Circle),color, ...
                    'EdgeColor',[.95 .97 1],'LineWidth',1.2);
                obj.Headings(i)=plot(obj.Axes,[0 .24],[0 0],'-','Color',[.06 .09 .13],'LineWidth',2);
                obj.Labels(i)=text(obj.Axes,0,0,num2str(i),'Color','w','FontWeight','bold', ...
                    'FontSize',10,'HorizontalAlignment','center','VerticalAlignment','middle');
            end
            obj.Ball=fill(obj.Axes,P.ballR*cos(obj.Circle),P.ballR*sin(obj.Circle),'w', ...
                'EdgeColor',[.06 .08 .1],'LineWidth',1.7);
            obj.ScoreText=uicontrol(obj.Figure,'Style','text','Units','normalized', ...
                'Position',[.08 .91 .84 .06],'BackgroundColor',bg,'ForegroundColor',fg, ...
                'FontSize',24,'FontWeight','bold','String','BLUE  0 : 0  RED');
            obj.ClockText=uicontrol(obj.Figure,'Style','text','Units','normalized', ...
                'Position',[.25 .855 .5 .045],'BackgroundColor',bg,'ForegroundColor',[.66 .76 .86], ...
                'FontSize',14,'String','00:00.0');
            obj.StartButton=uicontrol(obj.Figure,'Style','pushbutton','Units','normalized', ...
                'Position',[.08 .075 .15 .055],'String','Restart','FontSize',12, ...
                'Callback',@(~,~)obj.start(),'Interruptible','on','BusyAction','cancel');
            obj.PauseButton=uicontrol(obj.Figure,'Style','pushbutton','Units','normalized', ...
                'Position',[.25 .075 .15 .055],'String','Pause','FontSize',12, ...
                'Enable','off','Callback',@(~,~)obj.togglePause());
            obj.StopButton=uicontrol(obj.Figure,'Style','pushbutton','Units','normalized', ...
                'Position',[.42 .075 .15 .055],'String','Stop','FontSize',12, ...
                'Enable','off','Callback',@(~,~)obj.stop());
            uicontrol(obj.Figure,'Style','text','Units','normalized','Position',[.62 .08 .12 .035], ...
                'String','Speed','FontSize',12,'BackgroundColor',bg,'ForegroundColor',fg);
            obj.SpeedControl=uicontrol(obj.Figure,'Style','popupmenu','Units','normalized', ...
                'Position',[.75 .075 .15 .055],'FontSize',12, ...
                'String',{'0.25x','0.5x','1x','2x','4x','8x','Max'},'Value',3, ...
                'Callback',@(src,~)obj.setSpeed(obj.Speeds(get(src,'Value'))));
            obj.StatusText=uicontrol(obj.Figure,'Style','text','Units','normalized', ...
                'Position',[.04 .015 .92 .045],'String','Ready','FontSize',10, ...
                'BackgroundColor',bg,'ForegroundColor',[.66 .76 .86]);
            obj.setSpeed(speed);
            if nargin<4
                T=tdpTemplates(P);initialRow=MatchRecord(T.World,0,0);
            end
            obj.showFrame(initialRow,true);
            obj.FrameCount=0;obj.Events=struct('event',{},'simulationTime',{},'speed',{});
        end

        function start(obj)
            if obj.Running || obj.Closing || ~isgraphics(obj.Figure),return;end
            root=fileparts(fileparts(mfilename('fullpath')));
            base=fullfile(root,'build',['animation-' char(datetime('now','Format','yyyyMMdd-HHmmss-SSS'))]);
            obj.RunDirectory=base;suffix=0;
            while isfolder(obj.RunDirectory)
                suffix=suffix+1;obj.RunDirectory=sprintf('%s-%d',base,suffix);
            end
            mkdir(obj.RunDirectory);P=obj.Parameters;obj.LastError=[];trace=zeros(0,98);tactics=zeros(0,0);recovery=zeros(0,0);
            try
                [trace,tactics,recovery]=runAnimatedMatch(P,obj);
                obj.Trace=trace;status='COMPLETED';
                if obj.StopRequested,status='STOPPED_BY_USER';end
                metrics=[];if ~isempty(trace),metrics=matchMetrics(trace,P);end
                receipt=struct('status',status,'frames',size(trace,1),'metrics',metrics, ...
                    'parameters',P,'events',obj.Events,'simulationMode','normal', ...
                    'initializationSeconds',obj.InitializationSeconds,'runSeconds',obj.RunSeconds, ...
                    'displayOnly',true,'wallClockUse','Pacing only; never controller or physics time');
            catch e
                obj.LastError=e;obj.Running=false;
                receipt=struct('status','FAIL','error',getReport(e,'extended','hyperlinks','off'));
                obj.setStatus(['Simulation failed: ' e.message]);
                warning('TDP:AnimationRun','%s',receipt.error);
            end
            save(fullfile(obj.RunDirectory,'trace.mat'),'trace','tactics','P');
            if ~isempty(recovery)
                save(fullfile(obj.RunDirectory,'trace.mat'),'recovery','-append');
            end
            writeJson(fullfile(obj.RunDirectory,'receipt.json'),receipt);
            fprintf('TDP animation: %s\n',fullfile(obj.RunDirectory,'receipt.json'));
            if obj.Closing
                if isgraphics(obj.Figure),delete(obj.Figure);end
            elseif isgraphics(obj.Figure)
                set(obj.StartButton,'Enable','on');set(obj.PauseButton,'Enable','off');set(obj.StopButton,'Enable','off');
                if isempty(obj.LastError),obj.setStatus([status ' | Results: ' obj.RunDirectory]);end
            end
        end

        function beginRun(obj)
            obj.Running=true;obj.PauseRequested=false;obj.Paused=false;obj.StopRequested=false;
            obj.FrameCount=0;obj.Trace=zeros(0,98);obj.LastError=[];
            obj.WallTimer=[];obj.InitializationTimer=tic;
            obj.InitializationSeconds=NaN;obj.RunSeconds=NaN;
            obj.Events=struct('event',{},'simulationTime',{},'speed',{});
            T=tdpTemplates(obj.Parameters);obj.showFrame(MatchRecord(T.World,0,0),true);obj.FrameCount=0;
            obj.setStatus('Compiling model... first run can take a moment.');
            set(obj.StartButton,'Enable','off');set(obj.PauseButton,'Enable','off','String','Pause');
            set(obj.StopButton,'Enable','on');drawnow;
        end

        function ready(obj)
            obj.InitializationSeconds=toc(obj.InitializationTimer);
            obj.WallTimer=tic;obj.LastPaintWall=-Inf;
            if isgraphics(obj.Figure),set(obj.PauseButton,'Enable','on');end
            obj.runningStatus();
            obj.addEvent('started');
        end

        function showFrame(obj,row,force)
            if nargin<3,force=false;end
            row=reshape(row,1,[]);
            assert(numel(row)==98 && all(isfinite(row)),'TDP:AnimationFrame','Expected one finite 98-column record.');
            obj.LastRow=row;obj.FrameCount=obj.FrameCount+1;
            if ~isgraphics(obj.Figure),return;end
            wall=0;if ~isempty(obj.WallTimer),wall=toc(obj.WallTimer);end
            if ~force && wall-obj.LastPaintWall<1/30,return;end
            obj.LastPaintWall=wall;
            obj.refreshDisplay();
        end

        function refreshDisplay(obj)
            % Paint the latest observed sample without counting it a second time.
            if ~isgraphics(obj.Figure),return;end
            row=obj.LastRow;P=obj.Parameters;
            for i=1:8
                set(obj.Bodies(i),'XData',row(i)+P.robotR*cos(obj.Circle),'YData',row(i+8)+P.robotR*sin(obj.Circle));
                set(obj.Headings(i),'XData',row(i)+[0 .24*cos(row(i+16))],'YData',row(i+8)+[0 .24*sin(row(i+16))]);
                set(obj.Labels(i),'Position',[row(i) row(i+8) 0]);
                if obj.TeamV1
                    team=1+(i>4);
                    localNumber=mod(i-1,4)+1;
                    if row(70+team)==localNumber
                        set(obj.Bodies(i),'EdgeColor',[1 .82 .24],'LineWidth',2.7);
                    else
                        set(obj.Bodies(i),'EdgeColor',[.95 .97 1],'LineWidth',1.2);
                    end
                end
            end
            set(obj.Ball,'XData',row(57)+P.ballR*cos(obj.Circle),'YData',row(58)+P.ballR*sin(obj.Circle));
            set(obj.ScoreText,'String',sprintf('BLUE  %d : %d  RED',row(62),row(63)));
            set(obj.ClockText,'String',sprintf('%02d:%04.1f / %02d:%02d   |   4 v 4', ...
                floor(row(61)/60),mod(row(61),60),floor(P.Tmatch/60),round(mod(P.Tmatch,60))));
        end

        function togglePause(obj)
            if ~obj.Running || obj.StopRequested || isempty(obj.WallTimer) || obj.PauseRequested~=obj.Paused,return;end
            obj.PauseRequested=~obj.Paused;obj.PauseRequestTimer=tic;
            set(obj.PauseButton,'Enable','off');
            if obj.PauseRequested
                obj.setStatus('Pausing...');obj.addEvent('pauseRequested');
            else
                obj.setStatus('Resuming...');obj.addEvent('resumeRequested');
            end
        end

        function confirmPauseState(obj,paused)
            % The simulation driver calls this only after observing its new status.
            if ~obj.Running || obj.StopRequested || obj.PauseRequested~=paused || obj.Paused==paused,return;end
            obj.Paused=paused;
            if paused
                obj.refreshDisplay();
                set(obj.PauseButton,'String','Resume','Enable','on');
                obj.setStatus('Paused | Simulation time is frozen');obj.addEvent('paused');
            else
                set(obj.PauseButton,'String','Pause','Enable','on');
                obj.runningStatus();obj.addEvent('resumed');
            end
        end

        function checkPauseTimeout(obj,seconds)
            if obj.PauseRequested~=obj.Paused && toc(obj.PauseRequestTimer)>seconds
                error('TDP:AnimationControlTimeout','Simulator did not confirm the playback request within %g seconds.',seconds);
            end
        end

        function setSpeed(obj,speed)
            assert(isscalar(speed) && isnumeric(speed) && isreal(speed) && speed>0,'TDP:AnimationSpeed','Speed must be positive.');
            obj.Speed=speed;
            index=find(obj.Speeds==speed,1);
            if isempty(index)
                obj.Speeds(end+1)=speed;index=numel(obj.Speeds);
                labels=get(obj.SpeedControl,'String');labels{end+1}=sprintf('%gx',speed);
                set(obj.SpeedControl,'String',labels);
            end
            if isgraphics(obj.SpeedControl),set(obj.SpeedControl,'Value',index);end
            if obj.Running,obj.addEvent('speed');end
        end

        function stop(obj)
            if ~obj.Running,return;end
            obj.StopRequested=true;obj.PauseRequested=false;obj.Paused=false;obj.addEvent('stopped');obj.setStatus('Stopping...');
        end

        function close(obj)
            obj.Closing=true;obj.stop();
            if isgraphics(obj.Figure)
                if obj.Running,set(obj.Figure,'Visible','off');else,delete(obj.Figure);end
            end
        end

        function finishRun(obj,trace)
            if ~isempty(obj.WallTimer),obj.RunSeconds=toc(obj.WallTimer);end
            obj.Trace=trace;obj.Running=false;obj.PauseRequested=false;obj.Paused=false;
            if ~isempty(trace),obj.showFrame(trace(end,:),true);obj.FrameCount=size(trace,1);end
            if isgraphics(obj.Figure)
                set(obj.StartButton,'Enable','on');set(obj.PauseButton,'Enable','off');set(obj.StopButton,'Enable','off');
            end
        end

        function setStatus(obj,message)
            if isgraphics(obj.StatusText),set(obj.StatusText,'String',message);end
        end
    end
    methods (Access=private)
        function runningStatus(obj)
            if isfield(obj.Parameters,'v1AutoRecoveryTeams')
                names={'V1','Auto'};
                labels=names(1+double(obj.Parameters.v1AutoRecoveryTeams));
                obj.setStatus(sprintf('Team comparison | Blue: %s  Red: %s | Gold ring: primary chaser',labels{:}));
            elseif isfield(obj.Parameters,'v1AutoRecovery') && obj.Parameters.v1AutoRecovery
                obj.setStatus('Automatic recovery experiment | GK 1/5  DF 2/6  MF 3/7  ST 4/8 | Gold ring: primary chaser');
            elseif obj.TeamV1
                obj.setStatus('Team V1  |  GK 1/5   DF 2/6   MF 3/7   ST 4/8  |  Gold ring: primary chaser');
            else
                obj.setStatus('Running | Blue attacks right, red attacks left');
            end
        end
        function addEvent(obj,name)
            label=sprintf('%gx',obj.Speed);if isinf(obj.Speed),label='Max';end
            obj.Events(end+1)=struct('event',name,'simulationTime',obj.LastRow(61),'speed',label);
        end
        function drawPitch(obj,P)
            ax=obj.Axes;hold(ax,'on');axis(ax,'equal');axis(ax,'off');
            xlim(ax,[-P.L/2-P.border P.L/2+P.border]);ylim(ax,[-P.W/2-.45 P.W/2+.45]);
            rectangle(ax,'Position',[-P.L/2-P.border -P.W/2-.45 P.L+2*P.border P.W+.9], ...
                'FaceColor',[.075 .23 .18],'EdgeColor','none');
            for k=0:5
                color=[.12 .39 .27]+mod(k,2)*.025;
                rectangle(ax,'Position',[-P.L/2+k*P.L/6 -P.W/2 P.L/6 P.W], ...
                    'FaceColor',color,'EdgeColor','none');
            end
            rectangle(ax,'Position',[-P.L/2 -P.W/2 P.L P.W],'EdgeColor','w','LineWidth',1.3);
            plot(ax,[0 0],[-P.W/2 P.W/2],'w-','LineWidth',1.1);
            plot(ax,P.centreD/2*cos(obj.Circle),P.centreD/2*sin(obj.Circle),'w-','LineWidth',1.1);
            plot(ax,0,0,'w.','MarkerSize',10);
            for side=[-1 1]
                x=side*P.L/2;left=x;if side>0,left=x-P.penAreaL;end
                rectangle(ax,'Position',[left -P.penAreaW/2 P.penAreaL P.penAreaW],'EdgeColor',[.8 .9 .86]);
                left=x;if side>0,left=x-P.goalAreaL;end
                rectangle(ax,'Position',[left -P.goalAreaW/2 P.goalAreaL P.goalAreaW],'EdgeColor','w');
                plot(ax,side*(P.L/2-P.penMark),0,'w.','MarkerSize',10);
                left=x-P.goalD;if side>0,left=x;end
                color=[.25 .57 1];if side>0,color=[1 .4 .43];end
                rectangle(ax,'Position',[left -P.goalW/2 P.goalD P.goalW],'EdgeColor',color,'LineWidth',2);
            end
        end
    end
end
