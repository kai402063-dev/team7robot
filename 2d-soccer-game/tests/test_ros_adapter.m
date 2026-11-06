function tests=test_ros_adapter
tests=functiontests(localfunctions);
end
function testFreshAndDuplicate(t)
P=tdp.defaultConfig();f=makeBridgeFrames(P,2);
[o,~,~,~,q,h]=BridgeDecode(f(1,:),zeros(1,20),P);verifyTrue(t,o.selfValid);verifyEqual(t,q(1),1);
f(1,2)=0.6;[o,~,~,~,q,h2]=BridgeDecode(f(1,:),h,P);verifyFalse(t,o.selfValid);verifyEqual(t,q(1),0);verifyEqual(t,q(2),0.6);verifyEqual(t,h2(3),h(3));
end
function testOldSequenceAndFuture(t)
P=tdp.defaultConfig();f=makeBridgeFrames(P,3);[~,~,~,~,~,h]=BridgeDecode(f(2,:),zeros(1,20),P);
f(1,2)=0.2;f(1,4)=99;[o,~,~,~,q]=BridgeDecode(f(1,:),h,P);verifyEqual(t,o.robots(1).x,h(4));verifyEqual(t,q(1),0);
f(3,3)=1;[o,~,~,~,q]=BridgeDecode(f(3,:),h,P);verifyFalse(t,o.selfValid);verifyEqual(t,q(3),1);
end
function testBadPacketAndClock(t)
P=tdp.defaultConfig();f=makeBridgeFrames(P,3);[~,~,~,~,~,h]=BridgeDecode(f(2,:),zeros(1,20),P);
f(3,1)=2;[~,~,~,~,q,h2]=BridgeDecode(f(3,:),h,P);verifyEqual(t,q(1),0);verifyEqual(t,h2(20),h(20));
[o,~,~,~,q]=BridgeDecode(f(1,:),h,P);verifyFalse(t,o.selfValid);verifyEqual(t,q(6),0);
f(3,1)=1;f(3,8)=NaN;[~,~,~,~,q]=BridgeDecode(f(3,:),h,P);verifyEqual(t,q(1),0);
end
function testFeedbackContract(t)
P=tdp.defaultConfig();f=makeBridgeFrames(P,1);f(15:17)=[17 2 0];
[~,~,fb]=BridgeDecode(f,zeros(1,20),P);verifyEqual(t,fb.requestId,uint32(17));verifyEqual(t,fb.status,TdpStatus.Done);
f(17)=1;[~,~,fb]=BridgeDecode(f,zeros(1,20),P);verifyEqual(t,fb.status,TdpStatus.None);
end
function testActualCoreReplay(t)
P=tdp.defaultConfig();P.dt=0.04;P.mode=TdpMode.Delayed;f=makeBridgeFrames(P,101);
[a,q]=runFrameReplay(P,f);b=runFrameReplay(P,f);verifyEqual(t,a,b);verifyTrue(t,any(q(:,3)==1));verifyTrue(t,any(a(:,3)==double(TdpPhase.Kick)));
end
