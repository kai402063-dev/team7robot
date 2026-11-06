"""Independently check per-step completion, kick, and role signals in saved MAT files."""
from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
import numpy as np
from scipy.io import loadmat


def load(path):
    return json.loads(path.read_text())


def checked(value, message):
    if not value:
        raise AssertionError(message)


def check_match(mat_path, receipt):
    matrices = loadmat(mat_path, variable_names=['trace','tactics'])
    trace = matrices['trace']
    tactics = matrices['tactics']
    p = receipt['parameters']
    key = (p['dt'], p['seed'])
    checked(trace.shape == (round(600/p['dt']), 98), f'{key} physical steps')
    checked(tactics.shape == (trace.shape[0],171), f'{key} tactical steps or schema')
    checked(np.all(np.diff(trace[:,60])>0), f'{key} time')
    # Public columns are documented in scripts/v1TraceColumns.m (1-based).
    statuses = tactics[:,63:71]
    feedback_ids = tactics[:,71:79]
    actual_kicker = tactics[:,14]
    fresh_done = np.zeros(statuses.shape, dtype=bool)
    for robot in range(8):
        interested = np.flatnonzero(statuses[:,robot] == 2)  # Done
        ids = feedback_ids[interested,robot]
        checked((ids>0).all(),f'{key} Done has no ID')
        _, first = np.unique(ids,return_index=True)
        fresh_done[interested[first],robot] = True
    physical = actual_kicker[:,None] == np.arange(1,9)
    checked(np.array_equal(physical, fresh_done), f'{key} new Done events differ from actual physics')
    checked(np.max(fresh_done.sum(axis=1))<=1,f'{key} multiple physical completions in one tick')
    checked(np.all(trace[:,48:56] == np.tile([1,3,5,2],2)), f'{key} identity')
    valid = tactics[:,15:23].astype(bool) & tactics[:,13,None].astype(bool)
    target_x, target_y = tactics[:,87:95], tactics[:,95:103]
    intents = tactics[:,31:39]
    keeper_samples, defender_samples, support_samples = 0, 0, 0
    initial_striker_x = np.array([-1.,1.]) # Existing kickoffReset: local number 4.
    st_x = np.vstack([initial_striker_x, trace[:-1,[3,7]]])
    for team, direction in enumerate(p['dirSign']):
        gk,df,mf,st = [team*4+i for i in range(4)]
        defending = valid[:,df]
        guarding = valid[:,gk]
        checked((intents[guarding,gk]==1).all(),f'{key} keeper guard request')
        checked(np.allclose(target_x[guarding,gk],direction*(-p['L']/2+p['v1KeeperInset']),rtol=0,atol=1e-12),f'{key} keeper line')
        checked((abs(target_y[guarding,gk])<=p['goalW']/2-p['robotR']+1e-12).all(),f'{key} keeper bounds')
        checked((intents[defending,df]==1).all() and (direction*target_x[defending,df]<0).all(),f'{key} defender crossed into attack')
        supporting = (valid[:,mf] & valid[:,st] & (tactics[:,1+team]==2)
                      & (tactics[:,5+team]==st+1))
        expected_x = np.clip(st_x[:,team]-direction*p['v1SupportTrail'], -p['L']/2+p['robotR'], p['L']/2-p['robotR'])
        checked((intents[supporting,mf]==1).all() and np.allclose(target_x[supporting,mf],expected_x[supporting],rtol=0,atol=1e-12),f'{key} support depth')
        keeper_samples += guarding.sum()
        defender_samples += defending.sum()
        support_samples += supporting.sum()
    touches=np.flatnonzero(trace[:,63]>0)
    kicks=np.flatnonzero(actual_kicker>0)
    return {'period':p['dt'],'seed':p['seed'],'steps':len(trace),
            'firstTouchTeam':int(trace[touches[0],63]) if len(touches) else None,
            'firstPhysicalKicker':int(actual_kicker[kicks[0]]) if len(kicks) else None,
            'firstPhysicalKickSeconds':float(trace[kicks[0],60]) if len(kicks) else None,
            'newDoneMatchesPhysicalKickAtEveryStep':True,'uniquePhysicalKicks':int(physical.sum()),
            'keeperGuardSamplesChecked':int(keeper_samples),'defenderLineSamplesChecked':int(defender_samples),
            'midfielderSupportSamplesChecked':int(support_samples)}


def main(evidence, preflight):
    matrix = load(evidence/'summary/receipt.json')
    checked(matrix['status']=='PASS_40_V1_MATCHES','matrix summary incomplete')
    worker=load(evidence/'matches/receipt.json')
    root=Path(worker['executionRoot'])
    common=set()
    rows=[]
    for path in sorted((evidence/'matches').glob('dt*-seed*/receipt.json')):
        receipt=load(path)
        p=receipt['parameters']
        checked(p['v1Enabled'] and p['mode']=='Delayed' and p['rulesProfile']=='CourseSimplified' and p['kickNoise']>0,'unexpected configuration')
        common.add(json.dumps({k:v for k,v in p.items() if k not in ('dt','seed')},sort_keys=True))
        rows.append(check_match(root/receipt['artifact'],receipt))
    checked(len(rows)==40 and len(common)==1,'matrix differs in more than seed and period')
    before = load(preflight/'dt50-seed01/artifact.json')
    after = load(evidence/'matches/dt50-seed01/artifact.json')
    key='sha256LittleEndianDoublesRowMajor'
    comparison={name:before['arrays'][name][key]==after['arrays'][name][key] for name in ('trace','tactics')}
    result={'status':'PASS','matches':len(rows),'configurationVariesOnlyIn':['dt','seed'],
            'commonConfigurationSha256':sha256(next(iter(common)).encode()).hexdigest(),
            'seedOne50msPreflightMatchesRebuiltModel':comparison,
            'preflightScope':'Historical preflight had a source-drift failure. Only the numeric array digests are compared.',
            'totals':{key:sum(r[key] for r in rows) for key in ('steps','uniquePhysicalKicks','keeperGuardSamplesChecked','defenderLineSamplesChecked','midfielderSupportSamplesChecked')},
            'rows':rows}
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=ArgumentParser()
    parser.add_argument('matrix',type=Path)
    parser.add_argument('preflight',type=Path)
    args=parser.parse_args()
    main(args.matrix,args.preflight)
