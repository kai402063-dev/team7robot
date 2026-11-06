"""Read geometric primitives from the actual group world, not its README."""
import hashlib
import json
import re
from pathlib import Path


def node(text,name):
    start=text.index('DEF '+name+' ');left=text.index('{',start);depth=1;pos=left+1
    while depth:
        if text[pos]=='{':depth+=1
        elif text[pos]=='}':depth-=1
        pos+=1
    return text[start:pos]


def vector(text,field):
    return [float(v) for v in re.search(r'\b'+field+r'\s+([-+0-9.eE]+\s+[-+0-9.eE]+\s+[-+0-9.eE]+)',text)[1].split()]


def dimensions(path):
    text=Path(path).read_text();items={name:node(text,name) for name in
       ['Grass','SouthLine','NorthLine','LeftLine','RightLine','LeftPostSouth','LeftPostNorth','LeftBar']}
    p={k:vector(v,'translation') for k,v in items.items()};size={k:vector(v,'size') for k,v in items.items()}
    result={'pitchLength':p['RightLine'][0]+size['RightLine'][0]/2-p['LeftLine'][0]+size['LeftLine'][0]/2,
            'pitchWidth':p['NorthLine'][1]+size['NorthLine'][1]/2-p['SouthLine'][1]+size['SouthLine'][1]/2,
            'goalClearWidth':p['LeftPostNorth'][1]-size['LeftPostNorth'][1]/2-p['LeftPostSouth'][1]-size['LeftPostSouth'][1]/2,
            'goalClearHeight':p['LeftBar'][2]-size['LeftBar'][2]/2,
            'grassSize':size['Grass'],'groundZ':p['Grass'][2]+size['Grass'][2]/2,
            'basicTimeStepMs':float(re.search(r'\bbasicTimeStep\s+([0-9.]+)',text)[1]) if re.search(r'\bbasicTimeStep\s+([0-9.]+)',text) else None,
            'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    for key,expected in [('pitchLength',9),('pitchWidth',6),('goalClearWidth',2.6),('goalClearHeight',1.2),('groundZ',0)]:
        assert abs(result[key]-expected)<1e-12,(key,result[key],expected)
    return result

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('world');p.add_argument('--output');a=p.parse_args()
    result=dimensions(a.world);text=json.dumps(result,indent=2)+'\n'
    if a.output:Path(a.output).write_text(text)
    print(text)
