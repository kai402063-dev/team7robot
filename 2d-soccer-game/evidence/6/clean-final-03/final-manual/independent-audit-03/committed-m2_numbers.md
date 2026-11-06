# M2 实测数字（脚本生成）

来自已提交真实ROS/Webots记录；每次测试重新分析记录并重放Core。位移/速度是V5仿真结果，不是NAO6实测。

| 字段（名称含单位） | 值 |
|---|---|
| scalarInput | 3.5 |
| scalarOutput | 4.5 |
| rosReplayFrames | 101 |
| webotsFrames | 1001 |
| clockPublishers | 1 |
| initialDistanceMetres | 0.696698991074647 |
| distanceAtShootMetres | 0.218010912762967 |
| requestId | 438 |
| motionStartSeconds | 20.78 |
| motionEndSeconds | 25.58 |
| motionDurationSeconds | 4.8 |
| motionEventBallDisplacementMetres | 0.192893730709864 |
| sampledBallDisplacementMetres | 0.195528182208871 |
| ballEvaluationTimeSeconds | 25.6 |
| sampledBallPeakSpeedMetresPerSecond | 0.131725475699181 |
| duplicateDeliveries | 154 |
| physicalExecutions | 1 |
| motionOnlyBallDisplacementMetres | 0 |
| cameraErrorCode | 0 |
| cameraWidth | 160 |
| cameraHeight | 120 |
| cameraBytes | 76800 |

动作事件每20 ms检查；sampled字段来自40 ms观测。motionEvent位移取动作结束瞬间，sampled位移取ballEvaluationTimeSeconds所示的随后观测，不能互换。
