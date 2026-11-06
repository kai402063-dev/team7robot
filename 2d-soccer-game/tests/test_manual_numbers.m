function tests=test_manual_numbers
tests=functiontests(localfunctions);
end
function testNumbersMatchExecutableResults(t)
root=fileparts(fileparts(mfilename('fullpath')));saved=jsondecode(fileread(fullfile(root,'docs','generated','manual_numbers.json')));actual=manualMeasurements();
for key={'firstCommand','firstRobot4X','rollingDistance','finalBallSpeed','dt','tapSpeed','thresholdOld','thresholdNew'}
 verifyEqual(t,saved.(key{1}),actual.(key{1}),'AbsTol',1e-12);
end
verifyEqual(t,saved.delayLesson(:),actual.delayLesson(:),'AbsTol',1e-12);verifyEqual(t,saved.flatPhases(:),actual.flatPhases(:));verifyEqual(t,saved.replay,actual.replay);
end
function testRenderedManualContainsActualNumbers(t)
root=fileparts(fileparts(mfilename('fullpath')));n=jsondecode(fileread(fullfile(root,'docs','generated','manual_numbers.json')));
md=fileread(fullfile(root,'docs','generated','manual_numbers.md'));
for key={'firstCommand','firstRobot4X','rollingDistance'}
 verifySubstring(t,md,sprintf('| %.15g |',n.(key{1})));
end
entry=fileread(fullfile(root,'docs','DEV_MANUAL.md'));verifySubstring(t,entry,'generated/manual_numbers.md');
end
function testParameterTableMatchesCurrentConfiguration(t)
root=fileparts(fileparts(mfilename('fullpath')));saved=jsondecode(fileread(fullfile(root,'docs','generated','config.json')));P=tdp.defaultConfig();
keys=fieldnames(P);for k=1:numel(keys)
 key=keys{k};v=P.(key);
 if isenum(v),verifyEqual(t,saved.(key),char(string(v)));
 elseif islogical(v),verifyEqual(t,saved.(key),v);
 elseif isnumeric(v),verifyEqual(t,saved.(key)(:),v(:),'AbsTol',1e-12);end
end
end

function testM2NumbersFromActualRecordedInputs(t)
root=fileparts(fileparts(mfilename('fullpath')));saved=jsondecode(fileread(fullfile(root,'docs/generated/m2_numbers.json')));actual=manualM2Measurements();
keys=fieldnames(actual);for k=1:numel(keys),verifyEqual(t,saved.(keys{k}),actual.(keys{k}),'AbsTol',1e-12);end
md=fileread(fullfile(root,'docs/generated/m2_numbers.md'));
for k=1:numel(keys),verifySubstring(t,md,sprintf('| %s | %.15g |',keys{k},actual.(keys{k})));end
end
function testWebotsParameterTable(t)
root=fileparts(fileparts(mfilename('fullpath')));actual=jsondecode(fileread(fullfile(root,'config/webots.json')));saved=jsondecode(fileread(fullfile(root,'docs/generated/webots_config.json')));verifyEqual(t,saved,actual);
end

function testAnimationNumbersAndFigures(t)
root=fileparts(fileparts(mfilename('fullpath')));
n=jsondecode(fileread(fullfile(root,'docs/generated/animation_numbers.json')));
r=jsondecode(fileread(fullfile(root,n.source)));verifyEqual(t,r.status,'PASS');
verifyEqual(t,n.testsPassed,sum(r.tests.passed));
verifyEqual(t,n.pausedSimulationTime,r.controls.pausedTime);
verifyEqual(t,n.frozenSimulationTime,r.controls.frozenTime);
verifyEqual(t,n.stoppedFrames,r.controls.partialFrames);
verifyEqual(t,n.restartFrames,r.restart.frames);
launch=jsondecode(fileread(fullfile(root,n.launcherSource)));
match=jsondecode(fileread(fullfile(root,fileparts(n.launcherSource),'match-receipt.json')));
verifyEqual(t,launch.status,'PASS');verifyEqual(t,n.launcherFrames,launch.frames);
verifyEqual(t,n.launcherElapsedSeconds,launch.elapsedSeconds,'AbsTol',1e-10);
verifyEqual(t,n.coldInitializationSeconds,match.initializationSeconds,'AbsTol',1e-10);
md=fileread(fullfile(root,'docs/generated/animation_numbers.md'));
for key={'testsPassed','pausedSimulationTime','frozenSimulationTime','stoppedFrames','restartFrames','launcherFrames','coldInitializationSeconds','launcherElapsedSeconds'}
 verifySubstring(t,md,sprintf('| %s | %.15g |',key{1},n.(key{1})));
end
for name={'live-before.png','live-after.png'}
 verifyEqual(t,imread(fullfile(root,'docs/generated',['animation-' name{1}])), ...
     imread(fullfile(fileparts(fullfile(root,n.source)),name{1})));
end
end

function testV1ContractsAndHandWalk(t)
root=fileparts(fileparts(mfilename('fullpath')));
generated=fullfile(root,'docs','generated');
P=tdp.v1Config();
memory=tdp.v1TeamMemory();
columns=v1TraceColumns();
for pair={{'v1_config.json',P},{'v1_memory.json',memory},{'v1_columns.json',columns}}
    item=pair{1};
    source=item{2};
    saved=jsondecode(fileread(fullfile(generated,item{1})));
    verifyEqual(t,sort(fieldnames(saved)),sort(fieldnames(source)));
    for key=fieldnames(source)'
        name=key{1}; expected=source.(name); actual=saved.(name);
        if isenum(expected)
            verifyEqual(t,actual,char(string(expected)));
        elseif islogical(expected)
            verifyEqual(t,actual,expected);
        elseif ismatrix(expected) && ~isvector(expected)
            verifyEqual(t,actual,double(expected),'AbsTol',1e-12);
        else
            verifyEqual(t,actual(:),double(expected(:)),'AbsTol',1e-12);
        end
    end
end
walk=jsondecode(fileread(fullfile(generated,'v1_handwalk.json')));
verifyEqual(t,walk.bluePhase(:),[1;1;2;2;1]);
verifyEqual(t,walk.redPhase(:),walk.bluePhase(:));
verifyEqual(t,walk.time(:),1+(0:4)'*P.dt,'AbsTol',1e-12);
md=fileread(fullfile(generated,'v1_contracts.md'));
chapter=fileread(fullfile(root,'docs/chapters/tactics_v1_design.md'));
for key=fieldnames(columns)'
    idx=columns.(key{1});
    if isscalar(idx),label=num2str(idx);else,label=sprintf('%d–%d',idx(1),idx(end));end
    verifySubstring(t,md,sprintf('| %s | %s |',key{1},label));
end
for k=1:numel(walk.time)
    signedX=strrep(sprintf('%+.2f',walk.blueBallX(k)),'-','−');
    verifySubstring(t,chapter,sprintf('| %.2f | %s | %s |',walk.time(k),signedX, ...
        upper(char(string(TdpTeamPhase(walk.bluePhase(k)))))));
    verifySubstring(t,md,sprintf('| %.2f | %.2f | %s | %s |',walk.time(k),walk.blueBallX(k), ...
        char(string(TdpTeamPhase(walk.bluePhase(k)))),char(string(TdpTeamPhase(walk.redPhase(k))))));
end
allColumns=cell2mat(struct2cell(columns)');
verifyEqual(t,sort(allColumns),1:171);
end

function testV1ModelEvidenceMatchesRecordedEvents(t)
root=fileparts(fileparts(mfilename('fullpath')));
tool=fullfile(root,'scripts','export_v1_model_evidence.py');
[status,message]=system(['python3 ' shellQuote(tool) ' --check']);
verifyEqual(t,status,0,message);
end

function testV1MatchResultTable(t)
root=fileparts(fileparts(mfilename('fullpath')));
script=fullfile(root,'scripts','export_v1_results.py');
[status,diagnostic]=system(['python3 ' shellQuote(script) ' --check']);
verifyEqual(t,status,0,diagnostic);
end

function testRecoveryComparisonTable(t)
root=fileparts(fileparts(mfilename('fullpath')));
results=fullfile(root,'evidence','recovery-v1','clean-01');
tool=fullfile(root,'scripts','compare_recovery.py');
page=fullfile(root,'docs','generated','recovery_results.md');
[status,message]=system(strjoin({'python3',shellQuote(tool),shellQuote(results),'--check',shellQuote(page)},' '));
verifyEqual(t,status,0,message);
comparison=jsondecode(fileread(fullfile(results,'comparison.json')));
verifyEqual(t,comparison.officialMatches,80);
verifyEqual(t,comparison.totalOfficialSteps,1080000);
verifyEqual(t,comparison.historicMatchesReproduced,40);
verifyEqual(t,numel(comparison.matches),40);
verifyTrue(t,all([comparison.matches.defaultEqualsArchived]));
config=tdp.recoveryConfig();
for pair=comparison.matches'
    evidence=jsondecode(fileread(fullfile(results,pair.experimentReceipt)));
    verifyEqual(t,evidence.status,'PASS');
    verifyEqual(t,evidence.recovery.returns,pair.handback.returns);
    verifyEqual(t,evidence.parameters.v1RecoveryHealthySeconds,config.v1RecoveryHealthySeconds);
end
end
