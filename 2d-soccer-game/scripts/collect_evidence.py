"""Archive immutable small evidence; keep hashes for larger artifacts."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

def collect(source,destination):
    source=Path(source).resolve();destination=Path(destination).resolve()
    destination.mkdir(parents=True,exist_ok=False);manifest=[]
    for path in sorted(source.rglob('*')):
        if not path.is_file() or path.is_symlink():continue
        data=path.read_bytes();relative=path.relative_to(source)
        keep=len(data)<=1048576
        if keep:
            target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
        manifest.append({'path':str(relative),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'retained':keep})
    (destination/'ARCHIVE_MANIFEST.json').write_text(json.dumps({'source':str(source),'largeThresholdBytes':1048576,'files':manifest},indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('destination');a=p.parse_args();collect(a.source,a.destination)
