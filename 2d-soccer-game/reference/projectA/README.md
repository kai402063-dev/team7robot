# ENG5325 RoboCup 2D Simulation (MATLAB)

A top-down 4 v 4 NAO6 soccer simulation on the 9 m × 6 m KidSize pitch
(Table 1 of the project specification). Base MATLAB only; no toolboxes.

## Run
1. Put all files in one folder and open it in MATLAB.
2. Run `main_robocup2d`.
3. Change anything in `simParams.m` (match length, robot speed limits,
   controller gains, animation speed).

## Files by work package
| File | Work package | What it does |
| --- | --- | --- |
| `robotModel.m` | A Robot model | Omnidirectional walk with NAO6-like speed and turn limits |
| `collisions.m` | A / B | Robot-robot separation; robot pushes ball (dribbling) |
| `ballModel.m` | B Pitch & ball | Rolling friction, bounce off the border |
| `rulesCheck.m` | B Pitch & ball | Goals, kick-ins, goal kicks, corners |
| `drawPitch.m`, `initGraphics.m`, `updateGraphics.m` | B Pitch & ball | Pitch markings and animation |
| `goToPose.m` | C Control & navigation | Go-to-point + heading control, robot avoidance |
| `kickSkill.m` | C Control & navigation | Get behind the ball, line up, kick |
| `teamBehaviour.m` | D Behaviours & tactics | Goalkeeper, dynamic striker, defender, supporter; passing and shooting |
| `main_robocup2d.m`, `initState.m`, `kickoffReset.m`, `simParams.m` | E Integration & testing | Main loop, set-up, parameters |

## Conventions
Origin at the centre spot, x along the pitch length, y across it, metres,
radians. Blue (team 1) attacks +x, red (team 2) attacks -x. Player 1 in
each team is the goalkeeper. Robot commands are `[vx vy w]` in the body frame.

## Simplifications to improve later
- Robot speeds are estimates; validate them against NAO6 data (WP A).
- Restarts do not enforce the opponents' distance from the ball.
- No falls, ball height, fouls or referee states; perfect knowledge of all
  positions (no vision or localisation noise).
