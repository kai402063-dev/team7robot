classdef TdpStatus < Simulink.IntEnumType
    % Fixed interface enumeration.
    enumeration
        None(0)
        Running(1)
        Done(2)
        Failed(3)
        Rejected(4)
    end
end
