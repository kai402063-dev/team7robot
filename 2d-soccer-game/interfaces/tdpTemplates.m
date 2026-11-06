function T=tdpTemplates(P)
%TDPTEMPLATES Canonical fixed-size bus values. No base-workspace access.
[r,b,s]=tdp.initialState(P);
T.Robot=r(1);T.Ball=b;T.Referee=s;
T.Intent=struct('type',TdpAction.Goto,'target',[0 0],'heading',0,'speed',0,'role',TdpRole.Unknown);
T.Feedback=struct('requestId',uint32(0),'status',TdpStatus.None,'stamp',0);
T.Request=struct('requestId',uint32(0),'kind',TdpAction.Stop,'velocity',[0 0 0], ...
 'target',[0 0],'speed',0,'stamp',0,'validUntil',0);
T.Observation=struct('selfIndex',1,'robots',r,'robotValid',true(1,8),'robotStamp',zeros(1,8), ...
 'ball',b,'ballValid',true,'ballStamp',0,'selfValid',true,'gameRunning',true,'allowKick',true,'tSim',0);
T.Geometry=struct('command',[0 0 0],'target',[0 0],'speed',0,'ready',false,'distance',0, ...
 'safe',false,'ballVisible',false,'running',false,'intent',TdpAction.Stop);
T.Actuator=struct('seenId',uint32(0),'rejectedId',uint32(0),'active',false,'start',0,'target',[0 0],'speed',0, ...
 'feedback',T.Feedback,'executions',uint32(0));
T.World=struct('robots',r,'ball',b,'referee',s,'actuator',repmat(T.Actuator,1,8), ...
 'active',true(1,8),'lastCommands',zeros(8,3),'lastKick',false,'kickCount',uint32(0));
end
