function P=validateConfig(P)
%VALIDATECONFIG Reject unknown, nonfinite and unsupported numerical choices.
keys=fieldnames(P);
for k=1:numel(keys)
 value=P.(keys{k});
 if isnumeric(value) && ~isenum(value),tdp.requireKnown(value);end
end
assert(isscalar(P.dt) && isfinite(P.dt) && P.dt>0,'TDP:Config','Invalid dt');
assert(P.nPerTeam==4,'TDP:Config','Exactly four robots per team required');
assert(P.L==9 && P.W==6,'TDP:Config','Course pitch must be 9 by 6 m');
values=[P.vFwd P.vBack P.vSide P.wMax P.robotR P.ballR P.ballDecel ...
 P.walkValidity P.kickTimeout P.maxObservationAge P.kickRange];
assert(all(isfinite(values)) && all(values>0),'TDP:Config','Unknown or invalid parameter');
assert(P.kickPreparation>=0 && P.kickPreparation<P.kickTimeout,'TDP:Config','Preparation must fit timeout');
assert(P.alignExit>P.alignEnter,'TDP:Config','Alignment hysteresis is invalid');
assert(P.fieldOfView>0 && P.fieldOfView<=2*pi,'TDP:Config','Invalid FOV');
assert(P.observationDelay>=0 && P.observationNoise>=0,'TDP:Config','Invalid observation settings');
assert(isfinite(P.contactIterations) && P.contactIterations>=1 && P.contactIterations==round(P.contactIterations),'TDP:Config','Invalid contact iteration limit');
assert(P.contactTolerance>0 && isfinite(P.contactTolerance),'TDP:Config','Invalid contact tolerance');
assert(P.restartOpponentDistance>0 && isfinite(P.restartOpponentDistance),'TDP:Config','Invalid restart clearance');
assert(isa(P.mode,'TdpMode') && isa(P.rulesProfile,'TdpRules'),'TDP:Config','Use typed profiles');
end
