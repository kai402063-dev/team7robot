"""Check terminal receipts before closing this local V1 validation attempt."""
from pathlib import Path
from hashlib import sha256
import json, subprocess
root = Path(__file__).resolve().parents[3]
base = root / 'evidence/tactics-v1'
paths = {}

def read(key, path):
    p = base / path
    data = p.read_bytes()
    paths[key] = {'file': str(path), 'sha256': sha256(data).hexdigest()}
    return json.loads(data)

def write(path, value):
    with path.open('x') as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write('\n')
viewer, launcher = ('viewer-02', 'launcher-02')
matrix = read('matrix', 'matrix-final-01/receipt.json')
summary = read('summary', 'matrix-final-01/summary/receipt.json')
outer = read('matlabCommand', 'matrix-final-01/command/command.json')
independent = read('perStepAudit', 'matrix-final-01/independent-audit.json')
assert matrix['status'] == 'PASS' and outer['exitCode'] == 0 and outer['cleanAtStart']
assert matrix['officialMatches'] == len(summary['matches']) == independent['matches'] == 40
assert matrix['testCount'] == 25 and matrix['totalOfficialSteps'] == independent['totals']['steps'] == 540000
assert len({(r['period'], r['seed']) for r in summary['matches']}) == 40
assert summary['additionalFullSeedOneReplays'] == 2
release = read('releaseMatrix', 'release-matrix-01/receipt.json')
assert release['status'] == 'PASS' and release['matchesCompared'] == 40 and (release['wholeMatricesCompared'] == 80)
assert release['physicalAndTacticalMatchedAtEveryStep'] and release['allReleaseRuntimeFilesMatchCommittedBlobs']
assert release['extraReplaySteps'] == 27000 and release['fullSeedOneReplays'] == 2
assert release['originalRevision'] == outer['sourceCommit']
rebuilt = read('shippedVsRebuilt', 'prebuilt-rebuild-01/receipt.json')
assert rebuilt['status'] == 'PASS' and rebuilt['additionalMatchesOutsideOfficialMatrix'] == 2
assert all((v['arrayEqual'] and v['maxAbsDifference'] == 0 for row in rebuilt['matches'] for v in row['arrays'].values()))
for role, directory in {
    'team': 'mutation-plans-01',
    'model': 'model-mutation-02',
    'matrix': 'mutation-matrix-01',
    'pause': 'mutation-pause-01',
}.items():
    mutation = read('mutation-' + role, directory + '/receipt.json')
    results = mutation['results']
    assert mutation['detected'] and mutation['exitCode'] == 0
    assert any(results['failed']) and not any(results['incomplete'])

legacy = read('ACompat', 'legacy-01/receipt.json')
assert legacy['status'] == 'PASS' and legacy['sameGoalsShotsFirstTouch'] == 40
reader = read('firstTimeReader', 'reader-01/receipt.json')
assert reader['status'].startswith('PASS') and reader['cloneCleanBeforeAndAfter']
assert read('handson', 'handson-01/receipt.json')['status'] == 'PASS'
manual = read('manualNumbers', 'manual-final-02/receipt.json')
assert manual['status'] == 'PASS' and all(manual['passed'])
structure = read('modelStructure', 'model-structure-01/receipt.json')
assert structure['status'] == 'PASS' and len(structure['cores']) == 8 and (len(structure['unitDelays']) == 5)
controls = read('interactiveDisplay', viewer + '/artifacts/receipt.json')
assert controls['status'] == 'PASS' and all(controls['tests']['passed']) and controls['closedDuringRun']
assert controls['controls']['pausedTime'] == controls['controls']['frozenTime']
assert read('displayCommand', viewer + '/command.json')['exitCode'] == 0
launch = read('releaseLauncher', launcher + '/receipt.json')
assert launch['status'] == 'PASS' and launch['fixedRoles'] and launch['naturalExitAfterClose'] and (launch['exitCode'] == 0)
assert read('observedMotion', launcher + '/recorded-motion.json')['robotsMoving'] == 8
assert read('sourceDriftRehearsal', 'matrix-longcheck-01/receipt.json')['status'] == 'FAIL'
assert read('initialDisplayRegression', 'viewer-01/artifacts/receipt.json')['status'] == 'FAIL'
start = read('readOnlyStart', 'implementation/inputs-before.json')
end = read('readOnlyEnd', 'implementation/inputs-after.json')
assert start == end and len(end) == 14 and (sum((len(x['files']) for x in end.values())) == 818)
assert not read('manualLinkAudit', 'implementation/manual-audit.json')['errors']
assert not read('mutationAudit', 'implementation/mutation-audit.json')['missing']
for tag, expected in [('baseline-v1', '160e0226343ec1d82e5479a1ca0aa0f4a3e8c1bd'), ('baseline-2d-v1', '187bdaf53a8882e24eee0bdc5bff03f711a806bb')]:
    actual = subprocess.check_output(['git', 'rev-list', '-1', tag], cwd=root, text=True).strip()
    assert actual == expected, (tag, actual)
result = {
    'status': 'PASS_V1_2D',
    'branch': 'ai-migration-baseline',
    'originalExperimentRevision': summary['revision'],
    'releaseRuntimeRevision': release['releaseRevision'],
    'fullReleaseRechecks': release['matchesCompared'],
    'releaseArrayPairsMatched': release['wholeMatricesCompared'],
    'scope': 'Fixed-role V1, real 4v4 Simulink, headless and live. Separate nominal ACompat regression.',
    'modelsAndTacticsIndependentOfViewer': True,
    'officialMatches': 40,
    'totalOfficialSteps': 540000,
    'matchSeconds': 600,
    'distinctSeeds': 20,
    'periods': [0.05, 0.04],
    'headline': {
        'scoringMatches': sum((p['matchesWithGoal'] for p in summary['periods'])),
        'goals': sum((sum(p['goals']) for p in summary['periods'])),
        'shots': sum((sum(p['shots']) for p in summary['periods'])),
        'physicalKicks': independent['totals']['uniquePhysicalKicks'],
        'overlapSteps': sum((p['overlapSteps'] for p in summary['periods'])),
        'outsideBorderRobotSamples': sum((p['outsideBorderRobotSamples'] for p in summary['periods'])),
    },
    'matlabTestCases': matrix['testCount'],
    'officialElapsedWallSeconds': outer['elapsedSeconds'],
    'manualTestCasesPassed': len(manual['passed']),
    'legacyMatches': legacy['matches'],
    'extraSeed1ShippedModelRuns': 2,
    'extraSeed1Replays': 2,
    'immutableRootCount': len(end),
    'immutableFileCount': 818,
    'unresolved': [
        'Team-defined physical recovery signal for striker; explicit recovery injection used',
        '2D sensing, maximum speeds and rolling/contact parameters require physical validation',
        'Native ROS Toolbox and Coder integrations blocked by missing products; V1 tactics have not been exercised on a 3D or physical NAO',
    ],
    'receipts': paths,
}
final = base / 'FINAL_RECEIPT.json'
if final.exists():
    assert json.loads(final.read_text()) == result, 'Aggregate receipt differs from the recorded inputs'
else:
    write(final, result)
print(result['status'], result['headline'])
