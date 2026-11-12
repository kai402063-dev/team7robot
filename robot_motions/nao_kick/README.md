# NAO V5 kicking and recovery controller (Webots)

ENG5325 Stage 1 deliverable: **kicking and recovery controller**.
Python controller for the built-in Webots `Nao` (V5) robot.

## Folder layout
```
nao_kick/
  worlds/kick_recovery_test.wbt        test world: NAO, 14 cm ball, 9 x 6 m pitch
  controllers/kick_recovery/
    kick_recovery.py                    main controller (modes below)
    poses.py                            stand pose, kick and roll-over keyframes  <- tune here
    motion_player.py                    plays keyframes and Webots .motion files
  motions/                              copy Webots' NAO motion files here (step 2)
```

## Set-up
1. Unzip and open `worlds/kick_recovery_test.wbt` in Webots (R2025a).
2. Copy all `.motion` files from
   `WEBOTS_HOME/projects/robots/softbank/nao/motions`
   (Windows default: `C:\Program Files\Webots\projects\robots\softbank\nao\motions`)
   into the `motions` folder. The controller uses them for walking, turning,
   side steps and standing up from the front. The console lists which motions it found.
3. Python must be installed on Windows (Webots: Tools > Preferences > Python command).
4. Press Play.

## Modes
Change the NAO's `controllerArgs` field in the scene tree, then reload the world.

| Mode | What it does | Output |
| --- | --- | --- |
| `sensor_check` | Prints the accelerometer while you drag the robot onto its back and front. Run this **first**. | Console |
| `kick_test` | Puts the ball in front of the kicking foot and kicks at strengths 0.2–1.0, 3 kicks each. Records peak ball speed, distance rolled, direction error and falls; gets up after falls. | `kick_test.csv` |
| `getup_test` | Lays the robot on its back 10 times at random headings and times the get-up. | `getup_test.csv` |
| `play` | Walks to the ball, lines up with the target (default: right goal centre at x = 4.5 m), kicks, gets up if it falls, repeats. | Console |

The Webots test world has a 9 m x 6 m marked playing area on 11 m x 8 m turf.
Both goals are 2.8 m wide overall (2.6 m clear between the posts), 1.2 m high,
and use 0.1 m square posts and crossbar, matching `kidsize_pitch.wbt`.

CSV files are written next to `kick_recovery.py`.

## How it works
- **Kick** (`poses.kick_sequence`): stand → shift weight onto the support foot →
  lift → back-swing → swing through → retract → put down → re-centre.
  `strength` (0–1) sets the back-swing size and swing speed.
  Set `USE_BUILTIN_SHOOT = True` to compare with Webots' `Shoot.motion`.
- **Positioning** (`position_for_kick`): go to a point 0.45 m behind the ball
  (round the side if the robot is past it), then turn to face the target and
  correct with side steps and short steps until the ball is at
  (`BALL_X`, `BALL_Y`) in front of the kicking foot.
- **Fall detection**: the torso accelerometer; upright when the vertical axis
  reads more than 5 m/s².
- **Recovery**: on the back or side → roll onto the front (`poses.rollover_sequence`),
  trying the other side if it fails → `StandUpFromFront.motion` → check upright.
  Up to 3 attempts.
- Ball and robot positions come from the Supervisor (ground truth). Replace
  them with camera-based estimates later.

## Tuning order
1. `sensor_check`: on the back `ax` should be positive; if not, set `BACK_SIGN = -1`.
2. Kick balance: run `kick_test` at strength 0.2. If the robot falls towards the
   kicking side, increase `WEIGHT_SHIFT`; if it falls towards the support side, decrease it.
3. Kick power: raise the strengths only once 0.2 is stable; tune the back-swing
   and swing lines marked `TUNE` in `poses.py`.
4. Contact: adjust `BALL_X` / `BALL_Y` until the foot meets the ball centre
   (direction error close to 0°).
5. Get-up: run `getup_test`; tune the roll-over keyframes marked `TUNE`.
   Double-click the robot to open its robot window and read live joint angles.

All keyframe values are first designs and must be tuned in Webots.
