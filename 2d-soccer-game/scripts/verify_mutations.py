"""Audit that each MATLAB test suite has a real assertion-detecting mutation."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1];qualified={}
for path in (root/'evidence').rglob('receipt.json'):
 if (path.parent/'NOT_QUALIFIED.json').exists():continue
 try:r=json.loads(path.read_text())
 except (ValueError,UnicodeError):continue
 if not r.get('detected') or 'spec' not in r:continue
 result=r.get('results',{});fail=result.get('failed',[]);incomplete=result.get('incomplete',[])
 if isinstance(fail,bool):fail=[fail]
 if isinstance(incomplete,bool):incomplete=[incomplete]
 if not any(incomplete) and any(fail):
  qualified[Path(r['spec']['suite']).name]=str(path.relative_to(root))
missing=[p.name for p in (root/'tests').glob('test_*.m') if p.name not in qualified]
print(json.dumps({'qualified':qualified,'missing':missing},indent=2));assert not missing
