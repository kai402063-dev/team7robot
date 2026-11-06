function tests=test_original_handover
tests=functiontests(localfunctions);
end

function testHealthyReturnWhileMfPrepares(t)
for dt=[.05 .04]
    [P,w]=fixture(dt,3); P.kickPreparation=.80;
    P.v1UnavailableWindow(4,:)=[0 .20];
    P.v1RecoveryWindow(1,:)=[.75 P.Tmatch+dt];
    [~,q]=runModel(P,w); c=v1TraceColumns();
    first=find(q(:,c.status(3))==double(TdpStatus.Running),1);
    assertNotEmpty(t,first);
    id=q(first,c.requestId(3));
    kick=q(:,c.kicker)==3 & q(:,c.requestId(3))==id;
    fprintf('REPRO dt=%g first=%g request=%g actualMFkicks=%d\n',dt,q(first,c.time),id,nnz(kick));
    verifyEqual(t,nnz(kick),1,'A legal in-flight kick should finish before handback.');
end
end

function testReturnWithoutInFlightKick(t)
for dt=[.05 .04]
    [P,w]=fixture(dt,4);
    P.v1UnavailableWindow(4,:)=[0 .3];
    [~,q]=runModel(P,w); c=v1TraceColumns();
    later=q(:,c.time)>.92 & q(:,c.time)<1.15;
    fprintf('REPRO dt=%g owners after 0.92 s: %s\n',dt,mat2str(unique(q(later,c.chaser(1)))'));
    verifyEqual(t,unique(q(later,c.chaser(1))),4,'A healthy striker should regain eligibility automatically.');
end
end

function [P,world]=fixture(dt,robot)
P=tdp.v1Config();P.dt=dt;P.Tmatch=1.6;P.kickNoise=0;
T=tdpTemplates(P);world=T.World;
world.ball.x=2;world.ball.y=0;
world.robots(robot).x=world.ball.x-.245;world.robots(robot).y=0;world.robots(robot).th=0;
end

function [trace,tactics]=runModel(P,world)
[input,model]=matchSimulationInput(P);
input=input.setVariable('world0',world,'Workspace',model);
output=sim(input);trace=recordRows(output.records);tactics=recordRows(output.tacticsRecords);
end
