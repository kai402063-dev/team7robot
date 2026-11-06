function observations=V1Observation2D(world,tSim,P)
%V1OBSERVATION2D Apply reproducible sensor and availability scenarios.
observations=repmat(Observation2D(world,1,tSim,P),1,8);
available=world.active;
for i=1:8
    available(i)=available(i) && ~inside(tSim,P.v1UnavailableWindow(i,:));
end
for i=1:8
    obs=Observation2D(world,i,tSim,P);
    obs.robotValid=available;
    obs.selfValid=available(i);
    obs.gameRunning=obs.gameRunning && ~inside(tSim,P.v1StopWindow);
    if inside(tSim,P.v1BlindWindow(i,:))
        obs.ballValid=false;
    end
    if inside(tSim,P.v1StaleWindow(i,:))
        obs.ballStamp=tSim-P.maxObservationAge-P.dt;
    end
    payloadFinite=all(isfinite([obs.ball.x obs.ball.y obs.ball.vx obs.ball.vy]));
    obs.ballValid=obs.ballValid && payloadFinite;
    age=tSim-obs.ballStamp;
    if ~obs.ballValid || ~isfinite(age) || age<0 || age>P.maxObservationAge
        % Discard hidden coordinates at the sensor boundary. The self-relative
        % placeholder gives the shared Core zero distance even in diagnostics.
        obs.ball.x=obs.robots(i).x;
        obs.ball.y=obs.robots(i).y;
        obs.ball.vx=0;
        obs.ball.vy=0;
    end
    observations(i)=obs;
end
end

function yes=inside(t,window)
yes=t>=window(1) && t<window(2);
end
