"""Read two existing 50 ms, seed 1 V1 match receipts. Write only JSON to stdout."""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path

import numpy as np
from scipy.io import loadmat


def read_game(receipt_path, override=None):
    receipt = json.loads(receipt_path.read_text())
    audit = json.loads(receipt_path.with_name("artifact.json").read_text())
    p = receipt["parameters"]
    assert receipt["status"] == "PASS" and (p["dt"], p["seed"], p["Tmatch"]) == (.05, 1, 600)
    if override is None:
        candidates = (folder / receipt["artifact"] for folder in receipt_path.resolve().parents)
        override = next((file for file in candidates if file.is_file()), None)
        if override is None:
            raise FileNotFoundError("Missing archived MAT; supply both trajectories with --mats.")
    assert sha256(override.read_bytes()).hexdigest() == audit["sha256"]
    arrays = loadmat(override, variable_names=["trace", "tactics"])
    digests = {}
    for name, width in (("trace", 98), ("tactics", 171)):
        array = np.ascontiguousarray(arrays[name], dtype="<f8")
        assert array.shape == (12000, width) and np.isfinite(array).all()
        digests[name] = sha256(array.tobytes()).hexdigest()
        assert digests[name] == audit["arrays"][name]["sha256LittleEndianDoublesRowMajor"]
    return arrays, receipt, digests


def quantiles(numbers):
    return dict(zip(("minimum", "median", "maximum"), np.percentile(numbers, [0, 50, 100]).tolist()))


def inspect_shots(trace, tactics, p):
    # Post-step-state columns from MatchRecord; tactical fields from v1TraceColumns.
    t, kicker = tactics[:, 0], tactics[:, 14].astype(int)
    xy, velocity = trace[:, 56:58], trace[:, 58:60]
    robots = np.stack((trace[:, :8], trace[:, 8:16]), axis=2)
    robot_v = np.stack((trace[:, 24:32], trace[:, 32:40]), axis=2)
    kicks = np.flatnonzero(kicker)
    speeds = tactics[kicks, 158 + kicker[kicks]]
    shots = kicks[(kicker[kicks] <= 4) & (speeds >= p["shotSpeed"])]
    counts = np.diff(trace[:, 65], prepend=0)
    assert np.array_equal(shots, np.flatnonzero(counts == 1)) and counts.sum() == len(shots)
    radius = p["robotR"] + p["ballR"]
    touches = np.isclose(np.linalg.norm(xy[:, None, :] - robots, axis=2), radius,
                         atol=1e-9, rtol=0)
    goal = np.array([p["L"]/2, 0])
    delays, travel, struck, impulse_errors, free_scores = [], [], Counter(), [], []
    same_step, unobserved = 0, 0
    dt, dv = p["dt"], p["ballDecel"] * p["dt"]
    for start in shots:
        assert start > 0
        end = next((idx for idx in kicks if idx > start), len(t))
        # Exclude any restart that would replace the ball before a defensive touch.
        stops = np.flatnonzero((tactics[start:end, 13] == 0) |
                               (trace[start:end, 64] > t[start:end]))
        if len(stops):
            end = start + stops[0]
        hits = np.flatnonzero(touches[start:end, 4:].any(axis=1))
        if not len(hits):
            unobserved += 1
            continue
        hit = int(start + hits[0])
        opponent = np.flatnonzero(touches[hit, 4:]) + 4
        assert len(opponent) == 1 and trace[hit, 63] == 2
        defender = opponent[0]
        struck[int(defender+1)] += 1
        delays.append(t[hit] - t[start])
        travel.append(np.linalg.norm(xy[hit] - xy[start-1]))
        if hit == start:
            same_step += 1
            continue

        # First-step output is a free launch only if no ball contact or reset intervened.
        speed = tactics[start, 158 + kicker[start]]
        assert not touches[start].any() and np.isclose(np.linalg.norm(velocity[start]), speed-dv)
        direction = velocity[start] / np.linalg.norm(velocity[start])
        samples = np.arange(1, int(np.ceil(speed/dv)) + 1)
        distance = np.cumsum(np.maximum(0, speed - samples*dv)) * dt
        free_path = xy[start-1] + distance[:, None]*direction
        first_exit = np.flatnonzero((np.abs(free_path[:, 0]) > goal[0]+p["ballR"]) |
                                    (np.abs(free_path[:, 1]) > p["W"]/2+p["ballR"]))
        free_scores.append(bool(len(first_exit) and free_path[first_exit[0], 0] > goal[0]+p["ballR"]
                                and abs(free_path[first_exit[0], 1])+p["ballR"] < p["goalW"]/2))

        # Reconstruct exactly the defensive contact step from the saved previous velocity.
        old_v = velocity[hit-1]
        free_v = old_v * (max(0, np.linalg.norm(old_v)-dv) / np.linalg.norm(old_v))
        offset = xy[hit-1] + dt*free_v - robots[hit, defender]
        assert 0 < np.linalg.norm(offset) < radius
        normal = offset / np.linalg.norm(offset)
        closing = (free_v - robot_v[hit, defender]) @ normal
        assert closing < 0
        predicted = free_v - (1+p["ballRobotE"])*closing*normal
        impulse_errors.append(np.linalg.norm(velocity[hit]-predicted))
    red = kicks[kicker[kicks] > 4]
    return {
        "goalsBlueRed": trace[-1, 61:63].astype(int).tolist(),
        "shotsBlueRed": trace[-1, 65:67].astype(int).tolist(),
        "blueShotDistanceToGoalCentreMetres": quantiles(np.linalg.norm(xy[shots-1]-goal, axis=1)),
        "blueShotCountsByGlobalRobot": dict(Counter(kicker[shots].tolist())),
        "firstOpponentContactByGlobalRobot": dict(struck),
        "shotsWithoutObservedOpponentContactBeforeKickOrRestart": unobserved,
        "secondsUntilFirstOpponentContact": quantiles(delays),
        "displacementToFirstOpponentContactMetres": quantiles(travel),
        "sameStepLaunchAndOpponentContact": same_step,
        "reconstructedImpulses": len(impulse_errors),
        "maximumVelocityReconstructionErrorMetresPerSecond": max(impulse_errors),
        "freeRollEligible": len(free_scores), "freeRollScored": sum(free_scores),
        "redAttackSamples": int((tactics[:, 2] == 2).sum()),
        "firstLastRedAttackSeconds": t[tactics[:, 2] == 2][[0,-1]].tolist(),
        "redPhaseSampleCounts": dict(Counter(tactics[:, 2].astype(int).tolist())),
        "minimumBallXMetres": float(xy[:, 0].min()),
        "samplesBeyondMidlineInRedAttackingDirection": int((xy[:, 0] < -p["v1MidlineBand"]).sum()),
        "redActualKicks": [{"time": float(t[i]), "robot": int(kicker[i]), "phase": int(tactics[i, 2]),
                            "speed": float(tactics[i, 158+kicker[i]])} for i in red],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("preflight", type=Path)
    parser.add_argument("formal", type=Path)
    parser.add_argument("--mats", nargs=2, type=Path, default=[None, None])
    args = parser.parse_args()
    first, old_receipt, old_hashes = read_game(args.preflight, args.mats[0])
    final, receipt, hashes = read_game(args.formal, args.mats[1])
    assert old_hashes == hashes and all(np.array_equal(first[k], final[k]) for k in hashes)
    stats = inspect_shots(final["trace"], final["tactics"], receipt["parameters"])
    print(json.dumps({"period": .05, "seed": 1, "seconds": 600, "sameArrays": True,
                      "sha256LittleEndianDoublesRowMajor": hashes,
                      "preflightRevision": old_receipt["revision"], "formalRevision": receipt["revision"],
                      "review": stats}, indent=2, allow_nan=False))
