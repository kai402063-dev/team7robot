function [memory,obs]=ObservationChannel(memory,raw,tSim,P,noiseSample)
%OBSERVATIONCHANNEL Replay adapter for fixed observation delay and position noise.
% noiseSample is a fixed 9-by-2 array; row 9 is the ball sample.
steps=round(P.observationDelay/P.dt);
assert(steps>=0 && steps<=20 && abs(steps*P.dt-P.observationDelay)<1e-10,'TDP:ObservationDelay','Delay must be 0 to 20 integral samples.');
measured=raw;
for i=1:8
 measured.robots(i).x=raw.robots(i).x+P.observationNoise*noiseSample(i,1);
 measured.robots(i).y=raw.robots(i).y+P.observationNoise*noiseSample(i,2);
end
measured.ball.x=raw.ball.x+P.observationNoise*noiseSample(9,1);
measured.ball.y=raw.ball.y+P.observationNoise*noiseSample(9,2);
for i=21:-1:2,memory(i)=memory(i-1);end
memory(1)=measured;obs=memory(steps+1);
% Referee permission and evaluation time are current; sensor stamps stay old.
obs.gameRunning=raw.gameRunning;obs.allowKick=raw.allowKick;obs.tSim=tSim;
end
