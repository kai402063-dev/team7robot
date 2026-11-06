# 运行参数（脚本生成）

所有参数均列出；未标注实测的动力学量不得用于宣称 NAO6 性能。

| 参数 | 当前值 | 单位 | 来源类别 | 来源 | 状态 |
|---|---|---|---|---|---|
| L | 9 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| W | 6 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| goalD | 0.6 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| goalW | 2.6 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| goalAreaL | 1 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| goalAreaW | 3 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| penMark | 1.5 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| centreD | 1.5 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| border | 1 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| penAreaL | 2 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| penAreaW | 5 | m | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| ballR | 0.07 | m | 课程要求（近似派生） | 约 14 cm 直径 / 2；不是精确实测值 | 已采用；非实测标定 |
| ballDecel | 0.4 | m/s² | 现有行为 | A simParams.m | 估计/简化，待实测 |
| ballRestit | 0.5 | 1 / enum | 现有行为 | A simParams.m | 估计/简化，待实测 |
| ballRobotE | 0.3 | 1 / enum | 现有行为 | A simParams.m | 估计/简化，待实测 |
| robotR | 0.15 | m | 现有行为 | A simParams.m | 估计/简化，待实测 |
| vFwd | 0.25 | m/s | 现有行为 | A simParams.m | 估计/简化，待实测 |
| vBack | 0.12 | m/s | 现有行为 | A simParams.m | 估计/简化，待实测 |
| vSide | 0.15 | m/s | 现有行为 | A simParams.m | 估计/简化，待实测 |
| wMax | 0.7853981633974483 | rad/s | 现有行为 | A simParams.m | 估计/简化，待实测 |
| Kp | 0.8 | s⁻¹ | 现有行为 | A simParams.m | 已采用；非实测标定 |
| Kw | 2 | s⁻¹ | 现有行为 | A simParams.m | 已采用；非实测标定 |
| avoidR | 0.7 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| avoidGain | 0.6 | heuristic gain | 现有行为 | A simParams.m | 已采用；非实测标定 |
| ballAvoidR | 0.35 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| approachDist | 0.45 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| kickRange | 0.28 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| stepInSpeed | 0.1 | m/s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| kickAlign | 0.3490658503988659 | rad | 现有行为 | A simParams.m | 已采用；非实测标定 |
| behindTol | 0.5235987755982988 | rad | 现有行为 | A simParams.m | 已采用；非实测标定 |
| kickNoise | 0.10471975511965978 | rad | 现有行为 | A simParams.m | 已采用；非实测标定 |
| kickCooldown | 1 | s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| shotSpeed | 1.8 | m/s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| dribbleSpeed | 0.6 | m/s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| maxKickSpeed | 2.2 | m/s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| roleHyst | 0.4 | weighted cost | 现有行为 | A simParams.m | 已采用；非实测标定 |
| shootDist | 3 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| defDist | 1.8 | m | 现有行为 | A simParams.m | 已采用；非实测标定 |
| nPerTeam | 4 | 1 / enum | 课程要求 | 课程规格 PDF 第 3 页（人数见项目说明） | 已采用；非实测标定 |
| dt | 0.05 | s | 现有行为/工程配置 | A 默认 0.05；另验收 0.04 | 已采用；非实测标定 |
| Tmatch | 600 | s | 教学设定 | harness 覆盖 A 练习值 5 s | 已采用；非实测标定 |
| restartPause | 2 | s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| outPause | 1 | s | 现有行为 | A simParams.m | 已采用；非实测标定 |
| drawEvery | 4 | 1 / enum | 现有行为 | A simParams.m | 保留 A 字段；新离线模型不使用显示节拍或实时等待 |
| realtime | False | 1 / enum | 教学设定 | 无画面 harness 覆盖 true | 保留 A 字段；新离线模型不使用显示节拍或实时等待 |
| dirSign | [1, -1] | 1 / enum | 现有行为 | A simParams.m | 已采用；非实测标定 |
| seed | 1 | 1 / enum | 现有行为 | A simParams.m | 已采用；非实测标定 |
| mode | Compat | 1 / enum | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| rulesProfile | ACompat | 1 / enum | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| maxObservationAge | 0.5 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| walkValidity | 0.1 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| kickPreparation | 0.2 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| kickTimeout | 1 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| recoverTime | 0.5 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| alignEnter | 0.35 | m | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| alignExit | 0.45 | m | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| searchTurnRate | 0.3 | rad/s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| fieldOfView | 6.283185307179586 | rad | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| observationDelay | 0 | s | 拟议设计/教学设定 | 本工程 defaultConfig | 已实现于 sensorReplay；runMatch 非零时明确报错 |
| observationNoise | 0 | m | 拟议设计/教学设定 | 本工程 defaultConfig | 已实现于 sensorReplay；runMatch 非零时明确报错 |
| fixedStriker | False | 1 / enum | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| tapSpeed | 0.3 | m/s | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| freezeDuringPause | False | 1 / enum | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| contactIterations | 256 | 1 / enum | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |
| restartOpponentDistance | 0.75 | m | RoboCup 参考 + 教学简化 | R2025 自由球距离规则；本版仅重开瞬间中心点投影 | 已采用；非实测标定 |
| contactTolerance | 1e-10 | m | 拟议设计/教学设定 | 本工程 defaultConfig | 已采用；非实测标定 |

原参数目录中 JSON null 的路径完整保留在 unknown_parameters.json。null 可能是未知物理值，也可能表示某字符串规则没有单位；不能一律填 0。实际使用数值前调用 tdp.requireKnown，或显式提供有记录的教学假设。三维球质量等新增假设另列在 M2 参数表。
