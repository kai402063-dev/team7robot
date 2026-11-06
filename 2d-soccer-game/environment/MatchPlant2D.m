function [next,feedback]=MatchPlant2D(world,requests,plans,tSim,P)
%MATCHPLANT2D Assign public role labels before physical execution/statistics.
for i=1:8,world.robots(i).role=plans(i).role;end
[next,feedback]=Plant2D(world,requests,tSim,P);
end
