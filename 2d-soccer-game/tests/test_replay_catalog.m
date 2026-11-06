function tests = test_replay_catalog
tests = functiontests(localfunctions);
end

function setup(t)
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.build = fixture.Folder;
end

function testCompletedAndStoppedSortedByStartTime(t)
root = t.TestData.build;
completed = writeMatch(root, 'animation-20261105-142355-021', 'COMPLETED');
stopped = writeMatch(root, 'animation-20261106-110305-343-1', 'STOPPED_BY_USER');
headless = writeMatch(root, 'run-20261106-095958-405', 'COMPLETED');
matches = listReplayMatches(root);
t.verifyEqual({matches.file}, {stopped, headless, completed});
t.verifyEqual({matches.status}, {'STOPPED_BY_USER','COMPLETED','COMPLETED'});
t.verifySubstring(matches(1).label, '2026-11-06 11:03:05.343');
t.verifySubstring(matches(1).label, '蓝 2 : 1 红');
t.verifySubstring(matches(1).label, '00:00.25');
t.verifySubstring(matches(1).label, '提前停止');
t.verifySubstring(matches(2).label, '已完赛');
end

function testIgnoreUnplayableAndUnrelatedRuns(t)
root = t.TestData.build;
good = writeMatch(root, 'animation-20261106-125959-999', 'COMPLETED');
writeMatch(root, 'animation-20261106-130000-001', 'FAIL');
writeMatch(root, 'run-20261106-130000-002', 'RUNNING');
writeMatch(root, 'animation-launcher', 'COMPLETED');
unreadable = writeMatch(root, 'animation-20261106-130000-003', 'COMPLETED');
writelines("broken", unreadable);
missingParams = writeMatch(root, 'animation-20261106-130000-004', 'COMPLETED');
trace = zeros(5,98); %#ok<NASGU>
save(missingParams, 'trace');
malformedReceipt = writeMatch(root, 'animation-20261106-130000-005', 'COMPLETED');
writelines("{", fullfile(fileparts(malformedReceipt),'receipt.json'));
missingTrace = writeMatch(root, 'animation-20261106-130000-006', 'COMPLETED');
delete(missingTrace);
shortTrace = writeMatch(root, 'animation-20261106-130000-007', 'COMPLETED');
P = struct('dt', 0.05); %#ok<NASGU>
trace = zeros(0,98); %#ok<NASGU>
save(shortTrace, 'P', 'trace');
matches = listReplayMatches(root);
t.verifyEqual({matches.file}, {good});
end

function testEmptyBuildDirectory(t)
t.verifyEmpty(listReplayMatches(t.TestData.build));
t.verifyEmpty(listReplayMatches(fullfile(t.TestData.build, 'not-created')));
end

function file = writeMatch(root, name, status)
directory = fullfile(root, name);
mkdir(directory);
file = fullfile(directory, 'trace.mat');
trace = zeros(5,98);
P = struct('dt', 0.05, 'Tmatch', 600);
metrics = struct('goals', [2 1], 'steps', size(trace,1), 'finite', true);
receipt = struct('status', status, 'metrics', metrics, 'parameters', P);
writeJson(fullfile(directory,'receipt.json'), receipt);
save(file, 'P', 'trace');
end
