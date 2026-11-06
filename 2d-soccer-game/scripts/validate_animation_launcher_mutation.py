"""Prove the launcher's environment assertions reject a known regression."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile

from validate_animation_launcher import ROOT, validate


def main(output):
    output=Path(output).resolve()
    output.mkdir(parents=True,exist_ok=False)
    (ROOT/'build').mkdir(exist_ok=True)
    fixture=Path(tempfile.mkdtemp(prefix='launcher-mutation-',dir=ROOT/'build'))
    source=ROOT/'start_2d.sh'
    original=source.read_text()
    before='exec env -u LD_LIBRARY_PATH -u LD_PRELOAD -u MATLAB_JAVA'
    after='exec env -u LD_LIBRARY_PATH -u LD_PRELOAD'
    assert original.count(before)==1, 'Mutation must change exactly one known line'
    mutant=fixture/'start_2d.sh'
    mutant.write_text(original.replace(before,after,1))
    mutant.chmod(0o755)
    passed=validate(mutant,output/'mutant-suite')
    suite=json.loads((output/'mutant-suite'/'receipt.json').read_text())
    failures=[row for row in suite['results'] if not row['passed']]
    killed=(not passed and len(failures)==1
            and failures[0]['name']=='valid_environment'
            and failures[0]['assertionFailure']
            and 'MATLAB_JAVA' in failures[0]['message'])
    receipt={'status':'PASS' if killed else 'FAIL',
             'mutation':'Keep inherited MATLAB_JAVA in the MATLAB environment',
             'originalSha256':hashlib.sha256(source.read_bytes()).hexdigest(),
             'mutantSha256':hashlib.sha256(mutant.read_bytes()).hexdigest(),
             'mutant':str(mutant),'detected':killed,
             'expectedFailure':'valid_environment: MATLAB_JAVA must not enter the new MATLAB process',
             'failures':failures,'scope':'Stub execution only; original launcher remains unchanged'}
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))
    return killed


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    raise SystemExit(0 if main(args.output) else 1)
