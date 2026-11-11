function lines=replayInfoText(row,tacticsRow)
%REPLAYINFOTEXT Text block describing one recorded frame, grouped by information layer.
%   lines = replayInfoText(trace(f,:), tactics(f,:))   % V1 trace with tactics
%   lines = replayInfoText(trace(f,:), [])             % physical trace only
%
% Layers are kept apart on purpose:
%   recorded state : position and speed read from the 98-column physical trace
%   decision       : team phase, chaser, intent and its target (tactics log)
%   request        : the request actually issued after authorisation
%   feedback       : the executor's reported status for a request id
% Nothing here is inferred; every number is a logged value or a unit
% conversion of one (speed = hypot(vxw,vyw)).
c=replayColumns();
lines={};
if isempty(tacticsRow)
    lines{end+1}='Tactics log: NOT RECORDED in this file (physical state only)';
    lines{end+1}=sprintf('striker/chaser local id  blue %g  red %g   (trace cols 71-72)', ...
        row(c.striker(1)),row(c.striker(2)));
    lines{end+1}='';
    lines{end+1}='ID Role      x      y  speed';
    for i=1:8
        lines{end+1}=sprintf('%d  %-2s %7.2f%7.2f %5.2f',i,replayEnumName('TdpRole',row(c.role(i))), ...
            row(i),row(8+i),hypot(row(c.vxw(i)),row(c.vyw(i)))); %#ok<AGROW>
    end
    return
end
k=v1TraceColumns();
names={'BLUE','RED '};
for team=1:2
    lines{end+1}=sprintf('%s  phase %-8s chaser %d  takeover %g  recovering %g',names{team}, ...
        replayEnumName('TdpTeamPhase',tacticsRow(k.phase(team))),tacticsRow(k.chaser(team)), ...
        tacticsRow(k.takeover(team)),tacticsRow(k.recovering(team))); %#ok<AGROW>
end
lines{end+1}=sprintf('gameRunning %g   kicker (robot that kicked this step) %g', ...
    tacticsRow(k.running),tacticsRow(k.kicker));
lines{end+1}='';
lines{end+1}=sprintf('%-25s | %-29s| %-13s | %s','[recorded state]','[decision]','[request]','[feedback]');
lines{end+1}=sprintf('%-3s%-2s %7s%7s%5s | %-6s %-13s %-8s| %-6s %-6s | %-8s %-6s', ...
    'ID','Rl','x','y','v','intent','target','skill','kind','id','status','id');
for i=1:8
    lines{end+1}=sprintf('%d  %-2s %7.2f%7.2f%5.2f | %-6s (%5.1f,%5.1f) %-8s| %-6s #%-5d | %-8s #%-5d', ...
        i,replayEnumName('TdpRole',row(c.role(i))),row(i),row(8+i), ...
        hypot(row(c.vxw(i)),row(c.vyw(i))), ...
        replayEnumName('TdpAction',tacticsRow(k.intent(i))), ...
        tacticsRow(k.targetX(i)),tacticsRow(k.targetY(i)), ...
        replayEnumName('TdpPhase',tacticsRow(k.skill(i))), ...
        replayEnumName('TdpAction',tacticsRow(k.kind(i))),tacticsRow(k.requestId(i)), ...
        replayEnumName('TdpStatus',tacticsRow(k.status(i))),tacticsRow(k.feedbackId(i))); %#ok<AGROW>
end
lines{end+1}='';
lines{end+1}='v in m/s. Feedback may keep an old terminal status while a robot is idle.';
end
