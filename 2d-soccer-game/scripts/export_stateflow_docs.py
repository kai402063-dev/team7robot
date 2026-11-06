"""Extract actual chart text/priorities from the generated model archive."""
from pathlib import Path
import zipfile,xml.etree.ElementTree as E,json
root=Path(__file__).resolve().parents[1]
with zipfile.ZipFile(root/'models/ControllerCore.slx') as z:
 for f in z.namelist():
  if not f.startswith('simulink/stateflow/chart_') or not f.endswith('.xml'):continue
  e=E.fromstring(z.read(f));states={}
  for s in e.iter('state'):
   label=s.find("P[@Name='labelString']")
   if label is not None:states[s.get('SSID')]=label.text
  if not any(s.startswith('Active') for s in states.values()):continue
  transitions=[]
  for t in e.iter('transition'):
   def val(x):
    p=t.find(x);return p.text if p is not None else ''
   transitions.append({'source':states.get(val("src/P[@Name='SSID']"),'DEFAULT').split('\n')[0], 'destination':states.get(val("dst/P[@Name='SSID']"),'').split('\n')[0], 'priority':val("P[@Name='executionOrder']"), 'text':val("P[@Name='labelString']")})
  result={'states':states,'transitions':transitions}
  (root/'docs/generated/stateflow.json').write_text(json.dumps(result,indent=2)+'\n')
  lines=['# 从 ControllerCore.slx 提取的完整状态文本','']
  for s in states.values():lines += ['```matlab',s,'```','']
  lines += ['| 起点 | 终点 | 优先级 | 条件 / 动作 |','| --- | --- | --- | --- |']
  for i,t in enumerate(transitions,1):lines.append('| '+t['source']+' | '+t['destination']+' | '+t['priority']+' | [T'+str(i)+'](#t'+str(i)+') |')
  lines += ['', '复制下面代码块中的原文；表格只负责索引和优先级，避免竖线转义破坏 MATLAB 条件。', '']
  for i,t in enumerate(transitions,1):lines += ['### T'+str(i), '', t['source']+' → '+t['destination']+'；优先级 '+t['priority'], '', '```matlab', t['text'], '```', '']
  (root/'docs/generated/stateflow.md').write_text('\n'.join(lines)+'\n')
  print('Exported',len(states),'states and',len(transitions),'transitions')
