function n=manualMeasurements()
%MANUALMEASUREMENTS Calculate every numeric teaching output from executable code.
P=tdp.defaultConfig();a=runA(1,0,P.dt);n=struct;
n.firstCommand=a.trace(1,76);n.firstRobot4X=a.robots(4).x;
b=struct('x',0,'y',0,'vx',1.8,'vy',0);for k=1:90,b=tdp.ballModel(b,P);end
n.rollingDistance=b.x;n.finalBallSpeed=hypot(b.vx,b.vy);
o=sim('tdpDelayLesson');n.delayLesson=o.records(:)';o=sim('tdpFlatLesson');n.flatPhases=o.records(:)';
P.mode=TdpMode.Delayed;n.replay=runReplay(P,makeScenario(P,2));n.replayColumns={'kind','requestId','phase','vx','vy','w','targetX','targetY','speed','stamp','validUntil'};
n.dt=P.dt;n.tapSpeed=P.tapSpeed;n.thresholdOld=P.kickRange;n.thresholdNew=.32;
end
