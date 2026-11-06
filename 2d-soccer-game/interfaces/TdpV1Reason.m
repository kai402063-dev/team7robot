classdef TdpV1Reason < Simulink.IntEnumType
    % Cause of the reported action outcome in the recovery experiment.
    enumeration
        None(0)
        Geometry(1)
        Arbitration(2)
        Subsystem(3)
        Canceled(4)
        Expired(5)
    end
end
