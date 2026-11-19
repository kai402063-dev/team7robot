# 2D Soccer Tactics Simulation

[中文说明](README_zh-CN.md)

This project uses MATLAB, Simulink, and Stateflow to simulate 4v4 soccer.
It includes live matches, team tactics, match replay, and offline behaviour
analysis.

## Run in MATLAB

Set MATLAB's Current Folder to `2d-soccer-game/` in your checkout and run
one of the commands below. You can also open the corresponding `.m` file
and click **Run** in the editor.

| To watch | MATLAB command | Ubuntu desktop launcher |
| --- | --- | --- |
| Default V1 match | `start_2d` | `START_2D.desktop` |
| Midfielder takeover and handback to the striker | `start_2d_recovery` | `START_2D_RECOVERY.desktop` |
| A saved match replay | `replay_2d` | `REPLAY_2D.desktop` |

Live matches default to **600 simulation seconds at 1× speed**. The blue
team uses robot IDs 1–4, and the red team uses 5–8. Each team is ordered
goalkeeper, defender, midfielder, striker. A gold ring marks the player
currently authorised to chase the ball. Use the match window to pause,
resume, change speed, stop, or restart. The first model build can take a
few minutes.

The Ubuntu launchers use absolute paths. Check that their `Exec` and
`Path` entries point to your checkout before using them. If Ubuntu asks
whether you trust the launcher, confirm the paths before allowing it to
run. Each launcher opens a separate MATLAB process that exits when you
close its window.

[8-second headless handback exercise (Chinese)](docs/chapters/recovery_experiment.md#自己制造一次接管并看逐拍日志) ·
[Live viewer, recordings, and troubleshooting (Chinese)](docs/chapters/live_animation.md) ·
[Animation screenshots and verification](docs/generated/animation_numbers.md)

## Run from a terminal

From the project folder in an Ubuntu graphical session, run one of the
following commands. If the launcher cannot find MATLAB, set `MATLAB_BIN`
to the MATLAB executable.

```bash
./start_2d.sh
./start_2d.sh --recovery
./start_2d.sh --replay
```

## Reproduction and development

The [Chinese development manual](docs/DEV_MANUAL.md) covers dependencies, a
short match in a clean clone, and the verification records needed for full
reproduction. [Project progress](docs/PROGRESS.md) records the scope of
2D, ROS 2, and Webots verification. The project includes the frozen A
baseline, MATLAB algorithms, Stateflow controllers, a 2D environment, and tests.

Before using headless batch commands, check the MATLAB installation path
in `scripts/run_matlab.sh`.

| To reproduce | Command |
| --- | --- |
| Full workflow | `./scripts/run_matlab.sh "tdpSetup; reproduce_all;"` |
| V1 tactics validation | `./scripts/run_matlab.sh "tdpSetup; reproduce_v1;"` |
| Automatic handback comparison | `./scripts/run_matlab.sh "tdpSetup; reproduce_recovery;"` |

- V1 validation rebuilds the model, tests specific scenarios, and runs
  40 matches across 20 seeds and two time steps. Use
  `runMatch(tdp.defaultConfig())` to run the original tactics as a control.
  [Tactics design](docs/chapters/tactics_v1_design.md) ·
  [40-match results](docs/generated/v1_results.md)
- The automatic handback experiment compares V1 with the experimental
  policy using matching seeds. A previous clean-clone run took about
  21 minutes on the development machine.
  [Comparison method](docs/chapters/recovery_experiment.md) ·
  [80-match results](docs/generated/recovery_results.md)
- The single-team comparison measures the effect of changing each
  team's policy independently.
  [Experiment design](docs/chapters/team_ablation.md) ·
  [Ball pursuit authorisation, shots, and goals](docs/generated/team_ablation.md)

The original 3v3 MATLAB/Simulink teaching example is documented in the
[archived starter guide](../Archive/robot-soccer-starter/README.md).
