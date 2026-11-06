function row=encodeTrace(robots,ball,state,mem,cmds,kicked)
%ENCODETRACE Stable numeric encoding; see docs/generated/trace_schema.json.
values=[[robots.x];[robots.y];[robots.th];[robots.vxw];[robots.vyw];[robots.cool]]';
roles=zeros(1,8);
for k=1:8
 if ischar(robots(k).role)
  roles(k)=find(strcmp(robots(k).role,{'GK','ST','DF','SP'}));
 else
  roles(k)=double(robots(k).role);
 end
end
if ischar(state.msg)
 msg=find(strcmp(state.msg,{'Kick-off','GOAL! Blue','GOAL! Red','Goal kick','Corner','Kick-in'}));
else,msg=double(state.msg);end
row=[values(:)' roles ball.x ball.y ball.vx ball.vy state.t state.score ...
 state.lastTouch state.pauseUntil state.shots state.touchTime state.msgUntil ...
 [mem.striker] cmds(:)' double(kicked) msg];
end
