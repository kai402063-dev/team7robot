"""Generate source line provenance from the immutable A snapshot."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1];base=root/'reference/projectA'
def locate(file,needle):
 return next(i for i,line in enumerate((base/file).read_text().splitlines(),1) if needle in line)
def length(file):return len((base/file).read_text().splitlines())
rows=[]
for name in ('goToPose','kickSkill','robotModel','ballModel','collisions','rulesCheck','angWrap','kickoffReset'):
 rows.append({'module':'tdp.'+name,'source':'reference/projectA/'+name+'.m','lines':[1,length(name+'.m')],'relation':'等价提取；踢球函数的噪声改为显式注入'})
team='teamBehaviour.m'
rows += [
 {'module':'tdp.roleAssignment','source':'reference/projectA/'+team,'lines':[locate(team,'gk    = find'),locate(team,'% ---------- goalkeeper')-1],'relation':'角色代价与前锋记忆'},
 {'module':'tdp.actionSelection','source':'reference/projectA/'+team,'lines':[locate(team,'% ---------- goalkeeper'),locate(team,'function a = mkGoto')-2],'relation':'按角色选择计划；动作结构构造函数紧随其后'},
 {'module':'tdp.laneClear','source':'reference/projectA/'+team,'lines':[locate(team,'function ok = laneClear'),length(team)],'relation':'线段距离检验'},
 {'module':'tdp.initialState / tdpTemplates','source':'reference/projectA/initState.m','lines':[1,length('initState.m')],'relation':'数值初态对应；类型总线为新设计'},
 {'module':'baseline.runA / MatchPlant2D / Plant2D','source':'reference/projectA/main_robocup2d.m','lines':[15,67],'relation':'无画面执行顺序对应；环境分层为新设计'},
 {'module':'TeamCoordinator','source':'reference/projectA/teamBehaviour.m','lines':[1,locate(team,'function a = mkGoto')-2],'relation':'拆分角色与计划；两份延迟记忆为新设计'},
 {'module':'Contact2D / Referee2D','source':'reference/projectA/collisions.m + rulesCheck.m','lines':[],'relation':'按配置启用修复；先运行原缺陷复现测试'},
 {'module':'Observation2D / ObservationChannel / CoreGeometry / EmitRequest / Actuator2D','source':'本次新设计','lines':[],'relation':'新接口与时序设计，不继承 B 行为'},
 {'module':'ControllerCore / learning charts','source':'B soccerRobotLib.slx (SoccerBehavior), examples/soccer/datatypes/*.m','lines':[],'relation':'仅参考状态图/总线/枚举组织，阶段逻辑为新设计'},
 {'module':'Viewer2D','source':'reference/projectA/viewer.m','lines':[],'relation':'只参考显示约定，离线日志渲染为新设计'}]
# The supplied viewer name may differ; report the actual available file.
for r in rows:
 if r['module']=='Viewer2D':
  candidates=[p for p in (base/'initGraphics.m',base/'updateGraphics.m') if p.exists()];r['source']=', '.join(str(p.relative_to(root)) for p in candidates) or 'New log-only renderer'
text=['# 源码对应行（脚本生成）','','A 快照不可变；行号包含注释。B 的 SLX 用内部组件路径，不虚构文本行号。','','| 新模块 | 来源文件 | 原源码行 | 关系 |','|---|---|---|---|']
for r in rows:text.append('| '+r['module']+' | '+r['source']+' | '+('–'.join(map(str,r['lines'])) if r['lines'] else '新设计/二进制组件，见关系列')+' | '+r['relation']+' |')
(root/'docs/generated/source_map.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(root/'docs/generated/source_map.md').write_text('\n'.join(text)+'\n')
