"""Hash immutable task inputs; file contents and relative paths are included."""
import hashlib,json,sys
from pathlib import Path
BASE=Path('/home/fayne/Alpha/humanoid_football_robot')
INPUTS={
'projectA':Path('/home/fayne/Documents/Robotics & AI/Robotics TDP/robocup2d'),
'projectB':BASE/'work/robot-soccer-starter',
'motionSafe':BASE/'work/tdp-motion-safe-r1',
'motionEvidence':BASE/'verification/tdp-motion-safe-r1',
'pitch':BASE/'work/team7robot/kidsize_pitch.wbt',
'course':BASE/'Resource',
'specification':BASE/'reports/tdp_modeling_specification_2026_2027.md',
'parameters':BASE/'reports/tdp_modeling_parameters_2026_2027.json',
'analysis':BASE/'reports/manual_migration_course',
'naoMotion':BASE/'reports/research/nao6_motion.md',
'naoHardware':BASE/'reports/research/nao6_hardware.md',
'naoReference':Path('/home/fayne/.ros/webotsR2025a/webots/projects/robots/softbank/nao'),
'rosTurtlebot':Path('/opt/ros/jazzy/share/webots_ros2_turtlebot'),
'rosEpuck':Path('/opt/ros/jazzy/share/webots_ros2_epuck')}
def snapshot():
 result={}
 for key,root in INPUTS.items():
  files={}
  for f in sorted(root.rglob('*')) if root.is_dir() else [root]:
   if f.is_file():
    h=hashlib.sha256()
    with f.open('rb') as stream:
     for chunk in iter(lambda:stream.read(1048576),b''):h.update(chunk)
    files[str(f.relative_to(root)) if root.is_dir() else f.name]=h.hexdigest()
  digest=hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()
  result[key]={'path':str(root),'files':files,'sha256':digest}
 return result
if __name__=='__main__':
 out=Path(sys.argv[1]); assert not out.exists(), 'Refuse to overwrite evidence'
 result=snapshot();out.write_text(json.dumps(result,indent=2)+'\n')
 for k,v in result.items():print(k,len(v['files']),v['sha256'])
 if len(sys.argv)>2:
  old=json.loads(Path(sys.argv[2]).read_text());assert result==old,'READONLY INPUTS CHANGED'
  print('READONLY_INPUT_HASHES_IDENTICAL')
