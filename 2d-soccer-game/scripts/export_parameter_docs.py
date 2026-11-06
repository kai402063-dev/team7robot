"""Generate a complete runtime parameter table and preserve all source nulls."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/generated'
config=json.loads((out/'config.json').read_text())
course=set('L W goalD goalW goalAreaL goalAreaW penMark centreD border penAreaL penAreaW nPerTeam'.split())
design=set('mode rulesProfile maxObservationAge walkValidity kickPreparation kickTimeout recoverTime alignEnter alignExit searchTurnRate fieldOfView observationDelay observationNoise fixedStriker freezeDuringPause contactIterations contactTolerance tapSpeed'.split())
units={}
for k in 'L W goalD goalW goalAreaL goalAreaW penMark centreD border penAreaL penAreaW ballR robotR avoidR ballAvoidR approachDist kickRange shootDist defDist alignEnter alignExit observationNoise restartOpponentDistance contactTolerance'.split():units[k]='m'
for k in 'vFwd vBack vSide stepInSpeed shotSpeed dribbleSpeed maxKickSpeed tapSpeed'.split():units[k]='m/s'
for k in 'dt Tmatch restartPause outPause kickCooldown maxObservationAge walkValidity kickPreparation kickTimeout recoverTime observationDelay'.split():units[k]='s'
for k in 'kickAlign behindTol kickNoise fieldOfView'.split():units[k]='rad'
units.update(wMax='rad/s',searchTurnRate='rad/s',ballDecel='m/s²',Kp='s⁻¹',Kw='s⁻¹',roleHyst='weighted cost',avoidGain='heuristic gain')
rows=[]
for k,v in config.items():
 category='课程要求' if k in course else ('拟议设计/教学设定' if k in design else '现有行为')
 source='课程规格 PDF 第 3 页（人数见项目说明）' if k in course else ('本工程 defaultConfig' if k in design else 'A simParams.m')
 status='已采用；非实测标定'
 if k=='ballR':category='课程要求（近似派生）';source='约 14 cm 直径 / 2；不是精确实测值'
 if k=='restartOpponentDistance':category='RoboCup 参考 + 教学简化';source='R2025 自由球距离规则；本版仅重开瞬间中心点投影'
 if k in ('vFwd','vBack','vSide','wMax','ballDecel','ballRestit','ballRobotE','robotR'):status='估计/简化，待实测'
 if k=='Tmatch':source='harness 覆盖 A 练习值 5 s';category='教学设定'
 if k=='realtime':source='无画面 harness 覆盖 true';category='教学设定'
 if k in ('drawEvery','realtime'):status='保留 A 字段；新离线模型不使用显示节拍或实时等待'
 if k in ('observationDelay','observationNoise'):status='已实现于 sensorReplay；runMatch 非零时明确报错'
 if k=='dt':source='A 默认 0.05；另验收 0.04';category='现有行为/工程配置'
 rows.append(dict(parameter=k,value=v,unit=units.get(k,'1 / enum'),category=category,source=source,status=status))
(out/'parameters.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
text=['# 运行参数（脚本生成）','','所有参数均列出；未标注实测的动力学量不得用于宣称 NAO6 性能。','','| 参数 | 当前值 | 单位 | 来源类别 | 来源 | 状态 |','|---|---|---|---|---|---|']
for r in rows:text.append('| '+' | '.join(str(r[k]) for k in ('parameter','value','unit','category','source','status'))+' |')
source=json.loads((root/'reference/course/tdp_modeling_parameters_2026_2027.json').read_text());nulls=[]
def visit(value,path):
 if isinstance(value,dict):
  for k,v in value.items():visit(v,path+'.'+k)
 elif isinstance(value,list):
  for i,v in enumerate(value):visit(v,f'{path}[{i}]')
 elif value is None:nulls.append(path)
visit(source,'course')
(out/'unknown_parameters.json').write_text(json.dumps(nulls,ensure_ascii=False,indent=2)+'\n')
text+=['','原参数目录中 JSON null 的路径完整保留在 unknown_parameters.json。null 可能是未知物理值，也可能表示某字符串规则没有单位；不能一律填 0。实际使用数值前调用 tdp.requireKnown，或显式提供有记录的教学假设。三维球质量等新增假设另列在 M2 参数表。']
(out/'parameters.md').write_text('\n'.join(text)+'\n')
