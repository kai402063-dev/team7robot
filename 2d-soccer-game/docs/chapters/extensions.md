# 五个已经实现的改动示例

扩展时先提出一个能观察的差别，再改一处，再跑有针对性的测试。以下不是未验证的建议，源码和测试随基线提供。具体通过回执见状态表；测试失败时不要依据本章文字认定成功。

| 改动 | 实现与操作 | 应观察到的差别 | 测试与边界 |
|---|---|---|---|
| 改踢球距离阈值 | P.kickRange 从默认值改为 0.32；机器人在 x=-0.29、球在原点 | 原配置不 ready；新配置 ready | `testThresholdChangesDecision`；位置/朝向/冷却其他条件固定 |
| 改角色规则 | P.fixedStriker=true；TeamCoordinator 显式指定本队 2 号为 ST | 初始动态规则选择 4 号；固定规则选择 2 号，仍只有一名前锋 | `testFixedRoleRule`；门将仍为 1 号；不是自动改变门将身份 |
| 加有限视野 | P.fieldOfView=pi/3，Observation2D 将身后球的 ballValid 置 false | 原全视野能看见身后球，新配置看不见 | `testFiniteFieldOfView`；只有方位视野，没有遮挡/识别器 |
| 加观测延迟与噪声 | ObservationChannel 固定保存 21 个样本；P.observationDelay=.10，observationNoise=.02 | 前两拍无有效历史；第三拍收到时刻 0 的球；注入样本 [1,-2] 得偏移 [.02,-.04] m | `testObservationDelayAndNoise` 和 `testDelayedChannelRunsSharedCore`；延迟必须是 0…20 个整周期 |
| 加 Tap 动作 | `tdp.makeTapIntent`，TdpAction.Tap；P.tapSpeed=0.30 | 动作协议同 Kick 去重，零噪声出球速度为 .30 m/s | `testTapExecutesLowerSpeed`；这是一种二维轻触动作，不是已标定三维技能 |

观测通道目前通过 `sensorReplay(P,seed,duration)` 接入真实 ControllerCore 回放。它没有默默作用于所有八机器人比赛：runMatch 对非零 delay/noise 明确报错，提示使用此实验入口。将通道推广到全场需要每个观测源各有自己的历史，保留采集时间，并明确团队通信与裁判许可是否延迟。

例如：

```matlab
P=tdp.defaultConfig(); P.mode=TdpMode.Delayed;
P.observationDelay=0.10; P.observationNoise=0.02;
[records,scenario]=sensorReplay(P,7,2);
assertSuccess(runtests('tests/test_extensions.m'));
```

随机化初态也已做成 `tdp.randomizeInitial(P,noiseSample)`。固定 9×3 样本，前 8 行对应机器人，最后一行对应球；每次从规范初态开始，位置扰动比例 0.05 m、朝向 0.10 rad，属于教学设定。`testRandomizationStartsFresh` 验证两次相同输入不累积。实际比赛默认不启用随机初态。

未知参数的处理由 `tdp.requireKnown` 演示：空数组（jsondecode 后的 null）和 NaN 报错；显式已知值 0 可以合法返回。未知和数值恰好为零是两件不同的事。

新增动作时还要考虑：请求什么时候锁定参数；重复编号是否只执行一次；谁判断失败；动作是否有超时；完成反馈是否只代表运动文件结束。M2 的新增 ROS 2 主题示例另见 ROS 章，不能仅把主题名字写入文档就算实现。

## 第六例：增加ROS诊断主题

已实现并实测 `/tdp/diagnostics/action_age`：std_msgs/Float64，单位s，值为tSim减自身采集时刻。proxy.py创建publisher并在完整动作交换后发布，replay_driver.py订阅后逐样本与固定输入计算值比较；evidence/4/ros-01/action-age.json和topic info是实际证据。重复包不刷新采集stamp，出现负值表示未来时间而不是延迟为零；动作有效性由BridgeDecode另行判定。复制这条扩展时先确定单位和时间来源，再更新订阅断言，按[ROS章节](ros2.md)运行完整消息回放。
