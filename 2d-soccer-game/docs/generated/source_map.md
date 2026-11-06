# 源码对应行（脚本生成）

A 快照不可变；行号包含注释。B 的 SLX 用内部组件路径，不虚构文本行号。

| 新模块 | 来源文件 | 原源码行 | 关系 |
|---|---|---|---|
| tdp.goToPose | reference/projectA/goToPose.m | 1–36 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.kickSkill | reference/projectA/kickSkill.m | 1–38 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.robotModel | reference/projectA/robotModel.m | 1–25 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.ballModel | reference/projectA/ballModel.m | 1–21 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.collisions | reference/projectA/collisions.m | 1–34 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.rulesCheck | reference/projectA/rulesCheck.m | 1–40 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.angWrap | reference/projectA/angWrap.m | 1–4 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.kickoffReset | reference/projectA/kickoffReset.m | 1–16 | 等价提取；踢球函数的噪声改为显式注入 |
| tdp.roleAssignment | reference/projectA/teamBehaviour.m | 21–44 | 角色代价与前锋记忆 |
| tdp.actionSelection | reference/projectA/teamBehaviour.m | 45–97 | 按角色选择计划；动作结构构造函数紧随其后 |
| tdp.laneClear | reference/projectA/teamBehaviour.m | 107–117 | 线段距离检验 |
| tdp.initialState / tdpTemplates | reference/projectA/initState.m | 1–21 | 数值初态对应；类型总线为新设计 |
| baseline.runA / MatchPlant2D / Plant2D | reference/projectA/main_robocup2d.m | 15–67 | 无画面执行顺序对应；环境分层为新设计 |
| TeamCoordinator | reference/projectA/teamBehaviour.m | 1–97 | 拆分角色与计划；两份延迟记忆为新设计 |
| Contact2D / Referee2D | reference/projectA/collisions.m + rulesCheck.m | 新设计/二进制组件，见关系列 | 按配置启用修复；先运行原缺陷复现测试 |
| Observation2D / ObservationChannel / CoreGeometry / EmitRequest / Actuator2D | 本次新设计 | 新设计/二进制组件，见关系列 | 新接口与时序设计，不继承 B 行为 |
| ControllerCore / learning charts | B soccerRobotLib.slx (SoccerBehavior), examples/soccer/datatypes/*.m | 新设计/二进制组件，见关系列 | 仅参考状态图/总线/枚举组织，阶段逻辑为新设计 |
| Viewer2D | reference/projectA/initGraphics.m, reference/projectA/updateGraphics.m | 新设计/二进制组件，见关系列 | 只参考显示约定，离线日志渲染为新设计 |
