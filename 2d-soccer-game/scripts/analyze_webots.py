"""Evaluate communication, actual motion, and ball displacement independently."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def analyze(folder):
    out=Path(folder);receipt=json.loads((out/'webots-receipt.json').read_text())
    rows=json.loads((out/'webots-records.json').read_text())
    config=json.loads((Path(__file__).resolve().parents[1]/'config/webots.json').read_text())
    assert receipt['error'] is None,'Controller process failure'
    assert len(rows)==config['controlFrames'],'Incomplete control recording'
    assert all(all(math.isfinite(v) for v in r['robot']+r['ball']+r['ballVelocity']) for r in rows),'Nonfinite world state'
    assert all(abs(rows[k]['time']-rows[k-1]['time']-.04)<1e-12 for k in range(1,len(rows))),'Incorrect control period'
    assert all(r['clockPublishers']==1 for r in rows),'Clock publisher count'
    assert 'Publisher count: 1' in (out/'clock-info.txt').read_text(),'Missing CLI clock evidence'
    assert receipt['duplicateDeliveries']>0,'No repeated requests exercised'
    starts=[e for e in receipt['events'] if e['event']=='motion_start']
    ends=[e for e in receipt['events'] if e['event']=='motion_end']
    assert starts and ends,'Motion did not complete'
    assert len(set(e['requestId'] for e in starts))==len(starts)==receipt['executions'],'Repeated physical execution'
    start=starts[0];end=next(e for e in ends if e['requestId']==start['requestId'])
    pre=max((r for r in rows if r['time']<=start['time']),key=lambda r:r['time'])
    post=min((r for r in rows if r['time']>=end['time']),key=lambda r:r['time'])
    distance0=math.dist(rows[0]['robot'][:2],rows[0]['ball'][:2]);distance_start=math.dist(pre['robot'][:2],pre['ball'][:2])
    moved=math.dist(pre['ball'][:2],post['ball'][:2])
    prior_speed=math.hypot(*pre['ballVelocity'][:2]);peak=max(math.hypot(*r['ballVelocity'][:2]) for r in rows if start['time']<=r['time']<=end['time'])
    assert distance_start<distance0-config['minimumApproachProgressMetres'],'No approach progress'
    assert moved>config['ballDisplacementThresholdMetres'],'Ball displacement gate'
    assert prior_speed<config['ballStationarySpeedTolerance'] and peak>config['ballMotionSpeedThreshold'],'Ball was already moving or did not accelerate during Shoot'
    assert all(r['upright'] for r in rows),'Robot fell'
    return {'status':'PASS_SINGLE_V5_CLOSED_LOOP','communication':'PASS: ROS observation/request/camera and one clock publisher',
            'motionExecution':'PASS: unique Shoot request reached its end','ballKicked':'PASS: initially still ball moved during physical Shoot',
            'modelValidation':'NOT_ESTABLISHED: V5 simulation, no NAO6 or real dynamics validation',
            'frames':len(rows),'initialDistanceMetres':distance0,'distanceAtShootMetres':distance_start,
            'requestId':start['requestId'],'motionStartSeconds':start['time'],'motionEndSeconds':end['time'],
            'motionDurationSeconds':end['time']-start['time'],'ballDisplacementMetres':moved,'ballEvaluationTimeSeconds':post['time'],
            'motionEventBallDisplacementMetres':math.dist(start['ball'],end['ball']),
            'ballSpeedBeforeMetresPerSecond':prior_speed,'ballPeakSpeedMetresPerSecond':peak,
            'extraDuplicateDeliveries':receipt['duplicateDeliveries'],'physicalExecutions':receipt['executions'],
            'clockPublishers':1,'allUpright':True,
            'traceSHA256':hashlib.sha256((out/'webots-records.json').read_bytes()).hexdigest()}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');p.add_argument('--output');a=p.parse_args()
    result=analyze(a.folder);text=json.dumps(result,indent=2)+'\n'
    if a.output:Path(a.output).write_text(text)
    print(text)
