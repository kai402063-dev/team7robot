function ack=BridgeWrite(values)
%BRIDGEWRITE Send one fixed action record through the existing JVM.
BridgeSocket('write',values);ack=1;
end
