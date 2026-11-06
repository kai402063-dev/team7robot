"""Aggregate existing manual-command evidence without running or modifying models."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess

audit = Path(__file__).resolve().parent
root = audit.parents[1]
build = root / 'build'
def read(path):
    return json.loads(Path(path).read_text())
def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write_new(path, value):
    with Path(path).open('x') as handle:
        json.dump(value, handle, indent=2)
        handle.write('\n')

one_path = next(build.glob('reproduce-*/receipt.json'))
one = read(one_path)
manual = read(audit / 'manual-paths-01/receipt.json')
scalar = read(audit / 'scalar-01/receipt.json')
ros = read(build / 'ros-manual-03/receipt.json')
motion = read(build / 'webots-motion-manual-01/webots-receipt.json')
probe = read(build / 'webots-camera-manual-01/decoded/camera-receipt.json')
closed_dir = build / 'webots-closed-manual-01'
closed = read(closed_dir / 'analysis.json')
replay = read(closed_dir / 'replayed/replay-receipt.json')
camera = read(closed_dir / 'decoded/camera-receipt.json')
cleanup = read(audit / 'PROCESS_CLEANUP_FINAL.json')
assert one['status'] == 'PASS_AVAILABLE_M2_WITH_BLOCKERS_AND_NOISY_TRACE_DIFFERENCES'
assert manual['status'] == 'PASS_API_MANUAL_PATHS_GUI_NOT_PERFORMED'
assert scalar['status'] == 'PASS' and ros['actionsExactlyEqual'] and ros['frames'] == 101
assert motion['executions'] == 1 and motion['duplicateDeliveries'] == 200
assert motion['kickResults'][0]['motionEnded'] and motion['kickResults'][0]['ballDisplacementAtMotionEnd'] == 0
assert probe['ErrorCode'] == 0 and camera['ErrorCode'] == 0
assert closed['status'] == 'PASS_SINGLE_V5_CLOSED_LOOP' and closed['frames'] == 1001
assert replay['status'] == 'PASS' and replay['frames'] == 1001 and replay['exactActions']
assert not cleanup['activeTaskRuntimeProcesses'] and not cleanup['port29741Listeners']

command_names = ['manual-api-01', 'ros-build-01', 'scalar-command-01', 'ros-online-03',
    'webots-build-01', 'webots-pitch-01', 'webots-probe-01', 'webots-probe-decode-01',
    'webots-motion-01', 'webots-closed-01', 'webots-analysis-01', 'webots-replay-camera-01']
commands = {name: read(audit / name / 'command.json') for name in command_names}
assert all(r['status'] == 'PASS' and r['exitCode'] == 0 for r in commands.values())
one_cmd = read(audit / 'command.json')
assert one_cmd['status'] == 'PASS' and one_cmd['exitCode'] == 0
assert sha(root / 'models/ControllerCore.slx') == read(audit / 'core-before-manual.json')['sha256']
changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=root, text=True).splitlines()
assert all(p.startswith('models/') or p == 'docs/generated/match_snapshot.png' for p in changed)
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
assert commit == '1f52c4c6903e80817d2f80bce5795cab2dcda4d7'

actual = {'scalarInput': scalar['input'], 'scalarOutput': scalar['output'],
    'rosReplayFrames': ros['frames'], 'webotsFrames': closed['frames'],
    'clockPublishers': closed['clockPublishers'], 'initialDistanceMetres': closed['initialDistanceMetres'],
    'distanceAtShootMetres': closed['distanceAtShootMetres'], 'requestId': closed['requestId'],
    'motionStartSeconds': closed['motionStartSeconds'], 'motionEndSeconds': closed['motionEndSeconds'],
    'motionDurationSeconds': closed['motionDurationSeconds'],
    'motionEventBallDisplacementMetres': closed['motionEventBallDisplacementMetres'],
    'sampledBallDisplacementMetres': closed['ballDisplacementMetres'],
    'ballEvaluationTimeSeconds': closed['ballEvaluationTimeSeconds'],
    'sampledBallPeakSpeedMetresPerSecond': closed['ballPeakSpeedMetresPerSecond'],
    'duplicateDeliveries': closed['extraDuplicateDeliveries'], 'physicalExecutions': closed['physicalExecutions'],
    'motionOnlyBallDisplacementMetres': motion['kickResults'][0]['ballDisplacementAtMotionEnd'],
    'cameraErrorCode': camera['ErrorCode'], 'cameraWidth': camera['meta']['width'],
    'cameraHeight': camera['meta']['height'], 'cameraBytes': camera['meta']['bytes']}
expected = read(audit / 'committed-m2_numbers.json')
comparison = [{'field': key, 'committedGeneratedValue': value, 'newActualValue': actual[key],
    'newMinusGenerated': actual[key] - value, 'exactlyEqual': actual[key] == value}
    for key, value in expected.items()]
assert all(row['exactlyEqual'] for row in comparison)
for directory in [build / 'webots-camera-manual-01', closed_dir]:
    meta = read(directory / 'camera-ros.json')
    assert (directory / 'camera-ros.bgra').stat().st_size == meta['bytes']
    assert sha(directory / 'camera-ros.bgra') == meta['sha256']
measure = {'targetCommit': commit, 'run': 'manual', 'all22FieldsExactlyEqual': True,
    'maximumAbsoluteDifference': max(abs(row['newMinusGenerated']) for row in comparison),
    'comparison': comparison, 'webotsTraceSHA256': closed['traceSHA256'],
    'cameraSHA256': camera['meta']['sha256'], 'sameTraceAsOneKey': closed['traceSHA256'] == one['m2']['webots']['traceSHA256'],
    'motionBootstrapRepublishes': motion['bootstrapRepublishes'],
    'closedBootstrapRepublishes': read(closed_dir / 'webots-receipt.json')['bootstrapRepublishes'],
    'bootstrapNote': 'Discovery retries are wall-clock coordination, not control frames or physical duplicate executions.'}
write_new(audit / 'new-measurements-manual.json', measure)

comparisons = one['stage3']['comparisons']
zero = [row for row in comparisons if row['kickNoise'] == 0]
noisy = [row for row in comparisons if row['kickNoise'] != 0]
inputs = [one_path, audit / 'manual-paths-01/receipt.json', audit / 'scalar-01/receipt.json',
    build / 'ros-manual-03/receipt.json', build / 'webots-camera-manual-01/receipt.json',
    build / 'webots-camera-manual-01/decoded/camera-receipt.json',
    build / 'webots-motion-manual-01/webots-receipt.json', closed_dir / 'analysis.json',
    closed_dir / 'replayed/replay-receipt.json', closed_dir / 'decoded/camera-receipt.json',
    audit / 'PROCESS_CLEANUP_FINAL.json', audit / 'new-measurements-manual.json']
result = {'status': one['status'], 'manualAvailablePathsStatus': 'PASS_API_CLI_CUSTOM_CAMERA_WEBOTS_V5',
    'completedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'targetCommit': commit,
    'cloneRoot': str(root), 'matlabVersion': manual['matlabVersion'],
    'reproductionProvenance': 'Same clean clone resumed after preserved interruptions; completed one-key/API/build/scalar gates were checked from their original evidence and not rerun.',
    'oneKey': {'commandRecord': str(audit / 'command.json'), 'receipt': str(one_path),
        'wallSecondsIncludingMatlabStartup': one_cmd['wallSeconds'], 'suiteElapsedSeconds': one['elapsedSeconds'],
        'freshClone': one_cmd['freshClone'], 'reusedBuildCaches': one_cmd['reusedBuildCaches']},
    'manualCommands': commands, 'successfulManualCommandWallSeconds': sum(r['wallSeconds'] for r in commands.values()),
    'manualAPI': {'receipt': str(audit / 'manual-paths-01/receipt.json'), 'guiDragging': manual['guiDragging'],
        'laneOriginalPassed': sum(manual['laneOriginal']['passed']), 'laneMutationFailures': sum(manual['laneMutation']['failed']),
        'laneRestoredPassed': sum(manual['laneRestored']['passed']), 'controllerPassed': sum(manual['controller']['passed']),
        'lessonsPassed': sum(manual['lessons']['passed']), 'rosAdapterPassed': sum(manual['rosAdapter']['passed']),
        'hierarchical': manual['hierarchical']},
    'ros': ros, 'webotsPitch': read(audit / 'webots-pitch-01/stdout.log'),
    'webotsProbeCamera': probe, 'webotsMotionOnly': motion, 'webotsClosedLoop': closed,
    'webotsReplay': replay, 'webotsClosedCamera': camera, 'actualMeasurements': measure,
    'compatibility': {'stage3RawStatus': one['stage3']['status'], 'zeroNoiseMatches': len(zero),
        'zeroNoiseMaximumDifference': max(row['maximumDifference'] for row in zero),
        'defaultNoiseMatches': len(noisy), 'defaultNoiseMaximumDifference': max(row['maximumDifference'] for row in noisy),
        'defaultNoiseTraceEquivalent': False,
        'all40GoalShotFirstTouchMetricsEqual': all(all(row['oracle'][k] == row['migrated'][k] for k in ('goals', 'shots', 'firstTouchSeconds')) for row in comparisons)},
    'blockedProducts': ['ROS Toolbox', 'Simulink Coder', 'MATLAB Coder'],
    'blockedGates': {'nativeMatlabRos2': one['rosOnline'], 'generatedControllerNode': one['rosStandalone'], 'nativeReadImage': camera['nativeReadImage']},
    'unverified': {'guiDragging': 'NOT_PERFORMED', 'asynchronousNoNewWatchdog': 'NOT_VERIFIED',
        'NAO6AndRealDynamicsValidation': 'NOT_ESTABLISHED', 'visionBallDetectionAndLocalization': 'NOT_IMPLEMENTED',
        'realTimeControl': 'NOT_ESTABLISHED: lockstep proxy waits for messages'},
    'physicalLimitations': ['Webots Nao H25 V5, not NAO6', 'Supervisor read-only ground truth, not vision localization',
        'Uncalibrated teaching mass, contact and motion parameters', 'Rolling deceleration is insufficient; no calibrated transfer of the 2D 0.4 m/s^2 estimate',
        'Tap maps to Shoot in 3D; only Kick validated here'],
    'preservedInterruptedAttempts': {'ros-online-01': 'FAIL exitCode -2 during user pause; ros-manual-01 receipt remains RUNNING; not PASS',
        'ros-online-02': 'Stale RUNNING command and absent final receipt after prior process disappearance; not PASS'},
    'manualGapsFoundInThisResume': [], 'historicalDocumentStatus': 'Pinned DEV_MANUAL retains its pre-final-archive line; parent owns final source documentation and archive updates.',
    'sourceIntegrity': {'HEADUnchanged': True, 'projectSourceChangedByReader': False,
        'modifiedTrackedOutputs': changed, 'ControllerCoreSHA256': sha(root / 'models/ControllerCore.slx'),
        'ControllerCoreMatchesBeforeManual': True},
    'processCleanup': cleanup, 'receiptSHA256': {str(path): sha(path) for path in inputs},
    'authorizationBoundary': 'No installation, push, PR, user desktop connection, or original project-source modification.'}
write_new(audit / 'FINAL_AUDIT.json', result)
print(json.dumps({'status': result['status'], 'finalAudit': str(audit / 'FINAL_AUDIT.json'),
    'manualCommandCount': len(commands), 'all22ManualFieldsExactlyEqual': True,
    'successfulManualCommandWallSeconds': result['successfulManualCommandWallSeconds']}, indent=2))
