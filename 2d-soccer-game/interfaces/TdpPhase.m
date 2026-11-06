classdef TdpPhase < Simulink.IntEnumType
    % Fixed interface enumeration.
    enumeration
        Idle(0)
        Search(1)
        Approach(2)
        Align(3)
        Kick(4)
        Recover(5)
    end
end
