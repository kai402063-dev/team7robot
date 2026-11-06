"""Check local manual links, executable test names, and copyable chart text."""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1];errors=[]
for file in (root/'docs').rglob('*.md'):
 text=file.read_text()
 for link in re.findall(r'\]\(([^)]+)\)',text):
  if link.startswith(('https:','http:','#')):continue
  if not (file.parent/link.split('#')[0]).exists():errors.append([str(file.relative_to(root)),'missing link',link])
 for suite,test in re.findall(r'(test_\w+)/(test\w+)',text):
  source=root/'tests'/(suite+'.m')
  if not source.exists() or not re.search(r'function '+re.escape(test)+r'\(',source.read_text()):errors.append([str(file.relative_to(root)),'missing test',suite+'/'+test])
chart=(root/'docs/generated/stateflow.md').read_text()
if '&#124;' in chart:errors.append(['stateflow.md','non-copyable pipe entity'])
print(json.dumps({'errors':errors},ensure_ascii=False,indent=2));assert not errors
