function row=V1TacticsRecord(blue,red,obs,plans,raw,requests,feedback,skill,next,kicker,P)
%V1TACTICSRECORD Observe plans, authorizations, terminal feedback and physics.
c=v1TraceColumns();
row=zeros(1,171);
t=obs(1).tSim;
row(c.time)=t;
row(c.phase)=[double(blue.phase) double(red.phase)];
row(c.basePhase)=[double(blue.basePhase) double(red.basePhase)];
row(c.chaser)=[blue.chaser red.chaser];
row(c.ballKnown)=[blue.ballKnown red.ballKnown];
row(c.ballSource)=[blue.ballSource red.ballSource];
row(c.failed)=[blue.failed red.failed];
row(c.running)=obs(1).gameRunning;
row(c.kicker)=kicker;
row(c.takeover)=[blue.takeover red.takeover];
row(c.recovering)=[blue.recovering red.recovering];
for i=1:8
    robot=obs(i).robots(i);
    ball=obs(i).ball;
    age=t-obs(i).ballStamp;
    selfAge=t-obs(i).robotStamp(i);
    row(c.available(i))=obs(i).selfValid && obs(i).robotValid(i) ...
        && isfinite(selfAge) && selfAge>=0 && selfAge<=P.maxObservationAge ...
        && isfinite(robot.x) && isfinite(robot.y) && isfinite(robot.th);
    row(c.ballFresh(i))=obs(i).ballValid && isfinite(age) && age>=0 && age<=P.maxObservationAge ...
        && isfinite(ball.x) && isfinite(ball.y) && isfinite(ball.vx) && isfinite(ball.vy);
    row(c.intent(i))=double(plans(i).type);
    row(c.rawKind(i))=double(raw(i).kind);
    row(c.kind(i))=double(requests(i).kind);
    row(c.requestId(i))=double(requests(i).requestId);
    row(c.status(i))=double(feedback(i).status);
    row(c.feedbackId(i))=double(feedback(i).requestId);
    row(c.skill(i))=double(skill(i));
    row(c.targetX(i))=plans(i).target(1);
    row(c.targetY(i))=plans(i).target(2);
    row(c.ballAge(i))=age;
    row(c.rawId(i))=double(raw(i).requestId);
    row(c.executions(i))=double(next.actuator(i).executions);
    row(c.feedbackStamp(i))=feedback(i).stamp;
    row(c.validUntil(i))=requests(i).validUntil;
    row(c.stamp(i))=requests(i).stamp;
    row(c.rawSpeed(i))=raw(i).speed;
    row(c.speed(i))=requests(i).speed;
end
end
