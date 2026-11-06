"""Independently audit red shots from the four complete policy campaigns.

From the project root:
  python3 evidence/team-ablation/audit-01/inspect_red_shots.py \
    evidence/team-ablation/clean-01 evidence/recovery-v1/clean-01 \
    --output build/recomputed-red-shots.json

Omit --output to write JSON to stdout. The per-shard executionRoot and per-game
artifact path must resolve to the retained MAT files. For regenerated endpoint
runs, supply the new reference directory containing the v1 and recovery shards.
"""

import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path

import numpy as np
from scipy.io import loadmat


METHOD = {
    "unit": "A red physical shot requires red MF (global 7) or ST (8) actually kicking at requested speed >= shotSpeed. Exact increments checked against red referee shot counter.",
    "samples": "Each condition: 20 seeds at each 50/40 ms, 600 s. Raw MAT SHA-256 verified against each artifact receipt.",
    "firstOpponent": "Search from shot step inclusive to earliest next active kick by either side, stop/restart or end, exclusive. Identify first sample with post-step ball-to-blue-centre distance equal to robot radius + ball radius (0.22 m, absolute tolerance 1e-9 m) and lastTouch=blue (1). First blue player 2 is DF. Separate ambiguous multiple contacts from unambiguous role counts.",
    "goals": "A subsequent goal requires a red scoreboard increment after that shot with no intervening active kick or restart. A defender contact can still precede a goal.",
    "staticLine": "Centre-line clearance uses the previous-step ball and blue DF position. Blue DF blocks if its projection lies inside the ball-to-red-target-goal-centre segment and perpendicular distance <= 0.22 m. This geometric proxy does not require an actual contact.",
    "lastTouch": "Intermediate contacts within one step can be unobservable; counts are based on logged post-step positions, not simulator collision callbacks.",
}
FIELDS = (
    "matches", "redShots", "redMFShots", "redSTShots", "redGoals",
    "redMFShotsWithSubsequentGoal", "redSTShotsWithSubsequentGoal",
    "shotsFirstOpponentIsBlueDF", "mfShotsFirstOpponentIsBlueDF", "stShotsFirstOpponentIsBlueDF",
    "shotsFirstOpponentIsBlueGK", "shotsFirstOpponentIsBlueMF", "shotsFirstOpponentIsBlueST",
    "shotsNoRecognizableOpponentContact", "shotsFirstOpponentAmbiguous",
    "shotsWithSubsequentGoalAfterFirstBlueDF", "shotsClearOfStaticBlueDFCentreLine",
    "clearShotsWithSubsequentGoal",
)
BLUE_ROLES = ("GK", "DF", "MF", "ST")


def read_json(path):
    return json.loads(path.read_text())


def require(check, message):
    if not check:
        raise ValueError(message)


def scan_game(folder, execution_root, period_ms, seed):
    report = read_json(folder / "receipt.json")
    p = report["parameters"]
    require(report["status"] == "PASS" and p["seed"] == seed and
            p["dt"] == period_ms / 1000 and p["Tmatch"] == 600, f"Incomplete or wrong game: {folder}")
    path = execution_root / report["artifact"]
    require(sha256(path.read_bytes()).hexdigest() == read_json(folder / "artifact.json")["sha256"],
            f"MAT SHA-256 mismatch: {path}")
    mat = loadmat(path, variable_names=["trace", "tactics"])
    trace, tactics = mat["trace"], mat["tactics"]
    # Fixed columns from MatchRecord.m and v1TraceColumns.m.
    time = tactics[:, 0]
    kicker = tactics[:, 14].astype(int)
    kicks = np.flatnonzero(kicker)
    red_shots = kicks[(kicker[kicks] >= 7) & (tactics[kicks, 158 + kicker[kicks]] >= p["shotSpeed"])]
    referee_shots = np.flatnonzero(np.diff(trace[:, 66], prepend=0) == 1)
    require(np.array_equal(red_shots, referee_shots) and len(red_shots) == report["metrics"]["shots"][1],
            f"Physical red shots differ from referee: {folder}")

    ball = trace[:, 56:58]
    blue = np.stack((trace[:, :4], trace[:, 8:12]), axis=-1)
    radius = p["robotR"] + p["ballR"]
    contacts = np.isclose(np.linalg.norm(ball[:, None] - blue, axis=2), radius, atol=1e-9, rtol=0)
    restarts = np.flatnonzero((tactics[:, 13] == 0) | (trace[:, 64] > time))
    goals = np.flatnonzero(np.diff(trace[:, 62], prepend=0) == 1)
    converted = set()
    for goal in goals:
        previous = int(np.searchsorted(kicks, goal, side="right")) - 1
        require(previous >= 0, f"No active shot before a red goal: {folder}")
        shot = kicks[previous]
        require(shot in red_shots and not np.any((restarts > shot) & (restarts < goal)),
                f"Red goal does not follow a red shot in open play: {folder}")
        converted.add(shot)

    counts = Counter(matches=1, redShots=len(red_shots), redGoals=len(goals))
    distances = []
    # Sentinels bound the search at match end without treating it as a kick.
    kick_boundaries = np.append(kicks, len(time))
    restart_boundaries = np.append(restarts, len(time))
    for shot in red_shots:
        role = "MF" if kicker[shot] == 7 else "ST"
        counts[f"red{role}Shots"] += 1
        scored = shot in converted
        counts[f"red{role}ShotsWithSubsequentGoal"] += int(scored)

        require(shot > 0, f"Missing pre-shot sample: {folder}")
        start = ball[shot - 1]
        direction = np.array([-p["L"] / 2, 0]) - start
        distance = np.linalg.norm(direction)
        distances.append(float(distance))
        unit = direction / distance
        defender = blue[shot - 1, 1] - start
        offset = abs(unit[0] * defender[1] - unit[1] * defender[0])
        clear = not (0 < unit @ defender < distance and offset <= radius)
        counts["shotsClearOfStaticBlueDFCentreLine"] += int(clear)
        counts["clearShotsWithSubsequentGoal"] += int(clear and scored)

        end = min(kick_boundaries[np.searchsorted(kicks, shot, side="right")],
                  restart_boundaries[np.searchsorted(restarts, shot)])
        candidates = np.flatnonzero(contacts[shot:end].any(axis=1) & (trace[shot:end, 63] == 1))
        if not len(candidates):
            counts["shotsNoRecognizableOpponentContact"] += 1
            continue
        players = np.flatnonzero(contacts[shot + candidates[0]])
        if len(players) > 1:
            counts["shotsFirstOpponentAmbiguous"] += 1
            continue
        blue_role = BLUE_ROLES[players[0]]
        counts["shotsFirstOpponentIsBlue" + blue_role] += 1
        if blue_role == "DF":
            counts[role.lower() + "ShotsFirstOpponentIsBlueDF"] += 1
            counts["shotsWithSubsequentGoalAfterFirstBlueDF"] += int(scored)
    return counts, distances


def summarize(counts, distances):
    result = {key: int(counts[key]) for key in FIELDS}
    shots = result["redShots"]
    identified = sum(result["shotsFirstOpponentIsBlue" + role] for role in BLUE_ROLES)
    require(shots == identified + result["shotsNoRecognizableOpponentContact"] +
            result["shotsFirstOpponentAmbiguous"], "Missing or duplicate first-contact classification")
    require(shots == result["redMFShots"] + result["redSTShots"] and
            result["redGoals"] == result["redMFShotsWithSubsequentGoal"] +
            result["redSTShotsWithSubsequentGoal"], "Red role totals are inconsistent")
    result["fractionFirstOpponentBlueDF"] = result["shotsFirstOpponentIsBlueDF"] / shots if shots else None
    result["medianShotDistanceToGoalCentreM"] = float(np.median(distances)) if distances else None
    return result


def inspect(shard):
    run = read_json(shard / "receipt.json")
    require(run["status"] == "PASS_SHARD" and run["completedMatches"] == 40,
            f"Expected 40 completed games: {shard}")
    counts = Counter()
    distances = []
    by_period = {}
    for period in (50, 40):
        group_counts = Counter()
        group_distances = []
        for seed in range(1, 21):
            folder = shard / f"dt{period}-seed{seed:02d}"
            c, ds = scan_game(folder, Path(run["executionRoot"]), period, seed)
            group_counts.update(c)
            group_distances.extend(ds)
        by_period[str(period)] = summarize(group_counts, group_distances)
        counts.update(group_counts)
        distances.extend(group_distances)
    return {"all": summarize(counts, distances), "periodMs": by_period}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path, help="Run containing red-only and blue-only")
    parser.add_argument("reference", type=Path, help="Archived or freshly reproduced v1 and recovery endpoints")
    parser.add_argument("--output", type=Path, help="New JSON file; defaults to stdout")
    args = parser.parse_args()
    if args.output is not None:
        require(not args.output.exists(), f"Output already exists: {args.output}")
    paths = dict(default=args.reference / "v1", redOnly=args.run / "red-only",
                 blueOnly=args.run / "blue-only", both=args.reference / "recovery")
    result = {"method": METHOD, "conditions": {key: inspect(path) for key, path in paths.items()}}
    content = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.output is None:
        print(content, end="")
    else:
        with args.output.open("x") as stream:
            stream.write(content)


if __name__ == "__main__":
    main()
