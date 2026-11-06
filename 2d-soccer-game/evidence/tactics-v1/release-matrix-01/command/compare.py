"""Compare saved numerical matrices for every release and original seeded match."""
from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys
import numpy as np
from scipy.io import loadmat


def read(path):
    return json.loads(path.read_text())


def require(condition, explanation):
    if not condition:
        raise ValueError(explanation)


def data_hash(matrix):
    data=np.ascontiguousarray(matrix,dtype='<f8')
    return sha256(memoryview(data).cast('B')).hexdigest()


def file_hash(path):
    hasher=sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1<<20), b''):
            hasher.update(block)
    return hasher.hexdigest()


def key(match):
    return (round(match['period']*1000), match['seed'])


def compare(current, original, previous_shipped, log_dir):
    current_summary=read(current/'summary/receipt.json')
    original_summary=read(original/'summary/receipt.json')
    original_worker=read(original/'matches/receipt.json')
    commit=current_summary['revision']
    revision=original_summary['revision']
    require(current_summary['status']==original_summary['status']=='PASS_40_V1_MATCHES','Incomplete full matrix')
    require(current_summary['periods']==original_summary['periods'],'Summary metrics differ')
    require(original_summary['officialMatches']==current_summary['officialMatches']==40,'Wrong game count')
    old={key(m):m for m in original_summary['matches']}
    new={key(m):m for m in current_summary['matches']}
    require(set(old)==set(new)=={(ms,seed) for ms in (50,40) for seed in range(1,21)},'Incomplete pairs')
    original_root=Path(original_worker['executionRoot'])
    previous=read(previous_shipped/'source-before.json')
    all_previous=read(original/'matches/source-before.json')
    require(original_summary['sourceFingerprint']==all_previous['fingerprint'],'Broken original manifest')
    require(all_previous==read(original/'matches/source-after.json'),'Original source drift')
    require(previous['revision']==revision,'Previous shipped model has a different revision')
    require(previous==read(previous_shipped/'source-after.json'),'Previous shipped source drift')
    cases=[]
    workers={}
    replay_steps=0
    differences={}
    for ms in (50,40):
        shard=current/f'matches-{ms}ms'
        worker=read(shard/'receipt.json')
        cmd=read(log_dir/str(ms)/'command.json')
        require(cmd['status']=='PASS' and cmd['exitCode']==0 and cmd['cleanAtStart'] and not cmd['rebuild'],'Bad MATLAB batch exit or rebuild')
        require(cmd['revision']==commit and worker['revision']==commit and worker['completedMatches']==20, 'Unexpected worker revision or count')
        src=read(shard/'source-before.json')
        require(src==read(shard/'source-after.json'),'Source drift during release rerun')
        require(src['revision']==commit and src['fingerprint']==current_summary['sourceFingerprint'],'Release source fingerprint disagreement')
        root=Path(worker['executionRoot'])
        require(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root).strip(),'Release clone tracked tree differs')
        require(src['files'].keys()==previous['files'].keys(),'Inconsistent source-file scope')
        differences={name:{'before':previous['files'][name],'after':digest}
                     for name,digest in src['files'].items() if previous['files'][name]!=digest}
        require(set(differences)=={'environment/LiveViewer2D.m'},'Runtime file differences go beyond the live viewer')
        for name,digest in src['files'].items():
            blob=subprocess.check_output(['git','show',f'{commit}:{name}'],cwd=root)
            require(sha256(blob).hexdigest()==digest,f'Run source differs from released git blob: {name}')
        workers[ms]={'sourceFingerprintBefore':src['fingerprint'],'sourceFingerprintAfter':src['fingerprint'],
                     'commit':commit,'cacheId':cmd['cacheId'],'startedAtUtc':cmd['startedAtUtc'],
                     'finishedAtUtc':cmd['finishedAtUtc'],'elapsedSeconds':cmd['elapsedSeconds'],
                     'completedMatches':worker['completedMatches'],'batchExitCode':cmd['exitCode']}
        for seed in range(1,21):
            case=f'dt{ms:02d}-seed{seed:02d}'
            original_dir=original/'matches'/case
            release_dir=shard/case
            a=read(original_dir/'receipt.json')
            b=read(release_dir/'receipt.json')
            require(a['parameters']==b['parameters'] and a['status']==b['status']=='PASS' and
                    a['metrics']==b['metrics'],f'Run parameters/status/per-step metric mismatch: {case}')
            if seed==1:
                require(a['replay']==b['replay'] and b['replay']['samePhysicalTrace'] and
                        b['replay']['sameTacticalTrace'],f'Full additional replay mismatch: {case}')
                replay_steps+=b['replay']['steps']
            paths=[original_root/a['artifact'],root/b['artifact']]
            metadata=[read(d/'artifact.json') for d in [original_dir,release_dir]]
            for path,record in zip(paths,metadata):
                require(record['sha256']==file_hash(path),f'MAT SHA mismatch: {path}')
            arrays=[loadmat(path,variable_names=['trace','tactics']) for path in paths]
            outcomes={}
            for name,width in [('trace',98),('tactics',171)]:
                left,right=[z[name] for z in arrays]
                expected_shape=(round(600/(ms/1000)),width)
                require(left.shape==right.shape==expected_shape,f'{case} {name} dimension mismatch')
                require(left.dtype==right.dtype==np.float64 and np.array_equal(left,right),f'{case} {name} element mismatch')
                actual_digests=[data_hash(z) for z in (left,right)]
                logged_digests=[v['arrays'][name]['sha256LittleEndianDoublesRowMajor'] for v in metadata]
                require(actual_digests==logged_digests and actual_digests[0]==actual_digests[1],f'{case} {name} digest mismatch')
                outcomes[name]={'dimensions':list(left.shape),'originalSha256':actual_digests[0],
                                'releaseSha256':actual_digests[1],'elementwiseEqual':True}
            cases.append({'seed':seed,'periodSeconds':ms/1000,'steps':b['metrics']['steps'],'arrays':outcomes})
            del arrays,left,right
    require(replay_steps==27000 and sum(m['steps'] for m in cases)==540000,'Incomplete time coverage')
    return {'status':'PASS','releaseRevision':commit,'originalRevision':revision,
            'releaseSourceFingerprint':current_summary['sourceFingerprint'],
            'priorShippedSourceFingerprint':previous['fingerprint'],
            'originalRebuiltSourceFingerprint':original_summary['sourceFingerprint'],
            'changedLiveRuntimeSourcesAgainstPriorShipped':differences,
            'allReleaseRuntimeFilesMatchCommittedBlobs':True,
            'matchesCompared':len(cases),'officialStepsCompared':540000,'wholeMatricesCompared':80,
            'physicalAndTacticalMatchedAtEveryStep':True,'fullSeedOneReplays':2,
            'extraReplaySteps':replay_steps,'workers':workers,'pairs':cases}


if __name__=='__main__':
    p=ArgumentParser()
    for field in ('current','original','previous_shipped','command_dir','destination'):
        p.add_argument(field,type=Path)
    args=p.parse_args()
    try:
        result=compare(args.current,args.original,args.previous_shipped,args.command_dir)
    except Exception as error:
        result={'status':'FAIL','message':repr(error)}
    with args.destination.open('x') as f:
        json.dump(result,f,ensure_ascii=False,indent=2)
        f.write('\n')
    print(result['status'], result.get('message',result.get('matchesCompared')))
    sys.exit(0 if result['status']=='PASS' else 1)
