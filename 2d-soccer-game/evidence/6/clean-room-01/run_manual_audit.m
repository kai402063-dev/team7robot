function audit = run_manual_audit
% Execute only commands and exercise instructions reachable from DEV_MANUAL.
root = tdpSetup();
cd(root);
out = fullfile(root, 'build', 'manual-reproduction-audit');
learning = fullfile(root, 'build', 'learning');
addpath(learning);
timer = tic;
audit = struct('status', 'RUNNING', 'startedUTC', utcNow());
audit.matlab = version;
audit.release = version('-release');
audit.products = ver;
audit.root = root;
audit.runAResolution = which('runA', '-all');
audit.controllerResolution = which('ControllerCore', '-all');
audit.replayResolution = which('runReplay', '-all');
writeJson(fullfile(out, 'manual-receipt.json'), audit);
try
    names = {'runA', 'runReplay', 'makeScenario', 'build_lessons', 'tdp.laneClear'};
    for i = 1:numel(names)
        resolved = which(names{i});
        assert(startsWith(resolved, [root filesep]), 'TDP:CloneResolution', ...
            'Function resolves outside the clean clone: %s = %s', names{i}, resolved);
    end
    step = tic;
    a = runA(1, 0, 0.05);
    audit.quickExample = struct('request', a.trace(1,76), ...
        'robot4X', a.robots(4).x, 'elapsedSeconds', toc(step));
    assert(abs(a.trace(1,76) - 0.44) < 1e-12);
    assert(abs(a.robots(4).x + 0.9875) < 1e-12);
    fprintf('MANUAL quick example: request=%.17g, robot4.x=%.17g\n', ...
        a.trace(1,76), a.robots(4).x);

    step = tic;
    baseline = runtests(fullfile(learning, 'test_laneClearLesson.m'));
    assertSuccess(baseline);
    lessonFile = fullfile(learning, 'laneClearLesson.m');
    original = fileread(lessonFile);
    corrupted = strrep(original, 'if distance < margin', 'if distance > margin');
    assert(~strcmp(original, corrupted), 'Mutation was not applied');
    restoreGuard = onCleanup(@() writeText(lessonFile, original));
    writeText(fullfile(out, 'laneClearLesson-mutated.txt'), corrupted);
    writeText(lessonFile, corrupted);
    clear laneClearLesson
    rehash;
    mutant = runtests(fullfile(learning, 'test_laneClearLesson.m'));
    clear restoreGuard
    clear laneClearLesson
    rehash;
    assert(any([mutant.Failed]) && ~any([mutant.Incomplete]), ...
        'Mutation must fail an assertion without incomplete tests');
    restored = runtests(fullfile(learning, 'test_laneClearLesson.m'));
    assertSuccess(restored);
    audit.path1 = struct('status', 'PASS', 'baseline', summarize(baseline), ...
        'mutant', summarize(mutant), 'restored', summarize(restored), ...
        'elapsedSeconds', toc(step));

    step = tic;
    build_lessons;
    lessons = runtests('tests/test_lessons.m');
    assertSuccess(lessons);
    delayOutput = sim('tdpDelayLesson');
    flatOutput = sim('tdpFlatLesson');
    audit.path2 = struct('status', 'PASS_AUTOMATED_EQUIVALENT', ...
        'records', delayOutput.records(:)');
    audit.path3 = struct('status', 'PASS_AUTOMATED_EQUIVALENT', ...
        'records', flatOutput.records(:)');
    audit.lessonTests = summarize(lessons);
    audit.lessonsElapsedSeconds = toc(step);

    step = tic;
    P = tdp.defaultConfig(); P.mode = TdpMode.Delayed;
    s = makeScenario(P, 2);
    a = runReplay(P, s); b = runReplay(P, s);
    assert(isequaln(a, b));
    save(fullfile(out, 'manual-replay.mat'), 'P', 's', 'a', 'b');
    controller = runtests('tests/test_controller.m');
    assertSuccess(controller);
    audit.path4 = struct('status', 'PASS_AUTOMATED_EQUIVALENT', ...
        'tests', summarize(controller), ...
        'copyPasteExercise', 'BLOCKED_DOCUMENTATION_HTML_ENTITIES_IN_CODE_SPANS');
    audit.path5 = struct('status', 'PASS', 'deterministic', isequaln(a,b), ...
        'recordSize', size(a), 'elapsedSeconds', toc(step));

    step = tic;
    P = tdp.defaultConfig(); P.mode = TdpMode.Delayed;
    P.observationDelay = 0.10; P.observationNoise = 0.02;
    [records, scenario] = sensorReplay(P, 7, 2);
    save(fullfile(out, 'extension-example.mat'), 'P', 'records', 'scenario');
    audit.extensionExample = struct('status', 'PASS', ...
        'recordSize', size(records), 'elapsedSeconds', toc(step));
    audit.path6 = struct('status', 'BLOCKED', ...
        'reason', 'ROS Toolbox/Coders absent; M2 CLI path not implemented in this commit');
    audit.path7 = struct('status', 'BLOCKED', ...
        'reason', 'M2 Webots path not implemented in this commit; no scene or action command in this manual');
    audit.guiDragging = 'NOT_RUN: automated generation is not human GUI construction';
    audit.status = 'PASS_AUTOMATED_MANUAL_PATHS_WITH_DOCUMENTED_BLOCKERS';
catch e
    audit.status = 'FAIL';
    audit.error = getReport(e, 'extended', 'hyperlinks', 'off');
    audit.endedUTC = utcNow();
    audit.elapsedSeconds = toc(timer);
    writeJson(fullfile(out, 'manual-receipt.json'), audit);
    rethrow(e);
end
audit.endedUTC = utcNow();
audit.elapsedSeconds = toc(timer);
writeJson(fullfile(out, 'manual-receipt.json'), audit);
fprintf('MANUAL_AUDIT %s in %.1f seconds. Receipt: %s\n', ...
    audit.status, audit.elapsedSeconds, fullfile(out, 'manual-receipt.json'));
end

function s = summarize(r)
s = struct('names', {{r.Name}}, 'passed', [r.Passed], ...
    'failed', [r.Failed], 'incomplete', [r.Incomplete], 'durations', [r.Duration]);
end

function value = utcNow()
value = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end

function writeText(path, contents)
fid = fopen(path, 'w');
assert(fid ~= -1, 'Cannot write exercise file');
guard = onCleanup(@() fclose(fid));
fwrite(fid, contents, 'char');
end
