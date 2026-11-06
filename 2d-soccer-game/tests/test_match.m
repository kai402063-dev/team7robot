function tests=test_match
tests=functiontests(localfunctions);
end
function testEquivalenceZeroNoise(t)
P=tdp.defaultConfig();P.Tmatch=10;P.kickNoise=0;
a=runA(1,0,10);b=runMatch(P);verifyEqual(t,b,a.trace,'AbsTol',1e-12);
end
function testEquivalenceFortyMilliseconds(t)
P=tdp.defaultConfig();P.Tmatch=10;P.dt=.04;P.kickNoise=0;
a=runA(1,0,10,.04);b=runMatch(P);verifyEqual(t,b,a.trace,'AbsTol',1e-12);
end
function testArbiterParity(t)
P=tdp.defaultConfig();T=tdpTemplates(P);w=T.World;
for i=1:8,w.robots(i).x=-.25;w.robots(i).y=0;w.robots(i).th=0;w.robots(i).cool=0;end
w.ball.x=0;w.ball.y=0;plans=repmat(T.Intent,1,8);
for i=1:8,plans(i).type=TdpAction.Kick;plans(i).target=[4.5 0];plans(i).speed=1.8;end
for step=1:2
 obs=repmat(Observation2D(w,1,step*P.dt,P),1,8);
 for i=1:8,obs(i).selfIndex=i;end
 obs=KickArbiter2D(obs,plans,step*P.dt,P);
 ready=false(1,8);for i=1:8,g=CoreGeometry(obs(i),plans(i),step*P.dt,P);ready(i)=g.ready;end
 verifyEqual(t,sum(ready),1);verifyTrue(t,ready(1+4*(step==2)));
end
end
function testMetricsDetectOverlap(t)
P=tdp.defaultConfig();a=runA(1,0,.1);a.trace(1,2)=a.trace(1,1);a.trace(1,10)=a.trace(1,9);
m=matchMetrics(a.trace,P);verifyGreaterThan(t,m.overlapSteps,0);verifyGreaterThan(t,m.maximumPenetrationMetres,.29);
end
