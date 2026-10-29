# Robot Soccer Starter

A starter project for learning robot soccer simulation with MATLAB and Simulink.

[中文说明](README_zh-CN.md)

## About the Example

This project builds on the MathWorks Mobile Robotics Simulation Toolbox. It simulates two teams of three robots on a 2D soccer field, with robot motion, ball interaction, sensor models, and behavior logic. Use it to explore the model structure, change parameters, and develop team strategies.

The robots use simplified 2D kinematic models. The included toolbox also contains examples of mobile robot navigation, sensors, and visualization.

Copyright 2018-2019 The MathWorks, Inc. Original copyright notices are retained in the source files.

## Software Environment

The example has been checked in MATLAB R2026b with these products available:

- Simulink
- Stateflow
- Robotics System Toolbox
- Navigation Toolbox
- Image Processing Toolbox

Use MATLAB desktop to view the model and animation. Compatibility with other MATLAB releases needs to be checked separately. Other examples may require additional products; see `doc/GettingStarted.mlx`.

## Project Layout

```text
robot-soccer-starter/
├── README.md
├── README_zh-CN.md
├── startMobileRoboticsSimulationToolbox.m
├── examples/soccer/
│   ├── multiRobotSoccer.slx       # Main soccer model
│   ├── robotSoccerParams.m       # Simulation parameters
│   ├── datatypes/                # Bus types and enumerations
│   └── utils/                    # Soccer helpers and robot library
├── src/                         # Kinematics, sensors, visualization, pacing
└── doc/                         # Toolbox documentation
```

## Open and Run in MATLAB

1. Download or copy the **whole project folder** to your computer and extract it if it is a ZIP file. You may store it anywhere and rename the folder.
2. Open MATLAB. In **Current Folder**, browse to the project root: the folder containing this README, `startMobileRoboticsSimulationToolbox.m`, `examples`, and `src`. If another project has a model named `multiRobotSoccer` open, save any changes you need and close it first. A fresh MATLAB session avoids mixing paths from different copies.
3. In the **Command Window**, run the following block. It initializes paths, opens the model, selects approximately real-time playback, and runs a 30-second simulation:

   ```matlab
   run('startMobileRoboticsSimulationToolbox.m');
   open_system(fullfile(pwd, 'examples', 'soccer', 'multiRobotSoccer.slx'));
   soccerRuntimePacing(1);
   set_param('multiRobotSoccer', 'StopTime', '30');
   set_param('multiRobotSoccer', 'SimulationCommand', 'start');
   ```

   The startup script also opens the `GettingStarted.mlx` guide. The first run compiles the model before the soccer-field animation appears. The value `30` refers to simulation time in seconds.
4. Use the Simulink **Pause**, **Continue**, and **Stop** controls as needed. To stop from the Command Window:

   ```matlab
   set_param('multiRobotSoccer', 'SimulationCommand', 'stop');
   ```

### Open Files with the MATLAB Interface

After selecting the project root in **Current Folder**:

1. Double-click `startMobileRoboticsSimulationToolbox.m` and click **Run** in the MATLAB Editor. Keep **Current Folder** at the project root while initializing.
2. Browse to `examples/soccer` and double-click **`multiRobotSoccer.slx`** to open the main model.
3. In the Command Window, enter `soccerRuntimePacing(1)` to enable approximately real-time playback.
4. In the Simulink model window, set **Stop Time** to `30` and click **Run**. For continuous simulation, set **Stop Time** to `inf`; click **Stop** when finished.

Opening the model automatically runs `robotSoccerParams.m`. This script clears variables in the base workspace, loads the bus types and parameters, and randomizes initial robot and ball positions. Save any workspace data you need before opening the model. Separate runs may start from different positions when the parameters are reinitialized.

## Adjust Playback Speed

With the model open, enter one of these commands in the MATLAB Command Window:

| Command | Effect |
| --- | --- |
| `soccerRuntimePacing(1)` | Target approximately real-time playback |
| `soccerRuntimePacing(3)` | Target approximately 3 simulation seconds per real second |
| `soccerRuntimePacing(0)` | Remove pacing and run as fast as computation allows |
| `soccerRuntimePacing('status')` | Show the configuration and available timing statistics |
| `soccerRuntimePacing('restore')` | Disable soft pacing and restore the previous built-in pacing settings |

The helper automatically disables Simulink's built-in **Simulation Pacing**. Keep that built-in option off while using the helper. Playback speed depends on machine load; this is soft pacing without a hard real-time guarantee. The pacing configuration lasts only for the current MATLAB session, so enable it again after restarting MATLAB.

## Where to Start Exploring

- **Parameters:** open `examples/soccer/robotSoccerParams.m`, or enter `edit robotSoccerParams` after initialization. Start with `initialPoses`, `initBallPos`, sensor ranges, and behavior thresholds. The script calls `randomizeStartingPositions`; review that call when experimenting with fixed starting positions.
- **Behavior:** open `multiRobotSoccer.slx` and explore the robot subsystems and Stateflow logic. The robot library is `examples/soccer/utils/soccerRobotLib.slx`.
- **Toolbox guide:** enter `edit GettingStarted` after initialization for the remaining examples and documentation.

Stop the simulation before editing. After changing the parameter script, run `robotSoccerParams` again to reload parameters, then restart the simulation. This also clears workspace variables. Keep a separate copy of the starter project for your experiments.

## Troubleshooting

If MATLAB cannot find a function or bus type, select the project root in **Current Folder** and rerun the startup script. If a required product is missing, check the installed products with `ver`.

If `soccerRuntimePacing` reports `WrongCopy`, check the active paths:

```matlab
get_param('multiRobotSoccer', 'FileName')
which soccerRuntimePacing -all
which robotSoccerParams -all
```

The model and the first matching functions should belong to the same project folder. Close models from other copies and initialize this project again, or start a fresh MATLAB session.

## Further Reading

- [Simulating Mobile Robots with MATLAB and Simulink](https://www.mathworks.com/videos/matlab-and-simulink-robotics-arena-getting-started-with-the-mobile-robotics-simulation-toolbox-1523443253912.html)
- [Programming Robot Swarms](https://www.mathworks.com/videos/matlab-and-simulink-robotics-arena-programming-robot-swarms-1539080970349.html)
- [Programming Soccer Robot Behavior](https://www.mathworks.com/videos/programming-soccer-robot-behavior-1554386041395.html)
