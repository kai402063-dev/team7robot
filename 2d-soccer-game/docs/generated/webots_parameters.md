# Webots 参数及来源（脚本生成）

| 参数 | 值 | 单位 | 来源类别 / 状态 |
|---|---|---|---|
| robotModel | "Webots Nao H25 V5 red" | — | 现有Webots模型 / 已读取 |
| basicTimeStepMs | 20 | ms | 教学设定 / 已配置，未标定 |
| controlPeriodSeconds | 0.04 | s | 教学设定 / 已配置，未标定 |
| graphBootstrapRepublishSeconds | 0.25 | wall s | 工程通信设定 / 墙钟握手，不推进仿真 |
| graphBootstrapTimeoutSeconds | 90.0 | wall s | 工程通信设定 / 墙钟握手，不推进仿真 |
| cameraWidth | 160 | pixel | 现有Webots模型 / 已读取 |
| cameraHeight | 120 | pixel | 现有Webots模型 / 已读取 |
| ballRadiusMetres | 0.07 | m | 课程尺寸来源 / 已核对 |
| ballMassKg | 0.15 | kg | 显式假设 / 源参数未知，待实测 |
| ballMassSource | "explicit teaching assumption; course/source unknown; measurement required" | — | 设计/来源说明 |
| ballDisplacementThresholdMetres | 0.05 | m | 教学设定 / 已配置，未标定 |
| robotInitialPosition | [-0.7, 0.0, 0.334] | m, ENU | 教学设定 / 已配置，未标定 |
| ballInitialPosition | [0.0, 0.0, 0.075] | m, ENU | 教学设定 / 已配置，未标定 |
| kickTimeoutSeconds | 12.0 | s | 教学设定 / 已配置，未标定 |
| recoverTimeSeconds | 2.0 | s | 教学设定 / 已配置，未标定 |
| settleSeconds | 2.0 | s | 教学设定 / 已配置，未标定 |
| controlFrames | 1001 | sample | 教学设定 / 已配置，未标定 |
| footFriction | 7.0 | 1 | Webots参考 / 非NAO6实测 |
| footFrictionSource | "Webots nao_demo.wbt reference, not measured NAO6" | — | Webots参考 / 非NAO6实测 |
| localization | "Supervisor read-only ground truth; not perception validation" | — | 设计/来源说明 |
| motionMapping | "dominant velocity sign selects finite prerecorded motion; magnitude is not a calibrated velocity" | — | 设计/来源说明 |
| footBounce | 0.3 | 1 | Webots参考 / 非NAO6实测 |
| footBounceVelocityMetresPerSecond | 0.003 | m/s | Webots参考 / 非NAO6实测 |
| uprightMinimumZMetres | 0.15 | m | 教学设定 / 已配置，未标定 |
| uprightMinimumUpZ | 0.5 | 1 | 教学设定 / 已配置，未标定 |
| walkSelectionReference | [0.25, 0.15, 0.7853981633974483] | m/s,m/s,rad/s | 教学设定 / 已配置，未标定 |
| ballStationarySpeedTolerance | 0.01 | m/s | 教学设定 / 已配置，未标定 |
| ballMotionSpeedThreshold | 0.05 | m/s | 教学设定 / 已配置，未标定 |
| minimumApproachProgressMetres | 0.2 | m | 教学设定 / 已配置，未标定 |
