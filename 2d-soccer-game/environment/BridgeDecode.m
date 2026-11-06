function [obs,intent,fb,tSim,quality,held]=BridgeDecode(frame,previous,P)
%BRIDGEDECODE Decode protocol v1 using acquisition time, sequence and /clock.
% Frame: version,time,selfStamp,x,y,yaw,selfValid,bx,by,bvx,bvy,
% ballValid,ballStamp,playing,feedbackId,status,feedbackStamp,z,bz,sequence.
[robots,ball]=tdp.initialState(P);
obs=struct('selfIndex',1,'robots',robots,'robotValid',false(1,8),'robotStamp',zeros(1,8), ...
 'ball',ball,'ballValid',false,'ballStamp',0,'selfValid',false,'gameRunning',false,'allowKick',true,'tSim',0);
intent=struct('type',TdpAction.Kick,'target',[0 0],'heading',0,'speed',0,'role',TdpRole.ST);
fb=struct('requestId',uint32(0),'status',TdpStatus.None,'stamp',0);
tSim=frame(2);held=previous;isNew=false;
clockOK=isfinite(tSim)&&tSim>=0&&tSim>=previous(2);
packetOK=frame(1)==1&&all(isfinite(frame))&&frame(20)>=1&& ...
 frame(20)<=double(intmax('uint32'))&&frame(20)==floor(frame(20));
if clockOK&&packetOK&&frame(20)>previous(20)
 held=frame;isNew=true;
end
% A duplicate or late packet never refreshes an acquisition timestamp.
held(2)=tSim;age=tSim-held(3);ballAge=tSim-held(13);
selfFresh=clockOK&&held(1)==1&&held(7)==1&&isfinite(age)&&age>=0&&age<=P.maxObservationAge;
ballFresh=clockOK&&held(1)==1&&held(12)==1&&isfinite(ballAge)&&ballAge>=0&&ballAge<=P.maxObservationAge;
obs.selfIndex=1;obs.robotValid=false(1,8);obs.robotStamp=zeros(1,8);
obs.robots(1).x=held(4);obs.robots(1).y=held(5);obs.robots(1).th=held(6);
obs.robots(1).isGK=false;obs.robots(1).role=TdpRole.ST;obs.robots(1).cool=0;
obs.robotValid(1)=selfFresh;obs.robotStamp(1)=held(3);obs.selfValid=selfFresh;
obs.ball.x=held(8);obs.ball.y=held(9);obs.ball.vx=held(10);obs.ball.vy=held(11);
obs.ballValid=ballFresh;obs.ballStamp=held(13);obs.gameRunning=held(14)==1&&clockOK;
obs.allowKick=true;obs.tSim=tSim;
intent.type=TdpAction.Kick;intent.target=[P.L/2 0];intent.speed=P.shotSpeed;intent.role=TdpRole.ST;
if held(15)>=0&&held(15)<=double(intmax('uint32'))&&held(15)==floor(held(15))&& ...
 held(16)>=0&&held(16)<=4&&held(16)==floor(held(16))&& ...
 held(17)<=tSim&&tSim-held(17)<=P.kickTimeout
 fb.requestId=uint32(held(15));fb.status=TdpStatus(held(16));fb.stamp=held(17);
end
quality=[double(isNew) age double(~selfFresh) ballAge double(~ballFresh) double(clockOK)];
end
