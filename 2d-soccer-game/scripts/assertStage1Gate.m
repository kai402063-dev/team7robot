function assertStage1Gate(report)
%ASSERTSTAGE1GATE Reject missing, failed or blocked algorithm screening evidence.
required={'status','unsupportedCalls','messageCount'};
if ~isfield(report,'status') || ~isfield(report,'screening') || ...
 isempty(report.screening) || ~all(isfield(report.screening,required))
 error('TDP:Stage1Failed','Stage 1 screening evidence is missing or incomplete.');
end
states={report.screening.status};counts=[report.screening.unsupportedCalls];
if ~ismember(report.status,{'PASS','FAIL','BLOCKED'}) || ...
 strcmp(report.status,'FAIL') || any(~ismember(states,{'PASS','FAIL','BLOCKED'})) || ...
 any(strcmp(states,'FAIL')) || any(counts>0) || any(strcmp(states,'PASS') & counts~=0)
 error('TDP:Stage1Failed','Stage 1 screening failed; inspect the stage1 receipt for function-level details.');
end
if strcmp(report.status,'BLOCKED') || any(strcmp(states,'BLOCKED')) || any([report.screening.messageCount]>0)
 error('TDP:Stage1Blocked','Stage 1 screening needs a prerequisite or diagnostic review; inspect the stage1 receipt.');
end
end
