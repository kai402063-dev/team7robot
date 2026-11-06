function [score,lastPossession]=BScoringOracle(behavior,score,robotIdx,lastPossession)
%BSCORINGORACLE Exact executable assignments from B chart_529.xml.
% This is a source-slice reproduction, not a full B model simulation.
if robotIdx > 0
    lastPossession = robotIdx;
end
teamIdx = behavior(lastPossession).team;
score(teamIdx) = score(teamIdx) + 1;
end
