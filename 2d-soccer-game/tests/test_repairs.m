function tests=test_repairs
tests=functiontests(localfunctions);
end
function testCoincidentAndChainSeparation(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.CourseSimplified;
for spacing=[0 .1]
 [r,b,s]=tdp.initialState(P);active=false(1,8);active(1:3)=true;
 for i=1:3,r(i).x=spacing*(i-1);r(i).y=0;end
 [r,~,~]=Contact2D(r,b,s,false,active,P);
 for i=1:2,for j=i+1:3,verifyGreaterThanOrEqual(t,hypot(r(i).x-r(j).x,r(i).y-r(j).y),2*P.robotR-1e-8);end,end
end
end
function testEightCoincidentAtBoundary(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.CourseSimplified;[r,b,s]=tdp.initialState(P);
for i=1:8,r(i).x=5.34;r(i).y=3.84;end
[r,~,~]=Contact2D(r,b,s,false,true(1,8),P);
for i=1:8
 verifyLessThanOrEqual(t,abs(r(i).x)+P.robotR,5.5+1e-8);verifyLessThanOrEqual(t,abs(r(i).y)+P.robotR,4+1e-8);
 for j=i+1:8,verifyGreaterThanOrEqual(t,hypot(r(i).x-r(j).x,r(i).y-r(j).y),.3-1e-8);end
end
end
function testInactiveSlotsAreUntouched(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.CourseSimplified;[r,b,s]=tdp.initialState(P);r(8).x=20;
active=true(1,8);active(8)=false;[new,~,~]=Contact2D(r,b,s,false,active,P);verifyEqual(t,new(8),r(8));
end
function testReferenceRestartAndClearance(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.ReferenceRestarts;[r,b,s]=tdp.initialState(P);
b.x=4.6;b.y=2;s.lastTouch=1;r(2).x=0;r(2).y=3;
[r,b,s]=Referee2D(r,b,s,P);verifyEqual(t,[b.x b.y],[0 3]);verifyEqual(t,s.msg,TdpEvent.GoalKick);
for i=1:4,verifyGreaterThanOrEqual(t,hypot(r(i).x-b.x,r(i).y-b.y),.75-1e-8);end
b.x=1;b.y=3.1;s.lastTouch=1;[~,b,s]=Referee2D(r,b,s,P);verifyEqual(t,[b.x b.y],[1 3]);verifyEqual(t,s.msg,TdpEvent.KickIn);
end
function testWholeBallBetweenPosts(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.CourseSimplified;[r,b,s]=tdp.initialState(P);
b.x=4.6;b.y=1.28;s.lastTouch=1;[~,~,s]=Referee2D(r,b,s,P);verifyEqual(t,s.score,[0 0]);
end
function testOwnGoalAndNoTouch(t)
P=tdp.defaultConfig();P.rulesProfile=TdpRules.CourseSimplified;
for last=[0 1]
 [r,b,s]=tdp.initialState(P);b.x=-4.6;s.lastTouch=last;[~,~,s]=Referee2D(r,b,s,P);verifyEqual(t,s.score,[0 1]);
end
end
function testCompatibilityUntouched(t)
P=tdp.defaultConfig();[r,b,s]=tdp.initialState(P);r(2).x=r(1).x;r(2).y=r(1).y;b.x=4.6;b.y=2;s.lastTouch=1;
[a,c,e]=tdp.collisions(r,b,s,true,P);[x,y,z]=Contact2D(r,b,s,true,true(1,8),P);verifyEqual(t,x,a);verifyEqual(t,y,c);verifyEqual(t,z,e);
[a,c,e]=tdp.rulesCheck(r,b,s,P);[x,y,z]=Referee2D(r,b,s,P);verifyEqual(t,x,a);verifyEqual(t,y,c);verifyEqual(t,z,e);
end
