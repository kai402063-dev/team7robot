classdef TdpEvent < Simulink.IntEnumType
    % Fixed interface enumeration.
    enumeration
        None(0)
        Kickoff(1)
        GoalBlue(2)
        GoalRed(3)
        GoalKick(4)
        Corner(5)
        KickIn(6)
    end
end
