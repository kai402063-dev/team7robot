"""Kicking and recovery controller for the Webots NAO V5 (ENG5325, Stage 1).

Modes (set in the robot's controllerArgs field in Webots):
  play         walk to the ball, line up, kick towards the target, get up if fallen, repeat
  kick_test    repeat kicks at several strengths and log ball speed, distance, direction, falls
  getup_test   lay the robot on its back again and again and log get-up success and time
  sensor_check print accelerometer readings while you move the robot (to check fall signs)

Needs: the robot's 'supervisor' field set to TRUE (used for ground-truth ball and
robot positions and for resetting tests) and a ball Solid with DEF name BALL.
"""
import csv
import math
import os
import random
import sys

from controller import Supervisor

import poses
from motion_player import MotionPlayer, load_motion_file, motion_to_sequence

# ------------------------------------------------------------------ settings
TARGET = (4.5, 0.0)         # world point to kick towards (centre of a goal)
KICK_FOOT = "R"
KICK_STRENGTH = 0.8         # 0..1 for the custom kick
USE_BUILTIN_SHOOT = False   # True = use Webots' Shoot.motion instead of the custom kick

BALL_X = 0.20               # TUNE where the ball should sit in front of the robot (m)
BALL_Y = 0.05               # TUNE sideways offset so the ball is in front of the kicking foot
POS_TOL_X, POS_TOL_Y = 0.05, 0.035
HEAD_TOL = math.radians(20)  # turn clips finish in full steps; allow their small overshoot

# Walking speed: motions are played this many times faster than recorded.
# If the robot falls while walking, the speed-up drops by WALK_SPEED_STEP
# automatically (never below 1.0).
WALK_SPEED = 1.0            # use the recorded gait speed for stability
TURN_SPEED = 0.5            # half-speed turn playback reduces leg clipping and falls
SIDE_STEP_SPEED = 0.6       # complete each lateral step slowly before checking position
SIDE_STEP_WIDTH = 0.9       # reduce lateral reach to keep the stance under the body
WALK_SPEED_STEP = 0.1
WALK_HEAD_TOL = math.radians(25)   # walk without turning first if heading is within this

# Fall detection uses the torso orientation from the Supervisor (no sign guessing).
UPRIGHT_MIN = 0.5           # fallen when the torso's up-axis is tilted more than ~60 deg
FALL_CONFIRM_S = 0.15       # tilt must last this long, so a wobble is not counted as a fall

# Balance after getting up: hold the get-up's last pose, then move slowly to the
# stand pose while an ankle/hip controller corrects forward/backward lean.
SETTLE_S = 1.0              # TUNE hold the get-up motion's final pose this long
TO_STAND_S = 2.0            # TUNE time to move from that pose to the stand pose
BAL_KP_ANKLE = 0.8          # TUNE rad of ankle correction per unit of lean
BAL_KD_ANKLE = 0.08         # TUNE damping on the lean rate
BAL_KP_HIP = 0.5            # TUNE rad of hip correction per unit of lean
BAL_MAX = 0.35              # largest correction allowed (rad)

STRENGTHS = [0.2, 0.4, 0.6, 0.8, 1.0]
KICKS_PER_STRENGTH = 3
GETUP_TRIALS = 10
MAX_GETUP_ATTEMPTS = 3

KICK_PHASES = ["stand", "weight shift", "hold", "lift foot", "back-swing", "swing",
               "hold", "retract", "put foot down", "hold", "re-centre", "hold"]

WALK_MOTIONS = ["Forwards", "Forwards50", "Backwards", "SideStepLeft", "SideStepRight",
                "TurnLeft40", "TurnRight40", "TurnLeft60", "TurnRight60",
                "StandUpFromFront", "Shoot",
                # get-up motions from Cyberbotics' NAO wrestling examples (optional, see README)
                "GetUpBack", "GetUpFront", "GetUpSide"]


def wrap(a):
    return math.atan2(math.sin(a), math.cos(a))


def axis_angle_from_yaw_pitch(yaw, pitch):
    """Rotation Rz(yaw) * Ry(pitch) as a Webots axis-angle [x, y, z, angle]."""
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    R = [[cy * cp, -sy, cy * sp],
         [sy * cp,  cy, sy * sp],
         [-sp,     0.0, cp]]
    ang = math.acos(max(-1.0, min(1.0, (R[0][0] + R[1][1] + R[2][2] - 1) / 2)))
    if abs(ang) < 1e-6:
        return [0, 0, 1, 0]
    if abs(ang - math.pi) < 1e-4:            # 180 deg: axis from the diagonal
        x = math.sqrt(max(0, (R[0][0] + 1) / 2)); y = math.sqrt(max(0, (R[1][1] + 1) / 2))
        z = math.sqrt(max(0, (R[2][2] + 1) / 2))
        return [x, y, z, ang]
    k = 1 / (2 * math.sin(ang))
    return [k * (R[2][1] - R[1][2]), k * (R[0][2] - R[2][0]), k * (R[1][0] - R[0][1]), ang]


class NaoKickRecovery:
    def __init__(self):
        self.robot = Supervisor()
        self.ts = int(self.robot.getBasicTimeStep())
        self.motors, self.sensors = {}, {}
        for name in poses.JOINTS:
            m = self.robot.getDevice(name)
            if m is None:
                continue
            self.motors[name] = m
            ps = self.robot.getDevice(name + "S")
            if ps is not None:
                ps.enable(self.ts)
                self.sensors[name] = ps
        self.acc = self.robot.getDevice("accelerometer")
        self.acc.enable(self.ts)
        # one step so the position sensors and accelerometer hold real values (not NaN)
        self.robot.step(self.ts)
        self.player = MotionPlayer(self.robot, self.motors, self.sensors, self.ts)
        self.player.target = self.player.current_pose()

        self.me = self.robot.getSelf()
        self.ball = self.robot.getFromDef("BALL")
        if self.ball is None:
            sys.exit("No Solid with DEF BALL found in the world.")
        self.home = self.me.getPosition()             # standing height comes from the world file
        self.motions = self._load_motions()
        self.log_dir = os.path.dirname(os.path.abspath(__file__))
        self._tilt_steps = 0
        self.walk_speed = WALK_SPEED
        self.turn_speed = TURN_SPEED
        print(f"Motion speeds: walk {self.walk_speed:.1f}x, turn {self.turn_speed:.1f}x")

    # ------------------------------------------------------------ helpers
    def _load_motions(self):
        here = os.path.dirname(os.path.abspath(__file__))
        dirs = [os.path.join(here, "..", "..", "motions"),
                os.path.join(os.environ.get("WEBOTS_HOME", ""), "projects", "robots", "softbank", "nao", "motions"),
                r"C:\Program Files\Webots\projects\robots\softbank\nao\motions",
                "/usr/local/webots/projects/robots/softbank/nao/motions"]
        found = {}
        for name in WALK_MOTIONS:
            for d in dirs:
                p = os.path.join(d, name + ".motion")
                if os.path.isfile(p):
                    found[name] = load_motion_file(p)[1]
                    break
        missing = [n for n in WALK_MOTIONS if n not in found]
        print("Loaded motions:", ", ".join(found) or "none")
        if missing:
            print("Missing motions:", ", ".join(missing),
                  "- copy WEBOTS_HOME/projects/robots/softbank/nao/motions into this project.")
        return found

    def step(self, seconds=None):
        n = 1 if seconds is None else max(1, int(seconds * 1000 / self.ts))
        for _ in range(n):
            if self.robot.step(self.ts) == -1:
                sys.exit(0)

    def torso_axes(self):
        """World z-components of the torso's forward, left and up axes."""
        R = self.me.getOrientation()          # 3x3 row-major
        return R[6], R[7], R[8]

    def acc_values(self):
        v = self.acc.getValues()
        return [0.0, 0.0, 9.81] if any(x != x for x in v) else v

    def is_fallen(self):
        """Instant check: torso tilted past UPRIGHT_MIN."""
        return self.torso_axes()[2] < UPRIGHT_MIN

    def fall_check(self):
        """Debounced check for use during motions (tilt must persist)."""
        if self.is_fallen():
            self._tilt_steps += 1
        else:
            self._tilt_steps = 0
        return self._tilt_steps * self.ts / 1000.0 >= FALL_CONFIRM_S

    def lying_state(self):
        """'up', 'back', 'front' or 'side' from the torso orientation."""
        fz, lz, uz = self.torso_axes()
        if uz > 0.7:
            return "up"
        # A robot tilted between its back and side can have a fairly large fz.
        # Classify by the dominant horizontal torso axis so side falls take the
        # side-to-front recovery path instead of starting GetUpBack directly.
        if abs(lz) > abs(fz):
            return "side"
        if fz > 0.5:
            return "back"          # chest facing the sky
        if fz < -0.5:
            return "front"         # chest facing the floor
        return "side"

    def robot_pose(self):
        p = self.me.getPosition()
        R = self.me.getOrientation()
        return p[0], p[1], math.atan2(R[3], R[0])

    def ball_pos(self):
        b = self.ball.getPosition()
        return b[0], b[1]

    def ball_speed(self):
        v = self.ball.getVelocity()
        return math.hypot(v[0], v[1])

    def play_motion(self, name, time_scale=1.0, stop_after=None, abort_on_fall=True):
        """Play a .motion file. Get-up motions must use abort_on_fall=False,
        otherwise they stop immediately because the robot is lying down."""
        if name not in self.motions:
            print("Motion not available:", name)
            self.step(0.5)
            return "missing"
        check = self.fall_check if abort_on_fall else None
        self._tilt_steps = 0
        seq = motion_to_sequence(self.motions[name], time_scale, stop_after=stop_after)
        res = self.player.play(seq, check=check)
        if res == "done" and stop_after is not None:
            res = self.player.play([(0.5, poses.STAND)], check=check)
        return res

    def stand(self, duration=1.0):
        return self.player.play([(duration, poses.STAND)], check=self.fall_check)

    # ------------------------------------------------------------ kicking
    def kick(self, strength=KICK_STRENGTH, foot=KICK_FOOT):
        """Kick and return (peak ball speed m/s, fell during kick)."""
        peak = [0.0]

        def check():
            peak[0] = max(peak[0], self.ball_speed())
            return self.fall_check()

        if USE_BUILTIN_SHOOT and "Shoot" in self.motions:
            seq = motion_to_sequence(self.motions["Shoot"])
        else:
            seq = poses.kick_sequence(foot, strength)
        self._tilt_steps = 0
        res = self.player.play(seq, check=check)
        fell = res == "aborted" or self.is_fallen()
        if fell:
            names = KICK_PHASES if not USE_BUILTIN_SHOOT else []
            i = self.player.frame_index
            phase = names[i] if i < len(names) else f"frame {i}"
            fz, lz, uz = self.torso_axes()
            print(f"  fell during kick phase '{phase}' "
                  f"(torso forward_z={fz:.2f}, left_z={lz:.2f}): "
                  + ("fell forwards" if fz < -0.3 else "fell backwards" if fz > 0.3 else
                     "fell to the left" if lz < -0.3 else "fell to the right" if lz > 0.3 else "tilted"))
        return peak[0], fell

    # ------------------------------------------------------------ positioning
    def stance_target(self, target, foot):
        """Where the robot should stand to kick the ball towards target."""
        side = -1.0 if foot == "R" else 1.0            # ball offset in the robot's y
        bx, by = self.ball_pos()
        kick_dir = math.atan2(target[1] - by, target[0] - bx)
        ux, uy = math.cos(kick_dir), math.sin(kick_dir)
        lx, ly = -uy, ux                                # left of the kick direction
        gx = bx - ux * BALL_X - side * lx * BALL_Y
        gy = by - uy * BALL_X - side * ly * BALL_Y
        return gx, gy, kick_dir, (bx, by, ux, uy, lx, ly)

    def errors_to(self, gx, gy):
        """Position error to (gx, gy) in the robot frame: (forward, left, distance)."""
        x, y, yaw = self.robot_pose()
        ex_w, ey_w = gx - x, gy - y
        c, s = math.cos(yaw), math.sin(yaw)
        return c * ex_w + s * ey_w, -s * ex_w + c * ey_w, math.hypot(ex_w, ey_w)

    def play_until(self, name, done, max_time=12.0, speed=None):
        """Loop a walking motion until done() is True, then return to the stand pose.

        Stops on the robot's actual position, not on time, because the first
        second of a walking motion is mostly the gait starting up.
        Returns 'done', 'fallen', 'timeout' or 'missing'.
        """
        if name not in self.motions:
            print("Motion not available:", name)
            self.step(0.5)
            return "missing"
        self._tilt_steps = 0
        t_end = self.robot.getTime() + max_time
        reached = [False]

        def check():
            if self.fall_check():
                return True
            if done():
                reached[0] = True
                return True
            return self.robot.getTime() > t_end

        is_turn = name.startswith("Turn")
        if speed is None:
            speed = self.turn_speed if is_turn else self.walk_speed
        seq = motion_to_sequence(self.motions[name], time_scale=1.0 / speed, blend_in=0.2)
        while True:
            res = self.player.play(seq, check=check, ease=False)
            if res == "quit":
                sys.exit(0)
            # `check` aborts the current motion both when the target is reached
            # and when the robot falls. Replaying after `done()` caused endless
            # start-stop walking at the target until the timeout.
            if reached[0] or res == "aborted" or self.robot.getTime() > t_end:
                break
        if self.is_fallen():
            # walking too fast for the robot: slow down for the rest of the run
            if is_turn and self.turn_speed > 1.0:
                self.turn_speed = max(1.0, self.turn_speed - WALK_SPEED_STEP)
                print(f"  fell while turning: turn speed-up lowered to {self.turn_speed:.1f}")
            elif not is_turn and self.walk_speed > 1.0:
                self.walk_speed = max(1.0, self.walk_speed - WALK_SPEED_STEP)
                print(f"  fell while walking: walk speed-up lowered to {self.walk_speed:.1f}")
            return "fallen"
        self.player.play([(0.35, poses.STAND)], check=self.fall_check)
        result = "done" if reached[0] else "timeout"
        x, y, yaw = self.robot_pose()
        print(f"  {name:13s} -> {result:7s} robot at ({x:5.2f}, {y:5.2f}) facing {math.degrees(yaw):6.1f} deg")
        return result

    def turn_to(self, heading, tol=HEAD_TOL):
        """Turn using complete recorded steps so the legs do not stop mid-stride."""
        for _ in range(12):
            current_heading = self.robot_pose()[2]
            err = wrap(heading - current_heading)
            if abs(err) <= tol:
                return "done"
            large_turn = abs(err) > math.radians(50)
            if large_turn and "TurnLeft60" in self.motions and "TurnRight60" in self.motions:
                name = "TurnLeft60" if err > 0 else "TurnRight60"
            else:
                name = "TurnLeft40" if err > 0 else "TurnRight40"
            print(f"  {name}: heading {math.degrees(current_heading):.1f} deg "
                  f"toward {math.degrees(heading):.1f} deg")
            # Do not interrupt the clip when the heading crosses the target. The
            # clip ends with a stable stance; the next iteration checks the angle.
            res = self.play_motion(name, time_scale=1.0 / self.turn_speed,
                                   abort_on_fall=True)
            if self.is_fallen():
                return "fallen"
            if res != "done":
                return res
        return "timeout"

    def walk_to(self, gx, gy, tol=0.08):
        """Walk forwards to a point (turning towards it first)."""
        x, y, yaw = self.robot_pose()
        if math.hypot(gx - x, gy - y) <= tol:
            return "done"
        # Finish the turn before starting a walking motion. The wider walking
        # tolerance made the robot walk diagonally while it was still reorienting.
        res = self.turn_to(math.atan2(gy - y, gx - x), tol=HEAD_TOL)
        if res != "done":
            return res

        def done():
            ex, ey, d = self.errors_to(gx, gy)
            # reached, passed it, or drifted off line (then turn again next time)
            return d < tol or ex < 0.0 or abs(math.atan2(ey, max(ex, 1e-3))) > math.radians(35)
        far = math.hypot(gx - x, gy - y) > 0.8 and "Forwards50" in self.motions
        return self.play_until("Forwards50" if far else "Forwards", done)

    def ready_to_kick(self, target=TARGET, foot=KICK_FOOT):
        """Return True when the ball is already at the kicking foot and aligned."""
        gx, gy, kick_dir, (bx, by, ux, uy, _, _) = self.stance_target(target, foot)
        ex, ey, _ = self.errors_to(gx, gy)
        x, y, _ = self.robot_pose()
        # The ball must be ahead of the robot; this avoids treating a ball
        # beside or behind the kicking foot as ready just because the target
        # stance point happens to be nearby.
        ball_forward = (bx - x) * ux + (by - y) * uy
        heading_error = abs(wrap(kick_dir - self.robot_pose()[2]))
        return (ball_forward > 0.0
                and abs(ex) <= POS_TOL_X
                and abs(ey) <= POS_TOL_Y
                and heading_error <= HEAD_TOL)

    def position_for_kick(self, target=TARGET, foot=KICK_FOOT, max_actions=30):
        """Walk until the ball is just in front of the kicking foot, facing the target.

        Returns True when lined up, False if it fell or ran out of actions.
        """
        for _ in range(max_actions):
            gx, gy, kick_dir, (bx, by, ux, uy, lx, ly) = self.stance_target(target, foot)
            x, y, yaw = self.robot_pose()
            ahead = (x - bx) * ux + (y - by) * uy > -0.10    # level with or past the ball
            dist = math.hypot(gx - x, gy - y)
            ax_, ay_ = bx - ux * 0.45, by - uy * 0.45           # approach point behind the ball
            dist_a = math.hypot(ax_ - x, ay_ - y)

            if ahead:
                # go round the side of the ball, never through it
                s = 1.0 if (x - bx) * lx + (y - by) * ly >= 0 else -1.0
                res = self.walk_to(bx - ux * 0.25 + s * lx * 0.45, by - uy * 0.25 + s * ly * 0.45, tol=0.12)
            elif dist > 0.35 and dist_a > 0.12:
                # far: walk to the approach point 0.45 m behind the ball, on the kick line
                res = self.walk_to(ax_, ay_, tol=0.12)
            else:
                # close: face the target, then fix sideways and forward errors
                ex, ey, _ = self.errors_to(gx, gy)
                if abs(wrap(kick_dir - yaw)) > HEAD_TOL:
                    res = self.turn_to(kick_dir)
                elif abs(ey) > POS_TOL_Y:
                    sgn = 1.0 if ey > 0 else -1.0
                    name = "SideStepLeft" if sgn > 0 else "SideStepRight"
                    if name not in self.motions:
                        print("Motion not available:", name)
                        return False
                    # Finish the complete two-leg motion. Interrupting on the
                    # first position crossing can stop before the other leg steps.
                    seq = motion_to_sequence(self.motions[name],
                                             time_scale=1.0 / SIDE_STEP_SPEED)
                    for _, pose in seq:
                        for joint in ("LHipRoll", "RHipRoll"):
                            if joint in pose:
                                pose[joint] *= SIDE_STEP_WIDTH
                    self._tilt_steps = 0
                    res = self.player.play(seq, check=self.fall_check)
                    if res == "quit":
                        sys.exit(0)
                    if res != "done" or self.is_fallen():
                        return False
                    print(f"  {name} complete; checking lateral position again")
                elif ex > POS_TOL_X:
                    res = self.play_until("Forwards", lambda: self.errors_to(gx, gy)[0] < POS_TOL_X * 0.5,
                                          max_time=8.0)
                elif ex < -POS_TOL_X:
                    res = self.play_until("Backwards", lambda: self.errors_to(gx, gy)[0] > -POS_TOL_X * 0.5,
                                          max_time=8.0)
                else:
                    self.stand(0.6)
                    return True
            if res == "fallen" or self.is_fallen():
                return False
        print("Could not line up within the action limit.")
        return False

    # ------------------------------------------------------------ recovery
    def balanced_stand(self, settle=SETTLE_S, duration=TO_STAND_S):
        """Settle after a get-up motion, then blend to STAND with lean control.

        Lean is the z-component of the torso's forward axis: > 0 leaning back,
        < 0 leaning forward. Leaning back is corrected by tilting the shins
        (AnklePitch more negative) and the torso (HipPitch more negative)
        forwards, and the other way round. Returns True if still upright.
        """
        dt = self.ts / 1000.0
        start = dict(self.player.target)
        end = dict(start)
        for name, val in poses.STAND.items():
            if name in self.motors:
                end[name] = self.player._clamp(name, val)
        n_settle = int(settle / dt)
        n_blend = max(1, int(duration / dt))
        prev = self.torso_axes()[0]
        tilt_steps = 0
        for i in range(n_settle + n_blend):
            a = 0.0 if i < n_settle else 0.5 - 0.5 * math.cos(math.pi * (i - n_settle + 1) / n_blend)
            lean = self.torso_axes()[0]
            rate = (lean - prev) / dt
            prev = lean
            ank = max(-BAL_MAX, min(BAL_MAX, -(BAL_KP_ANKLE * lean + BAL_KD_ANKLE * rate)))
            hip = max(-BAL_MAX, min(BAL_MAX, -BAL_KP_HIP * lean))
            for name in end:
                v = start[name] + a * (end[name] - start[name])
                if name.endswith("AnklePitch"):
                    v += ank
                elif name.endswith("HipPitch"):
                    v += hip
                v = self.player._clamp(name, v)
                if v == v:
                    self.motors[name].setPosition(v)
            if self.robot.step(self.ts) == -1:
                sys.exit(0)
            tilt_steps = tilt_steps + 1 if self.is_fallen() else 0
            if tilt_steps * dt > 0.3:
                self.player.target = self.player.current_pose()
                return False
        self.player.target = end
        return True

    def recover(self):
        """Get up from any fall. Returns (success, seconds taken, attempts).

        back  -> GetUpBack.motion (Cyberbotics wrestling)
        front -> GetUpFront.motion, else Webots' StandUpFromFront.motion
        side  -> GetUpSide.motion, roll onto the front, then GetUpFront.motion
        """
        t0 = self.robot.getTime()
        self.step(0.5)                                   # let the robot settle first
        if self.lying_state() == "up":                   # not actually down: do nothing
            self.stand(0.5)
            return True, self.robot.getTime() - t0, 0
        roll_side = "L"
        for attempt in range(1, MAX_GETUP_ATTEMPTS + 1):
            state = self.lying_state()
            side_fall = state == "side"
            fz, lz, uz = self.torso_axes()
            print(f"  get-up attempt {attempt}: lying on {state} "
                  f"(torso forward_z={fz:.2f}, left_z={lz:.2f}, up_z={uz:.2f})")
            if state == "up":
                return True, self.robot.getTime() - t0, attempt - 1
            if state == "side":
                fz, lz, uz = self.torso_axes()
                if "GetUpSide" in self.motions:
                    # The authored clip is for the robot lying on its right side;
                    # mirror it when the torso's left axis points down instead.
                    print("  playing GetUpSide.motion")
                    seq = motion_to_sequence(self.motions["GetUpSide"])
                    if lz < 0:
                        seq = poses.mirror_sequence(seq)
                    self.player.play(seq)
                else:
                    print("  GetUpSide.motion unavailable; using shoulder push")
                    pose = {"RShoulderRoll": -1.2} if lz > 0 else {"LShoulderRoll": 1.2}
                    self.player.play([(0.4, pose), (1.0, {})])
                self.step(0.3)
                state = self.lying_state()
                print(f"  side motion ended on {state}")
                if state == "side":
                    print("  side roll did not reach the back or front; retrying")
                    continue
            if state == "back":
                if side_fall:
                    # Side recovery must reach the front before standing. Do not
                    # start the back get-up if the side roll lands supine.
                    print("  side motion reached back, not front; retrying side-to-front roll")
                    continue
                elif "GetUpBack" in self.motions:
                    self.play_motion("GetUpBack", abort_on_fall=False)
                else:
                    self.player.play(poses.rollover_sequence(roll_side))
                    self.step(0.5)
                    roll_side = "R" if roll_side == "L" else "L"
                    state = self.lying_state()
            if state == "front":
                name = "GetUpFront" if "GetUpFront" in self.motions else "StandUpFromFront"
                if side_fall:
                    print("  playing front get-up after side roll")
                self.play_motion(name, abort_on_fall=False)
            # the critical moment: straight after the get-up the robot is upright but
            # still moving, so settle and balance instead of jumping to the stand pose
            if self.torso_axes()[2] > UPRIGHT_MIN:
                if self.balanced_stand():
                    self.step(1.0)
                    if self.lying_state() == "up":
                        return True, self.robot.getTime() - t0, attempt
                print("  lost balance after getting up, trying again")
            else:
                self.step(0.5)
        return False, self.robot.getTime() - t0, MAX_GETUP_ATTEMPTS

    # ------------------------------------------------------------ test set-up
    def reset_robot(self, x=0.0, y=0.0, yaw=0.0, on_back=False):
        self.player.play([(0.05, poses.LYING if on_back else poses.STAND)])
        z = 0.12 if on_back else self.home[2]
        self.me.getField("translation").setSFVec3f([x, y, z])
        self.me.getField("rotation").setSFRotation(
            axis_angle_from_yaw_pitch(yaw, -math.pi / 2 if on_back else 0.0))
        self.me.resetPhysics()
        self.step(1.5)

    def place_ball(self, x, y):
        self.ball.getField("translation").setSFVec3f([x, y, 0.07])
        self.ball.resetPhysics()
        self.step(0.3)

    def csv_writer(self, name, header):
        f = open(os.path.join(self.log_dir, name), "w", newline="")
        w = csv.writer(f)
        w.writerow(header)
        print("Logging to", f.name)
        return f, w

    # ------------------------------------------------------------ modes
    def run_play(self):
        self.stand(1.0)
        kicks = 0
        while True:
            if self.is_fallen():
                ok, t, n = self.recover()
                print(f"Recovered: {ok} in {t:.1f} s ({n} attempts)")
                continue
            ready = self.ready_to_kick()
            if ready:
                print("Ball already in front and aligned; kicking without repositioning.")
            if ready or self.position_for_kick():
                speed, fell = self.kick()
                kicks += 1
                print(f"Kick {kicks}: peak ball speed {speed:.2f} m/s, fell: {fell}")
                self.step(1.0)
                bx, by = self.ball_pos()
                if abs(bx) > 4.5 and abs(by) < 1.3:
                    print("GOAL - resetting the ball")
                    self.place_ball(random.uniform(-1, 1), random.uniform(-1.5, 1.5))

    def run_kick_test(self):
        self.stand(1.0)
        f, w = self.csv_writer("kick_test.csv",
                               ["kick", "strength", "trial", "peak_speed_mps", "distance_m",
                                "direction_error_deg", "fell", "recovered", "recovery_s"])
        side = -1.0 if KICK_FOOT == "R" else 1.0
        labels = ["builtin"] if USE_BUILTIN_SHOOT else STRENGTHS
        for s in labels:
            for trial in range(1, KICKS_PER_STRENGTH + 1):
                self.reset_robot(0, 0, 0)
                self.place_ball(BALL_X, side * BALL_Y)
                b0 = self.ball_pos()
                speed, fell = self.kick(strength=0 if s == "builtin" else s)
                self.step(3.0)                               # let the ball roll
                b1 = self.ball_pos()
                dist = math.hypot(b1[0] - b0[0], b1[1] - b0[1])
                derr = math.degrees(math.atan2(b1[1] - b0[1], b1[0] - b0[0])) if dist > 0.02 else float("nan")
                rec, rt = "", ""
                if fell or self.is_fallen():
                    ok, t, _ = self.recover()
                    rec, rt = ok, round(t, 2)
                w.writerow(["custom" if s != "builtin" else "Shoot.motion", s, trial,
                            round(speed, 3), round(dist, 3), round(derr, 1),
                            fell, rec, rt])
                f.flush()
                print(f"strength {s} trial {trial}: {speed:.2f} m/s, {dist:.2f} m, "
                      f"direction {derr:.1f} deg, fell {fell}")
        f.close()
        print("Kick test finished.")

    def run_getup_test(self):
        f, w = self.csv_writer("getup_test.csv", ["trial", "success", "time_s", "attempts"])
        wins = 0
        for trial in range(1, GETUP_TRIALS + 1):
            self.reset_robot(0, 0, random.uniform(-math.pi, math.pi), on_back=True)
            print("Lying state after reset:", self.lying_state())
            ok, t, n = self.recover()
            wins += ok
            w.writerow([trial, ok, round(t, 2), n]); f.flush()
            print(f"Get-up trial {trial}: success {ok}, {t:.1f} s, {n} attempts")
        f.close()
        print(f"Get-up test finished: {wins}/{GETUP_TRIALS} successful.")

    def run_sensor_check(self):
        self.stand(1.0)
        print("Every 0.5 s: accelerometer and torso orientation. Drag the robot onto its")
        print("back and front (Shift + drag) and check the state reads back / front / up.")
        while True:
            self.step(0.5)
            a = self.acc_values()
            fz, lz, uz = self.torso_axes()
            print(f"acc = [{a[0]:6.2f} {a[1]:6.2f} {a[2]:6.2f}]   torso up_z = {uz:5.2f}  "
                  f"forward_z = {fz:5.2f}  ->  {self.lying_state()}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "play"
    nao = NaoKickRecovery()
    {"play": nao.run_play, "kick_test": nao.run_kick_test,
     "getup_test": nao.run_getup_test, "sensor_check": nao.run_sensor_check}.get(mode, nao.run_play)()
