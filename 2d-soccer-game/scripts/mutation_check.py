"""Run a real source mutation in an isolated task-owned copy, never the oracle."""
import json,os,shutil,subprocess,sys,time,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=json.loads(Path(sys.argv[1]).read_text())
if len(sys.argv)>2:
    suffix=sys.argv[2];assert re.fullmatch(r'[A-Za-z0-9_-]+',suffix)
    spec['id']+='-'+suffix;spec['evidence']='build/mutations/'+suffix+'/'+spec['id']
out=root/spec['evidence'];out.mkdir(parents=True,exist_ok=False)
clone=root/'build'/('mutation-'+spec['id']);assert not clone.exists()
shutil.copytree(root,clone,ignore=shutil.ignore_patterns('.git','build','robot-soccer-starter'))
source=clone/spec['file'];text=source.read_text();assert spec['old'] in text
source.write_text(text.replace(spec['old'],spec['new'],1))
(clone/'build').mkdir();env=os.environ.copy()
for k in ['LD_LIBRARY_PATH','LD_PRELOAD','DISPLAY','MATLAB_JAVA']:env.pop(k,None)
env['MATLAB_PREFDIR']=str(clone/'build/prefs')
code="tdpSetup;"+spec.get("setup", "")+"r=runtests('"+spec['suite']+"');writeJson('build/results.json',struct('names',{{r.Name}},'passed',[r.Passed],'failed',[r.Failed],'incomplete',[r.Incomplete]));"
with (out/'matlab.log').open('w') as log:
 p=subprocess.run(['/home/fayne/Applications/MATLAB/R2026b/bin/matlab','-batch',code],cwd=clone,env=env,stdout=log,stderr=subprocess.STDOUT)
result=json.loads((clone/'build/results.json').read_text()) if (clone/'build/results.json').exists() else {}
failed=result.get('failed',[]);failed=[failed] if isinstance(failed,bool) else failed
names=result.get('names',[])
incomplete=result.get('incomplete',[]);incomplete=[incomplete] if isinstance(incomplete,bool) else incomplete
receipt={'spec':spec,'exitCode':p.returncode,'results':result,'detected':p.returncode==0 and any(f and not i for f,i in zip(failed,incomplete))}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt));assert receipt['detected'],'Mutation was not detected by assertions'
