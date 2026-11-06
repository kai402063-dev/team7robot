"""Inspect executable B XML/MATLAB consumers, excluding declarations/docs."""
import json,re,zipfile,sys
import xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'robot-soccer-starter'
report={}
for parameter in ('robotDetectorFOV','wheelRadius'):
    hits=[]
    for file in sorted((base/'examples/soccer').rglob('*')):
        if file.suffix=='.m' and file.name!='robotSoccerParams.m':
            if re.search(r'\b'+parameter+r'\b',file.read_text()):hits.append(str(file.relative_to(root)))
        if file.suffix=='.slx':
            with zipfile.ZipFile(file) as archive:
                for name in archive.namelist():
                    if name.endswith('.xml'):
                        tree=ET.fromstring(archive.read(name))
                        for element in tree.iter('P'):
                            if element.text and re.search(r'\b'+parameter+r'\b',element.text):
                                hits.append(str(file.relative_to(root))+'!'+name+':'+str(element.attrib))
    report[parameter]={'consumers':hits,'conclusion':'UNUSED_IN_SOCCER_SOURCE' if not hits else 'REVIEW_REQUIRED'}
out=root/(sys.argv[1] if len(sys.argv)>1 else 'build/b-unused-parameters.json')
assert not out.exists();out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report));assert all(not x['consumers'] for x in report.values())
