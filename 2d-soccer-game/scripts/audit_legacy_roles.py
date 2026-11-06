"""Measure role switches in the archived legacy traces; no simulation runs here."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]


def audit(output):
    destination = Path(output)
    destination.mkdir(parents=True, exist_ok=False)
    archive = json.loads((ROOT / 'evidence/3/FINAL_RECEIPT.json').read_text())
    runs = []
    for entry in archive['artifacts']:
        path = ROOT / entry['path']
        digest = sha256(path.read_bytes()).hexdigest()
        assert digest == entry['sha256'], 'This audit expects the exact archived MAT file.'
        trace = loadmat(path, variable_names=['b'])['b']
        assert trace.shape[1] == 98 and np.isfinite(trace).all()
        # MatchRecord columns 49:56 store the eight public roles.
        roles = trace[:, 48:56].astype(int)
        changed = np.diff(roles, axis=0) != 0
        indices = np.flatnonzero(np.any(changed, axis=1)) + 1
        first = int(indices[0]) if len(indices) else None
        runs.append({'path': entry['path'], 'sha256': digest, 'steps': len(trace),
                     'periodSeconds': round(float(trace[1, 60] - trace[0, 60]), 10),
                     'lastTimeSeconds': float(trace[-1, 60]),
                     'roleChangeSteps': len(indices),
                     'changesPerRobot': changed.sum(axis=0).tolist(),
                     'firstChangeStepOneBased': first + 1 if first is not None else None,
                     'firstChangeTimeSeconds': float(trace[first, 60]) if first is not None else None,
                     'rolesBeforeFirst': roles[first - 1].tolist() if first is not None else [],
                     'rolesAfterFirst': roles[first].tolist() if first is not None else []})
    result = {'status': 'LEGACY_TRACES_ANALYZED', 'v1Implemented': False,
              'v1Validation': 'NOT_RUN', 'profile': 'CourseSimplified rules, legacy A tactics, seed 13',
              'roleCode': {'1': 'GK', '2': 'ST', '3': 'DF', '4': 'SP'}, 'runs': runs}
    (destination / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output')
    audit(parser.parse_args().output)
