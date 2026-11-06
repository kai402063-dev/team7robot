function [next,feedback,kicker]=V1Plant2D(world,requests,plans,tSim,P)
%V1PLANT2D Apply the V1 plan labels and explicit actuator failure windows.
fail=false(1,8);
for i=1:8
    world.robots(i).role=plans(i).role;
    fail(i)=tSim>=P.v1FailWindow(i,1) && tSim<P.v1FailWindow(i,2);
end
[next,feedback,kicker]=Plant2D(world,requests,tSim,P,fail);
% Physical removal also terminates an old preparation. Sensor-only loss goes
% through the normal Stop request while the physical robot remains present.
for i=1:8
    if ~world.active(i) && world.actuator(i).active
        memory=world.actuator(i);
        memory.active=false;
        memory.feedback.status=TdpStatus.Failed;
        memory.feedback.stamp=tSim;
        next.actuator(i)=memory;
        feedback(i)=memory.feedback;
    end
end
end
