"""Plays keyframe sequences and Webots .motion files on the NAO.

Unlike the built-in Motion class, this player can scale time (play a
motion faster or slower), stop part-way, blend smoothly from the current
pose, and call a check function every step (for fall detection).
"""
import math


def load_motion_file(path):
    """Read a Webots .motion file into (joints, [(time_s, {joint: angle})])."""
    with open(path) as f:
        lines = [ln.strip() for ln in f if ln.strip()]
    header = lines[0].split(",")
    if not header[0].startswith("#WEBOTS_MOTION"):
        raise ValueError(f"{path} is not a Webots motion file")
    joints = header[2:]
    frames = []
    for ln in lines[1:]:
        if ln.startswith("#"):
            continue
        cols = ln.split(",")
        m, s, ms = (int(x) for x in cols[0].split(":"))
        t = 60 * m + s + ms / 1000.0
        pose = {}
        for name, val in zip(joints, cols[2:]):
            val = val.strip()
            if val not in ("", "*"):
                pose[name] = float(val)
        frames.append((t, pose))
    return joints, frames


def motion_to_sequence(frames, time_scale=1.0, blend_in=0.3, stop_after=None):
    """Convert motion-file frames to a keyframe sequence.

    time_scale > 1 plays slower, < 1 faster. stop_after (s, in the
    original timing) cuts the motion short.
    """
    seq = []
    prev_t = None
    for t, pose in frames:
        if stop_after is not None and t > stop_after:
            break
        if prev_t is None:
            seq.append((blend_in, pose))
        else:
            seq.append((max(t - prev_t, 1e-3) * time_scale, pose))
        prev_t = t
    return seq


class MotionPlayer:
    def __init__(self, robot, motors, sensors, time_step_ms):
        self.robot = robot
        self.motors = motors
        self.sensors = sensors
        self.dt = time_step_ms / 1000.0
        self.ts = time_step_ms
        self.target = {}
        self.frame_index = 0
        self.limits = {}
        for name, m in motors.items():
            lo, hi = m.getMinPosition(), m.getMaxPosition()
            self.limits[name] = (lo, hi) if lo < hi else None

    def _clamp(self, name, val):
        lim = self.limits.get(name)
        if lim is None:
            return val
        return min(max(val, lim[0]), lim[1])

    def current_pose(self):
        """Measured joint angles. Sensors read NaN until the first simulation
        step, so fall back to the last target (or 0) instead of passing NaN on."""
        pose = {}
        for name in self.motors:
            s = self.sensors.get(name)
            val = s.getValue() if s else float("nan")
            if val != val:                                  # NaN check
                val = self.target.get(name, 0.0)
                if val != val:
                    val = 0.0
            pose[name] = val
        return pose

    def play(self, sequence, check=None, from_sensors=False, ease=True):
        """Play a keyframe sequence.

        ease=True eases in and out of every keyframe (good for hand-made poses);
        ease=False interpolates linearly, as Webots' Motion class does, which
        keeps the joints moving through the frames of a recorded motion such
        as a walk.

        check() is called every step; if it returns True the motion stops
        and play() returns 'aborted'. Returns 'done', or 'quit' when the
        simulation ends.
        """
        if from_sensors or not self.target:
            self.target = self.current_pose()
        for self.frame_index, (duration, pose) in enumerate(sequence):
            start = dict(self.target)
            end = dict(start)
            for name, val in pose.items():
                if name in self.motors and val == val:
                    end[name] = self._clamp(name, val)
            n = max(1, int(round(duration / self.dt)))
            for k in range(1, n + 1):
                a = 0.5 - 0.5 * math.cos(math.pi * k / n) if ease else k / n
                for name in end:
                    v = start[name] + a * (end[name] - start[name])
                    if v == v:                                  # never send NaN to a motor
                        self.motors[name].setPosition(v)
                if self.robot.step(self.ts) == -1:
                    return "quit"
                if check is not None and check():
                    self.target = self.current_pose()
                    return "aborted"
            self.target = end
        return "done"

    def hold(self, seconds, check=None):
        return self.play([(seconds, {})], check=check)
