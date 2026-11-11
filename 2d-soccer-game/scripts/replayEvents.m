function events=replayEvents(trace,tactics,opts)
%REPLAYEVENTS List transitions found in a recorded match, never re-simulating it.
%   events = replayEvents(trace)            % 98-column physical trace only
%   events = replayEvents(trace,tactics)    % plus the 171-column V1 tactics log
%   events = replayEvents(trace,tactics,opts)
%
% Every element has the fields
%   frame     row index into trace
%   time      trace(frame,61), simulation seconds
%   type      'goal' 'referee' 'kick' 'phase' 'chaser' 'takeover' 'recovering'
%             'gameRunning' 'intent' 'request' 'feedback' 'chaserStationary'
%   team      1 blue, 2 red, 0 not team-specific
%   robot     global robot id 1..8, 0 when no single robot applies
%   detail    short human-readable text
%   source    'recorded'  the logged value itself changed at this frame
%             'inferred'  derived by a stated rule from several logged values
%   evidence  the trace columns the event was read from
%
% 'recorded' marks a change of a logged field, not proof of cause: for example a
% phase change is logged, but WHY the team controller made it is not.
% Only the 'chaserStationary' type is inferred. Its rule: the authorised
% chaser's recorded world speed hypot(vxw,vyw) stays below opts.StationarySpeed
% (default 0.02 m/s) for at least opts.StationarySeconds (default 1 s) while
% the game is running.
if nargin<2,tactics=[];end
if nargin<3,opts=struct();end
speedLimit=option(opts,'StationarySpeed',0.02);
minSeconds=option(opts,'StationarySeconds',1.0);
assert(isnumeric(trace) && ismatrix(trace) && size(trace,2)==98 && size(trace,1)>=1, ...
    'TDP:ReplayEvents','trace must be N-by-98.');
c=replayColumns();
n=size(trace,1);
times=trace(:,c.time);
hasTactics=~isempty(tactics);
if hasTactics
    assert(isnumeric(tactics) && isequal(size(tactics),[n 171]), ...
        'TDP:ReplayEvents','tactics must be N-by-171 with the same row count as trace.');
    k=v1TraceColumns();
end
frames=zeros(0,1);types={};teams=zeros(0,1);robots=zeros(0,1);
details={};sources={};evidence={};

% ---- recorded: 98-column physical trace -------------------------------
for team=1:2
    score=trace(:,c.score(team));
    for r=changeRows(score)'
        add(r,'goal',team,0,sprintf('score of team %d: %g -> %g',team,score(r-1),score(r)), ...
            'recorded',sprintf('trace col %d (score)',c.score(team)));
    end
end
message=trace(:,c.msg);
for r=changeRows(message)'
    add(r,'referee',0,0,['referee message ' replayEnumName('TdpEvent',message(r))], ...
        'recorded',sprintf('trace col %d (msg, TdpEvent)',c.msg));
end
if hasTactics
    kicker=tactics(:,k.kicker);
    % One event per recorded step in which a kick was applied (a kick lasts one step).
    for r=find(kicker~=0)'
        add(r,'kick',teamOf(kicker(r)),kicker(r), ...
            sprintf('robot %d applied a kick to the ball',kicker(r)),'recorded', ...
            sprintf('tactics col %d (kicker)',k.kicker));
    end
else
    for r=find(trace(:,c.kicked)~=0)'
        add(r,'kick',0,0,'a kick was applied to the ball (robot unknown without tactics)', ...
            'recorded',sprintf('trace col %d (kicked)',c.kicked));
    end
end

% ---- recorded: tactical log --------------------------------------------
if hasTactics
    for team=1:2
        phase=tactics(:,k.phase(team));
        for r=changeRows(phase)'
            add(r,'phase',team,0,sprintf('team phase %s -> %s', ...
                replayEnumName('TdpTeamPhase',phase(r-1)),replayEnumName('TdpTeamPhase',phase(r))), ...
                'recorded',sprintf('tactics col %d (phase, TdpTeamPhase)',k.phase(team)));
        end
        chaser=tactics(:,k.chaser(team));
        for r=changeRows(chaser)'
            add(r,'chaser',team,chaser(r),sprintf('authorised chaser %d -> %d (0 = none)', ...
                chaser(r-1),chaser(r)),'recorded', ...
                sprintf('tactics col %d (chaser, global id)',k.chaser(team)));
        end
        for field={'takeover','recovering'}
            value=tactics(:,k.(field{1})(team));
            for r=changeRows(value)'
                add(r,field{1},team,0,sprintf('%s %g -> %g',field{1},value(r-1),value(r)), ...
                    'recorded',sprintf('tactics col %d (%s)',k.(field{1})(team),field{1}));
            end
        end
    end
    running=tactics(:,k.running);
    for r=changeRows(running)'
        add(r,'gameRunning',0,0,sprintf('gameRunning %g -> %g',running(r-1),running(r)), ...
            'recorded',sprintf('tactics col %d (running)',k.running));
    end
    for i=1:8
        intent=tactics(:,k.intent(i));
        for r=changeRows(intent)'
            add(r,'intent',teamOf(i),i,sprintf('intent %s -> %s; intent target (%.2f, %.2f)', ...
                replayEnumName('TdpAction',intent(r-1)),replayEnumName('TdpAction',intent(r)), ...
                tactics(r,k.targetX(i)),tactics(r,k.targetY(i))),'recorded', ...
                sprintf('tactics col %d (intent, TdpAction); target cols %d,%d',k.intent(i),k.targetX(i),k.targetY(i)));
        end
        kind=tactics(:,k.kind(i));
        id=tactics(:,k.requestId(i));
        onset=ismember(kind,[2 3 4]) & [true;(kind(2:end)~=kind(1:end-1)) | (id(2:end)~=id(1:end-1))];
        for r=find(onset)'
            add(r,'request',teamOf(i),i,sprintf('%s request id %g; intent target (%.2f, %.2f)', ...
                replayEnumName('TdpAction',kind(r)),id(r),tactics(r,k.targetX(i)),tactics(r,k.targetY(i))), ...
                'recorded',sprintf('tactics cols %d (kind), %d (requestId); target %d,%d are the INTENT target', ...
                k.kind(i),k.requestId(i),k.targetX(i),k.targetY(i)));
        end
        status=tactics(:,k.status(i));
        fid=tactics(:,k.feedbackId(i));
        fresh=[true;(status(2:end)~=status(1:end-1)) | (fid(2:end)~=fid(1:end-1))];
        for r=find(ismember(status,[2 3 4]) & fresh)'
            add(r,'feedback',teamOf(i),i,sprintf('feedback %s for request id %g', ...
                replayEnumName('TdpStatus',status(r)),fid(r)),'recorded', ...
                sprintf('tactics cols %d (status), %d (feedbackId)',k.status(i),k.feedbackId(i)));
        end
    end

    % ---- inferred: authorised chaser that is not moving -----------------
    for team=1:2
        chaser=tactics(:,k.chaser(team));
        moving=nan(n,1);
        for r=find(chaser>0)'
            moving(r)=hypot(trace(r,c.vxw(1)-1+chaser(r)),trace(r,c.vyw(1)-1+chaser(r)));
        end
        still=moving<speedLimit & running~=0;
        % A run continues only while the same robot stays chaser and stays still.
        link=[false;still(2:end) & still(1:end-1) & chaser(2:end)==chaser(1:end-1)];
        first=find(still & ~link);
        last=find(still & ~[link(2:end);false]);
        for q=1:numel(first)
            a=first(q);b=last(q);
            if times(b)-times(a)+median(diff(times))>=minSeconds
                robot=chaser(a);
                gap=hypot(trace(a,robot)-trace(a,c.ballX),trace(a,8+robot)-trace(a,c.ballY));
                add(a,'chaserStationary',team,robot,sprintf( ...
                    'authorised chaser %d below %.3g m/s from t=%.2f to t=%.2f s (%.2f s); ball %.2f m away at start', ...
                    robot,speedLimit,times(a),times(b),times(b)-times(a),gap),'inferred', ...
                    'trace cols vxw,vyw of the chaser + tactics chaser/running');
            end
        end
    end
end

% ---- assemble in time order -------------------------------------------
[~,order]=sortrows([frames (1:numel(frames))']);
if ~isempty(order)
    events=struct('frame',num2cell(frames(order)'),'time',num2cell(times(frames(order))'), ...
        'type',types(order)','team',num2cell(teams(order)'),'robot',num2cell(robots(order)'), ...
        'detail',details(order)','source',sources(order)','evidence',evidence(order)');
else
    events=struct('frame',{},'time',{},'type',{},'team',{},'robot',{},'detail',{}, ...
        'source',{},'evidence',{});
end

    function add(frame,type,team,robot,detail,source,where)
        frames(end+1,1)=frame; %#ok<AGROW>
        types{end+1,1}=type; %#ok<AGROW>
        teams(end+1,1)=team; %#ok<AGROW>
        robots(end+1,1)=robot; %#ok<AGROW>
        details{end+1,1}=detail; %#ok<AGROW>
        sources{end+1,1}=source; %#ok<AGROW>
        evidence{end+1,1}=where; %#ok<AGROW>
    end
end

function rows=changeRows(x)
% Row numbers r>=2 where x(r) differs from x(r-1).
rows=find(x(2:end)~=x(1:end-1))+1;
end

function team=teamOf(robot)
team=1+(robot>4);
end

function value=option(opts,name,default)
if isfield(opts,name),value=opts.(name);else,value=default;end
end
