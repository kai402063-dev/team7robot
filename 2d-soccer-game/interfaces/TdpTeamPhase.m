classdef TdpTeamPhase < Simulink.IntEnumType
    % Team-level tactical mode, separate from an individual skill phase.
    enumeration
        Hold(0)
        Defend(1)
        Attack(2)
        Search(3)
        Fallback(4)
    end
end
