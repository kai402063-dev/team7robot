"""Joint poses and keyframe sequences for the NAO V5 in Webots.

Angles are in radians, using the NAO joint conventions:
  HipPitch < 0 swings the leg forwards, KneePitch > 0 bends the knee,
  LHipRoll > 0 / RHipRoll < 0 move a leg outwards,
  LShoulderRoll > 0 / RShoulderRoll < 0 move an arm outwards.

A keyframe sequence is a list of (duration_s, {joint: angle}). Joints that a
frame does not mention keep their previous target.

Every number marked TUNE is a starting value. Check it in Webots and adjust;
the Webots robot window (double-click the robot) shows live joint angles.
"""

JOINTS = [
    "HeadYaw", "HeadPitch",
    "LShoulderPitch", "LShoulderRoll", "LElbowYaw", "LElbowRoll", "LWristYaw",
    "RShoulderPitch", "RShoulderRoll", "RElbowYaw", "RElbowRoll", "RWristYaw",
    "LHipYawPitch", "LHipRoll", "LHipPitch", "LKneePitch", "LAnklePitch", "LAnkleRoll",
    "RHipYawPitch", "RHipRoll", "RHipPitch", "RKneePitch", "RAnklePitch", "RAnkleRoll",
]

# Joints whose sign flips when a pose is mirrored left <-> right
_MIRROR_NEGATE = ("HeadYaw", "ShoulderRoll", "ElbowYaw", "ElbowRoll",
                  "WristYaw", "HipRoll", "AnkleRoll")

STAND = {
    "HeadYaw": 0.0, "HeadPitch": 0.0,
    "LShoulderPitch": 1.45, "LShoulderRoll": 0.20, "LElbowYaw": -1.20, "LElbowRoll": -0.50, "LWristYaw": 0.0,
    "RShoulderPitch": 1.45, "RShoulderRoll": -0.20, "RElbowYaw": 1.20, "RElbowRoll": 0.50, "RWristYaw": 0.0,
    "LHipYawPitch": 0.0, "LHipRoll": 0.0, "LHipPitch": -0.45, "LKneePitch": 0.90, "LAnklePitch": -0.45, "LAnkleRoll": 0.0,
    "RHipYawPitch": 0.0, "RHipRoll": 0.0, "RHipPitch": -0.45, "RKneePitch": 0.90, "RAnklePitch": -0.45, "RAnkleRoll": 0.0,
}

# Relaxed pose used while lying down (legs straight, arms by the sides)
LYING = dict(STAND, **{
    "LHipPitch": 0.0, "LKneePitch": 0.0, "LAnklePitch": 0.0,
    "RHipPitch": 0.0, "RKneePitch": 0.0, "RAnklePitch": 0.0,
    "LShoulderPitch": 1.5, "RShoulderPitch": 1.5,
})


def mirror(pose):
    """Swap left and right in a pose (used to build left-foot kicks etc.)."""
    out = {}
    for name, val in pose.items():
        if name[0] == "L":
            new = "R" + name[1:]
        elif name[0] == "R":
            new = "L" + name[1:]
        else:
            new = name
        if any(name.endswith(j) for j in _MIRROR_NEGATE):
            val = -val
        out[new] = val
    return out


def mirror_sequence(seq):
    return [(d, mirror(p)) for d, p in seq]


def _clamp01(x):
    return max(0.0, min(1.0, x))


# --------------------------------------------------------------------------
# Kick
# --------------------------------------------------------------------------
WEIGHT_SHIFT = 0.3  # TUNE  hip/ankle roll used to move the body over the support foot


def kick_sequence(foot="R", strength=0.7):
    """Keyframes for a forward kick with the given foot.

    strength in [0, 1] changes how far back the leg swings and how fast it
    swings through; both raise the ball speed.
    """
    s = _clamp01(strength)
    sh = -WEIGHT_SHIFT          # right-foot kick: lean over the LEFT foot
    seq = [
        (0.6, dict(STAND)),
        # 1. move the body over the support (left) foot
        (0.9, {"LHipRoll": sh, "RHipRoll": sh, "LAnkleRoll": -sh, "RAnkleRoll": -sh}),
        (0.3, {}),
        # 2. lift the kicking foot
        (0.6, {"RHipPitch": -0.85, "RKneePitch": 1.70, "RAnklePitch": -0.85}),
        # 3. back-swing (bigger for stronger kicks)                       TUNE
        (0.35, {"RHipPitch": -0.50 + 0.30 * s, "RKneePitch": 1.80, "RAnklePitch": -0.90}),
        # 4. swing through: faster and further for stronger kicks       TUNE
        (0.32 - 0.20 * s, {"RHipPitch": -1.00 - 0.25 * s, "RKneePitch": 0.35, "RAnklePitch": 0.10}),
        (0.15, {}),
        # 5. retract and put the foot down, still leaning on the support foot
        (0.5, {"RHipPitch": -0.85, "RKneePitch": 1.70, "RAnklePitch": -0.85}),
        (0.6, {"RHipPitch": -0.45, "RKneePitch": 0.90, "RAnklePitch": -0.45}),
        (0.4, {}),
        # 6. back to the centre
        (0.9, {"LHipRoll": 0.0, "RHipRoll": 0.0, "LAnkleRoll": 0.0, "RAnkleRoll": 0.0}),
        (0.4, {}),
    ]
    return seq if foot == "R" else mirror_sequence(seq)


# --------------------------------------------------------------------------
# Get-up from the back: roll onto the front, then stand up from the front
# --------------------------------------------------------------------------
def rollover_sequence(side="L"):
    """Roll from lying on the back onto the front, towards the given side.

    This is a first design to tune in Webots: arms go overhead, the far leg
    bends and swings across, and the far arm sweeps over the body.
    """
    seq = [
        (0.5, dict(LYING)),
        # arms overhead, elbows straight                                  TUNE
        (0.6, {"LShoulderPitch": -1.2, "RShoulderPitch": -1.2,
               "LShoulderRoll": 0.3, "RShoulderRoll": -0.3,
               "LElbowRoll": -0.05, "RElbowRoll": 0.05}),
        # bend the right leg and turn it towards the left                 TUNE
        (0.5, {"RHipPitch": -1.2, "RKneePitch": 1.6, "RHipRoll": 0.3,
               "LHipYawPitch": -0.6, "RHipYawPitch": -0.6}),
        # swing the right leg and right arm across, open the left arm     TUNE
        (0.4, {"RHipPitch": -1.5, "LShoulderRoll": 1.2,
               "RShoulderPitch": 0.5, "RShoulderRoll": 0.3, "HeadYaw": 1.0}),
        (0.8, {}),                              # let gravity finish the roll
        # straighten out lying on the front, arms ready to push
        (0.6, {"LHipYawPitch": 0.0, "RHipYawPitch": 0.0, "RHipRoll": 0.0,
               "RHipPitch": 0.0, "RKneePitch": 0.0, "HeadYaw": 0.0,
               "LShoulderPitch": 1.0, "RShoulderPitch": 1.0,
               "LShoulderRoll": 0.3, "RShoulderRoll": -0.3}),
        (0.4, {}),
    ]
    return seq if side == "L" else mirror_sequence(seq)
