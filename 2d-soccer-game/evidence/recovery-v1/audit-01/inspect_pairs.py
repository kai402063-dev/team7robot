"""Compare each pair until its first physical and tactical difference.

Usage: python3 inspect_pairs.py COMPARISON_RUN NEW_OUTPUT_JSON
Raw MAT files under the execution roots must still be available.
"""
import sys
import json
from pathlib import Path
import numpy as np
from scipy.io import loadmat
folder=Path(sys.argv[1])
roots={p:Path(json.loads((folder/p/'receipt.json').read_text())['executionRoot']) for p in ('v1','recovery')}
rows=[]
for receipt in sorted((folder/'v1').glob('dt*-seed*/receipt.json')):
    b=json.loads(receipt.read_text())
    e=json.loads((folder/'recovery'/receipt.parent.name/'receipt.json').read_text())
    orig=loadmat(roots['v1']/b['artifact'],variable_names=['trace','tactics'])
    exp=loadmat(roots['recovery']/e['artifact'],variable_names=['trace','tactics'])
    time=orig['tactics'][:,0]
    row={'case':receipt.parent.name}
    for field in ['trace','tactics']:
        mask=(orig[field]!=exp[field])
        idx=np.flatnonzero(np.any(mask,axis=1))
        if len(idx):
            k=idx[0]
            row[field]={'step':int(k+1),'time':float(time[k]),'columns1':(np.flatnonzero(mask[k])+1).tolist()}
    own=np.any((orig['tactics'][:,167:169]!=0)|(exp['tactics'][:,167:169]!=0),axis=1)
    first=np.flatnonzero(own)
    row['firstTakeoverSeconds']=float(time[first[0]]) if len(first) else None
    rows.append(row)
path=Path(sys.argv[2])
with path.open('x') as f:json.dump(rows,f,indent=2);f.write('\n')
print('first three:',rows[:3])
print('different before takeover:',sum(r['firstTakeoverSeconds'] is None or r['trace']['time']<r['firstTakeoverSeconds'] for r in rows))
