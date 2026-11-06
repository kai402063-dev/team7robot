function tests=test_algorithms
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));tc.TestData.oldPath=path;
addpath(fullfile(root,'reference','projectA'));rng(20261105,'twister');
P=tdp.defaultConfig();tc.TestData.P=P;
cases=cell(1,1000);
for k=1:1000
 [r,b,s]=tdp.initialState(P);
 for j=1:8
  r(j).x=12*rand-6;r(j).y=9*rand-4.5;r(j).th=8*pi*(rand-0.5);
  r(j).vxw=randn;r(j).vyw=randn;r(j).cool=max(0,randn);
 end
 b.x=12*rand-6;b.y=9*rand-4.5;b.vx=3*randn;b.vy=3*randn;
 target=[10*rand-5 8*rand-4];heading=8*pi*(rand-0.5);self=1+mod(k-1,8);
 if mod(k,5)==0
  b.x=r(self).x+0.25;b.y=r(self).y;r(self).th=0;r(self).cool=0;target=[b.x+4 b.y];
 end
 if mod(k,7)==0,r(2).x=r(1).x;r(2).y=r(1).y;end
 if mod(k,11)==0,target=[b.x b.y];end
 if mod(k,13)==0,b.x=P.L/2+P.ballR;b.y=P.goalW/2;end
 s.t=k*P.dt;s.lastTouch=mod(k,3);s.score=[2 3];s.touchTime=[4 5];
 cases{k}=struct('r',r,'b',b,'s',s,'target',target,'heading',heading,'self',self, ...
 'allow',mod(k,3)~=0,'speed',3*rand,'cmd',2*randn(8,3),'mem',struct('striker',mod(k,5)), ...
 'team',1+mod(k,2),'noise',randn);
end
tc.TestData.cases=cases;
end
function teardownOnce(tc)
path(tc.TestData.oldPath);
end
function testGoToPose(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 old=goToPose(q.r(q.self),q.target,q.heading,q.r,q.self,q.b,q.allow,P);
 new=tdp.goToPose(q.r(q.self),q.target,q.heading,q.r,q.self,q.b,q.allow,P);
 verifyEqual(tc,new,old,'AbsTol',1e-12);
end
end
function testKickSkill(tc)
kicks=0;
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 rng(k,'twister');z=randn;rng(k,'twister');
 [a,b,c]=kickSkill(q.r(q.self),q.b,q.target,q.speed,q.r,q.self,q.allow,P);
 [x,y,zv]=tdp.kickSkill(q.r(q.self),q.b,q.target,q.speed,q.r,q.self,q.allow,P,z);
 verifyEqual(tc,x,a,'AbsTol',1e-12);verifyEqual(tc,y,b);verifyEqual(tc,zv,c,'AbsTol',1e-12);kicks=kicks+b;
end
verifyGreaterThan(tc,kicks,100);
end
function testRobotModel(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 verifyEqual(tc,tdp.robotModel(q.r,q.cmd,P),robotModel(q.r,q.cmd,P),'AbsTol',1e-12);
end
end
function testBallModel(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 verifyEqual(tc,tdp.ballModel(q.b,P),ballModel(q.b,P),'AbsTol',1e-12);
end
end
function testCollisions(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 [a,b,c]=collisions(q.r,q.b,q.s,q.allow,P);[x,y,z]=tdp.collisions(q.r,q.b,q.s,q.allow,P);
 verifyEqual(tc,x,a,'AbsTol',1e-12);verifyEqual(tc,y,b,'AbsTol',1e-12);verifyEqual(tc,z,c,'AbsTol',1e-12);
end
end
function testRulesCheck(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 [a,b,c]=rulesCheck(asLegacy(q.r),q.b,asLegacy(q.s),P);[x,y,z]=tdp.rulesCheck(q.r,q.b,q.s,P);
 verifyEqual(tc,asLegacy(x),a,'AbsTol',1e-12);verifyEqual(tc,y,b,'AbsTol',1e-12);verifyEqual(tc,asLegacy(z),c,'AbsTol',1e-12);
end
end
function testRoleAssignment(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 [a,m]=teamBehaviour(asLegacy(q.r),q.b,q.team,q.mem,P);[roles,n]=tdp.roleAssignment(q.r,q.b,q.team,q.mem,P);
 for j=1:4,verifyEqual(tc,asLegacy(roles(j)),a(j).role);end
 verifyEqual(tc,n,m);
end
end
function testActionSelection(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 [a,~]=teamBehaviour(asLegacy(q.r),q.b,q.team,q.mem,P);[roles,~]=tdp.roleAssignment(q.r,q.b,q.team,q.mem,P);
 b=tdp.actionSelection(q.r,q.b,q.team,roles,P);verifyEqual(tc,asLegacy(b),a,'AbsTol',1e-12);
end
end
function testLaneClear(tc)
for k=1:1000
 q=tc.TestData.cases{k};a=[q.b.x q.b.y];b=q.target;op=[[q.r(5:8).x]' [q.r(5:8).y]'];
 verifyEqual(tc,tdp.laneClear(a,b,op,0.4),oracleLaneClear(a,b,op,0.4));
end
end
function testAnglesAndKickoff(tc)
for k=1:1000
 q=tc.TestData.cases{k};P=tc.TestData.P;
 verifyEqual(tc,tdp.angWrap(q.heading),angWrap(q.heading),'AbsTol',1e-12);
 [a,b]=kickoffReset(q.r,q.b,P);[x,y]=tdp.kickoffReset(q.r,q.b,P);
 verifyEqual(tc,x,a,'AbsTol',1e-12);verifyEqual(tc,y,b,'AbsTol',1e-12);
end
end
