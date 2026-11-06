function [actions,mem]=teamBehaviour(robots,ball,team,mem,P)
%TEAMBEHAVIOUR Compose pure role allocation and action selection.
[roles,mem]=tdp.roleAssignment(robots,ball,team,mem,P);
actions=tdp.actionSelection(robots,ball,team,roles,P);
end
