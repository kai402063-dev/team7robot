function tests=test_source_defects
tests=functiontests(localfunctions);
end
function testACoincidentCenters(t)
P=tdp.defaultConfig();[r,b,s]=tdp.initialState(P);r(2).x=r(1).x;r(2).y=r(1).y;
[r,~,~]=tdp.collisions(r,b,s,false,P);
verifyEqual(t,hypot(r(1).x-r(2).x,r(1).y-r(2).y),0);
end
function testAOnePassLeavesOverlap(t)
P=tdp.defaultConfig();[r,b,s]=tdp.initialState(P);
for i=1:3,r(i).x=.1*(i-1);r(i).y=0;end
[r,~,~]=tdp.collisions(r,b,s,false,P);
d=[hypot(r(1).x-r(2).x,r(1).y-r(2).y),hypot(r(1).x-r(3).x,r(1).y-r(3).y),hypot(r(2).x-r(3).x,r(2).y-r(3).y)];
verifyLessThan(t,min(d),2*P.robotR-1e-6);
end
function testASimplifiedRestarts(t)
P=tdp.defaultConfig();[r,b,s]=tdp.initialState(P);b.x=4.6;b.y=2;s.lastTouch=1;
[~,b,~]=tdp.rulesCheck(r,b,s,P);verifyEqual(t,[b.x b.y],[3.5 1.5]);
b.x=1;b.y=3.1;[~,b,~]=tdp.rulesCheck(r,b,s,P);verifyEqual(t,b.y,2.75);
end
function testLastTouchIsNotPossession(t)
P=tdp.defaultConfig();a=runA(1,0,10);tr=a.trace;
free=false(size(tr,1),1);
for k=1:size(tr,1),free(k)=all(hypot(tr(k,1:8)-tr(k,57),tr(k,9:16)-tr(k,58))>P.robotR+P.ballR+.01);end
increments=[0;diff(sum(tr(:,68:69),2))];verifyTrue(t,any(free & increments>0));
end
function testBOwnGoalSourceSlice(t)
behavior=struct('team',{1,2,1,2,1,2});
% A blue robot scoring into its own (negative-x) goal is still credited blue by B.
[score,~]=BScoringOracle(behavior,[0 0],1,1);verifyEqual(t,score,[1 0]);
P=tdp.defaultConfig();[r,b,s]=tdp.initialState(P);b.x=-4.6;b.y=0;s.lastTouch=1;
[~,~,s]=tdp.rulesCheck(r,b,s,P);verifyEqual(t,s.score,[0 1]);
end
function testBNoPossessionSourceSlice(t)
behavior=struct('team',{1,2,1,2,1,2});
[score,last]=BScoringOracle(behavior,[0 0],0,1);verifyEqual(t,last,1);verifyEqual(t,score,[1 0]);
P=tdp.defaultConfig();[~,~,s]=tdp.initialState(P);verifyEqual(t,s.lastTouch,0);
end
function testBRandomizeAccumulates(t)
root=fileparts(fileparts(mfilename('fullpath')));file=fullfile(root,'baseline','B_randomizeStartingPositions.m');
initBallPos=[0 0];initialPoses=zeros(6,3);rng(20);run(file);once=initialPoses;
rng(20);run(file);verifyEqual(t,initialPoses,2*once,'AbsTol',1e-12);
end
