function [records,scenario]=sensorReplay(P,seed,duration)
%SENSORREPLAY Exercise the shared core through the delay/noise channel.
old=rng;c=onCleanup(@()rng(old));rng(seed,'twister');scenario=makeScenario(P,duration);
memory=ObservationHistory(P);
for k=1:numel(scenario)
 raw=scenario(k).obs;
 [memory,scenario(k).obs]=ObservationChannel(memory,raw,(k-1)*P.dt,P,randn(9,2));
end
records=runReplay(P,scenario);
end
