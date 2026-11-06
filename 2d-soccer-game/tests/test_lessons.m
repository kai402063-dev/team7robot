function tests=test_lessons
tests=functiontests(localfunctions);
end
function testClosedLoopUnitDelay(t)
o=sim('tdpDelayLesson');y=o.records;verifyEqual(t,y(:)',1-(1-.8*.05).^(0:4),'AbsTol',1e-12);
verifyEqual(t,get_param('tdpDelayLesson','AlgebraicLoopMsg'),'error');
end
function testFlatStates(t)
o=sim('tdpFlatLesson');verifyEqual(t,o.records(:)',[0 1 2 2 2]);
end
function testLearningHarnessUsesItsOwnChart(t)
P=tdp.defaultConfig();P.mode=TdpMode.Delayed;s=makeScenario(P,2);
reference=runReplay(P,s);original=runReplay(P,s,'tdpLearningReplay');verifyEqual(t,original,reference);
verifyEqual(t,get_param('tdpLearningReplay/ControllerCore','LinkStatus'),'none');
ch=find(sfroot,'-isa','Stateflow.Chart','Path','tdpLearningReplay/ControllerCore/SkillStages');
tr=find(ch,'-isa','Stateflow.Transition','LabelString','[tSim-kickStart>=P.kickTimeout]');
assert(numel(tr)==1);label=tr.LabelString;dirty=get_param('tdpLearningReplay','Dirty');cleanup=onCleanup(@()restoreTransition(tr,label,dirty));
tr.LabelString='[tSim-kickStart>=P.kickTimeout/2]';changed=runReplay(P,s,'tdpLearningReplay');
a=find(original(:,3)==double(TdpPhase.Recover),1);b=find(changed(:,3)==double(TdpPhase.Recover),1);
verifyLessThan(t,b,a);verifyEqual(t,runReplay(P,s),reference);
end
function restoreTransition(tr,label,dirty)
tr.LabelString=label;set_param('tdpLearningReplay','Dirty',dirty);
end
