function [robots,ball,state]=randomizeInitial(P,noiseSample)
%RANDOMIZEINITIAL Perturb a fresh baseline, never a previously perturbed state.
[robots,ball,state]=tdp.initialState(P);
for i=1:8
 robots(i).x=robots(i).x+.05*noiseSample(i,1);
 robots(i).y=robots(i).y+.05*noiseSample(i,2);
 robots(i).th=tdp.angWrap(robots(i).th+.10*noiseSample(i,3));
end
ball.x=ball.x+.05*noiseSample(9,1);ball.y=ball.y+.05*noiseSample(9,2);
end
