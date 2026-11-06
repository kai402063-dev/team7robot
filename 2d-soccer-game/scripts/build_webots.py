"""Derive a single-robot scene, preserving all group pitch geometry."""
import hashlib
import os
import json
from pathlib import Path
import shutil
from check_pitch import dimensions
ROOT=Path(__file__).resolve().parents[1]
NAO=Path(os.environ.get('TDP_WEBOTS_HOME','/home/fayne/.ros/webotsR2025a/webots'))/'projects/robots/softbank/nao'
URL='https://raw.githubusercontent.com/cyberbotics/webots/R2025a/projects/robots/softbank/nao/protos/Nao.proto'

def build():
    c=json.loads((ROOT/'config/webots.json').read_text())
    assert c['basicTimeStepMs']==20 and c['controlPeriodSeconds']==.04,'This baseline requires 20/40 ms timing'
    source=ROOT/'reference/kidsize_pitch.wbt';before=dimensions(source)
    text=source.read_text().replace('#VRML_SIM R2025a utf8','#VRML_SIM R2025a utf8\n\nEXTERNPROTO "'+URL+'"',1)
    text=text.replace('DEF Settings WorldInfo {',f'DEF Settings WorldInfo {{\n  basicTimeStep 20\n  contactProperties [\n    ContactProperties {{ material1 "NAO foot material" coulombFriction [ {c["footFriction"]} ] bounce {c["footBounce"]} bounceVelocity {c["footBounceVelocityMetresPerSecond"]} }}\n  ]',1)
    robot=' '.join(map(str,c['robotInitialPosition']));ball=' '.join(map(str,c['ballInitialPosition']))
    text+=f'''\nDEF TDP_BALL Solid {{
  translation {ball}
  children [ Shape {{ appearance PBRAppearance {{ baseColor 1 0.35 0 roughness 0.8 metalness 0 }} geometry Sphere {{ radius {c['ballRadiusMetres']} }} }} ]
  name "tdp_ball"
  boundingObject Sphere {{ radius {c['ballRadiusMetres']} }}
  physics Physics {{ density -1 mass {c['ballMassKg']} }}
}}
DEF TDP_NAO Nao {{
  translation {robot}
  rotation 0 0 1 0
  version "V5 (red)"
  name "tdp_nao_v5"
  controller "tdp_webots_bridge"
  supervisor TRUE
  synchronization TRUE
  cameraWidth {c['cameraWidth']}
  cameraHeight {c['cameraHeight']}
}}
'''
    target=ROOT/'webots/worlds/tdp_single.wbt';target.write_text(text)
    after=dimensions(target);assert after['basicTimeStepMs']==20
    manifest=[]
    for name in ['Forwards','Forwards50','Backwards','SideStepLeft','SideStepRight','TurnLeft40','TurnRight40','Shoot']:
        src=NAO/'motions'/f'{name}.motion';dst=ROOT/'webots/motions'/src.name
        shutil.copy2(src,dst);rows=src.read_text().splitlines();last=rows[-1].split(',')[0]
        m,s,ms=map(int,last.split(':'));duration=60*m+s+ms/1000
        manifest.append({'name':src.name,'source':str(src),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'durationSeconds':duration})
    (ROOT/'webots/motions/SOURCES.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'docs/generated/pitch_dimensions.json').write_text(json.dumps({'source':before,'derived':after},indent=2)+'\n')
    return after

if __name__=='__main__':print(json.dumps(build(),indent=2))
