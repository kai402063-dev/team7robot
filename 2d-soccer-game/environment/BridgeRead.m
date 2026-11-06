function frame=BridgeRead()
%BRIDGEREAD Blocking host transport. Control time is carried in the frame.
frame=BridgeSocket('read',[]);
end
