# Team 7 Robot Soccer

## 2D Team Tactics Simulation

`2d-soccer-game/` is a 4v4 soccer simulation built with MATLAB, Simulink,
and Stateflow. It includes live matches, configurable team tactics, match
replay, and offline behaviour analysis.

To watch the default V1 match, open `2d-soccer-game/` as the Current Folder
in MATLAB and run

```matlab
start_2d
```

Run `start_2d_recovery` to watch the midfielder temporarily take over ball
pursuit and hand it back to the striker. Run `replay_2d` to review a saved
match. V1.2 supports neutral, aggressive, and defensive policies for each team.

- [English simulation guide](2d-soccer-game/README.md)
- [中文仿真运行说明](2d-soccer-game/README_zh-CN.md)

## ROS 2 and Webots Development

The Webots project includes NAO V5 controllers for walking, kicking, fall
recovery, and goalkeeping, with a separate 4v4 match world.

- [Webots controller setup and test modes](https://github.com/kai402063-dev/team7robot/blob/main/robot_motions/nao_kick/README.md)
- [4v4 match world](https://github.com/kai402063-dev/team7robot/blob/main/robot_motions/nao_kick/worlds/match.wbt)
- [ROS 2 and Webots Development Guide](https://github.com/kai402063-dev/team7robot/blob/main/ROS2_Webots_Guide.md)

## Archived Robot Soccer Starter

The original 3v3 MATLAB/Simulink teaching example has been archived in
`Archive/robot-soccer-starter/`.
