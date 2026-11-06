classdef TdpAction < Simulink.IntEnumType
    % Fixed interface enumeration.
    enumeration
        Stop(0)
        Goto(1)
        Kick(2)
        Search(3)
        Tap(4)
    end
end
