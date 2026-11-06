function scenario=makeScenario(P,duration)
%MAKESCENARIO Fixed observation replay, independent of any plant state.
T=tdpTemplates(P);obs=T.Observation;obs.selfIndex=1;
obs.robots(1).x=-0.25;obs.robots(1).y=0;obs.robots(1).th=0;obs.robots(1).cool=0;
obs.robotValid(2:8)=false;
intent=T.Intent;intent.type=TdpAction.Kick;intent.target=[4.5 0];intent.speed=1.8;intent.role=TdpRole.ST;
row=struct('obs',obs,'intent',intent,'feedback',T.Feedback);
n=round(duration/P.dt)+1;scenario=repmat(row,1,n);
for k=1:n
 t=(k-1)*P.dt;scenario(k).obs.tSim=t;scenario(k).obs.ballStamp=t;scenario(k).obs.robotStamp(:)=t;
end
end
