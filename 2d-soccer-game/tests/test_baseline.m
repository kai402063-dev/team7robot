function tests=test_baseline
tests=functiontests(localfunctions);
end
function testFirstStep(testCase)
r=runA(1,0,0.05);verifyEqual(testCase,r.trace(1,76),0.44,'AbsTol',1e-12);
verifyEqual(testCase,r.robots(4).x,-0.9875,'AbsTol',1e-12);
end
function testRolling(testCase)
root=fileparts(fileparts(mfilename('fullpath')));p=path;c=onCleanup(@()path(p));
addpath(fullfile(root,'reference','projectA'));P=simParams();
b=struct('x',0,'y',0,'vx',1.8,'vy',0);
for k=1:90,b=ballModel(b,P);end
verifyEqual(testCase,b.x,4.005,'AbsTol',1e-12);verifyEqual(testCase,b.vx,0,'AbsTol',1e-12);
end
function testDeterministic(testCase)
a=runA(19,[],10);b=runA(19,[],10);verifyEqual(testCase,a,b);
end
