"""Fingerprint the V1 runtime and aggregate only complete verified match shards."""
from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def file_hash(path):
    digest = sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_new(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write("\n")


def read(path):
    return json.loads(path.read_text())


def sources(destination):
    files = set()
    for group in ("algorithms", "controllers", "interfaces", "environment"):
        files.update((ROOT / group).rglob("*.m"))
    files.update((ROOT / "models").glob("*.sldd"))
    files.update(ROOT / "models" / name for name in ("ControllerCore.slx", "tdpV1Match.slx"))
    files.update(ROOT / "scripts" / name for name in (
        "build_match.m", "build_v1_match.m", "build_types.m", "build_controller.m",
        "add_matlab_block.m", "configure_model.m", "set_data_size.m", "runMatch.m",
        "matchSimulationInput.m", "recordRows.m", "matchMetrics.m", "v1MatchMetrics.m",
        "v1TraceColumns.m", "validate_v1_matrix.m", "v1_matrix_evidence.py"))
    for name in ('models/tdpRecoveryMatch.slx', 'scripts/build_recovery_match.m',
                 'scripts/v1RecoveryColumns.m', 'scripts/recoveryMatchMetrics.m',
                 'scripts/compare_recovery.py', 'models/tdpTeamRecoveryMatch.slx',
                 'scripts/build_team_recovery_match.m'):
        source = ROOT / name
        if source.is_file():
            files.add(source)
    files.add(ROOT / "tdpSetup.m")
    hashes = {str(path.relative_to(ROOT)): file_hash(path) for path in sorted(files)}
    revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    digest = sha256(json.dumps(hashes, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    write_new(destination, {"revision": revision, "fingerprint": digest, "files": hashes})


def artifact(path, destination):
    import numpy as np
    from scipy.io import loadmat
    arrays = loadmat(path, variable_names=["trace", "tactics", "recovery"])
    data = {"sha256": file_hash(path), "bytes": path.stat().st_size, "arrays": {}}
    for key in (["trace", "tactics", "recovery"] if "recovery" in arrays else ["trace", "tactics"]):
        matrix = np.ascontiguousarray(arrays[key], dtype="<f8")
        data["arrays"][key] = {
            "shape": list(matrix.shape),
            "sha256LittleEndianDoublesRowMajor": sha256(memoryview(matrix).cast("B")).hexdigest(),
            "finite": bool(np.isfinite(matrix).all()),
        }
    write_new(destination, data)


def require(condition, explanation):
    if not condition:
        raise ValueError(explanation)


def summarize(destination, shards):
    destination.mkdir(parents=True, exist_ok=False)
    records = {}
    fingerprints = set()
    revisions = set()
    try:
        for shard in shards:
            worker = read(shard / "receipt.json")
            require(worker["status"] == "PASS_SHARD", f"Incomplete shard {shard}")
            before, after = [read(shard / f"source-{side}.json") for side in ("before", "after")]
            require(before["fingerprint"] == after["fingerprint"] == worker["sourceFingerprint"],
                    f"Source drift in {shard}")
            fingerprints.add(before["fingerprint"])
            revisions.add(worker["revision"])
            matches = sorted(shard.glob("dt*-seed*/receipt.json"))
            require(len(matches) == worker["completedMatches"], f"Receipt count mismatch in {shard}")
            for match in matches:
                item = read(match)
                p = item["parameters"]
                m = item["metrics"]
                dt, seed = p["dt"], p["seed"]
                key = (dt, seed)
                require(key not in records, f"Duplicate match {key}")
                require(item["status"] == "PASS" and not item["violations"] and m["passed"], f"Failed {key}")
                require(item["sourceFingerprint"] == before["fingerprint"] and
                        item["revision"] == worker["revision"], f"Match source mismatch {key}")
                require(p["Tmatch"] == m["simulationSeconds"] == 600 and
                        m["steps"] == round(600/dt) and m["period"] == dt, f"Incomplete timebase {key}")
                if seed == 1:
                    replay = item["replay"]
                    require(replay["samePhysicalTrace"] and replay["sameTacticalTrace"]
                            and replay["steps"] == m["steps"], f"Replay mismatch {key}")
                stored = read(match.parent / "artifact.json")
                path = Path(worker["executionRoot"]) / item["artifact"]
                require(file_hash(path) == stored["sha256"], f"Artifact changed {path}")
                trace = stored["arrays"]["trace"]
                tactics = stored["arrays"]["tactics"]
                require(trace["shape"] == [m["steps"], 98] and tactics["shape"][0] == m["steps"]
                        and trace["finite"] and tactics["finite"], f"Artifact shape/finite gate failed {key}")
                records[key] = {
                    "period": dt, "seed": seed, "steps": m["steps"], "metrics": m,
                    "elapsedSeconds": item["elapsedSeconds"],
                    "traceDigest": trace["sha256LittleEndianDoublesRowMajor"],
                    "tacticsDigest": tactics["sha256LittleEndianDoublesRowMajor"],
                    "artifactSha256": stored["sha256"],
                    "receipt": f"{shard.name}/{match.parent.name}/receipt.json",
                }
        expected = {(dt, seed) for dt in (.05, .04) for seed in range(1, 21)}
        require(set(records) == expected, f"Missing or extra cases {sorted(expected ^ set(records))}")
        require(len(fingerprints) == len(revisions) == 1, "Shards used different sources or revisions")
        groups = []
        for dt in (.05, .04):
            rows = [records[(dt, seed)] for seed in range(1, 21)]
            metrics = [row["metrics"] for row in rows]
            by_team = lambda field: [sum(m[field][team] for m in metrics) for team in range(2)]
            total = lambda field: sum(m[field] for m in metrics)
            scores = by_team("goals")
            scored = sum(any(m["goals"]) for m in metrics)
            first = [m["firstTouchSeconds"] for m in metrics if m["firstTouchSeconds"] is not None]
            distinct = len({r["traceDigest"] for r in rows})
            require(distinct > 1, f"All twenty noisy physical trajectories are identical at {dt}s")
            require(sum(by_team("actualKicksByTeam")) > 0 and total("physicalKickStepsWithBallMotion") > 0,
                    f"No physical kick and motion demonstrated at {dt}s")
            groups.append({
                "period": dt, "matches": len(rows), "steps": total("steps"), "distinctTraces": distinct,
                "goals": scores, "matchesWithGoal": scored, "shots": by_team("shots"),
                "actualKicks": by_team("actualKicksByTeam"), "midfielderShots": by_team("midfielderShots"),
                "takeoverEntries": by_team("takeoverEntries"), "takeoverSeconds": by_team("takeoverSeconds"),
                "phaseSwitches": by_team("phaseSwitches"), "chaserChanges": by_team("chaserChanges"),
                "firstTouchRangeSeconds": [min(first),max(first)] if first else [],
                "matchesWithoutTouch": len(rows)-len(first), "overlapSteps": total("overlapSteps"),
                "maximumPenetrationMetres": max(m["maximumPenetrationMetres"] for m in metrics),
                "outsidePitchRobotSamples": total("outsidePitchRobotSamples"),
                "outsideBorderRobotSamples": total("outsideBorderRobotSamples"),
                "blockedTranslationSamples": total("blockedTranslationSamples"),
                "translationRequests": total("translationRequests"),
                "blockedTranslationRatio": total("blockedTranslationSamples")/max(1,total("translationRequests")),
                "physicalKickStepsWithBallMotion": total("physicalKickStepsWithBallMotion"),
            })
        result = {"status": "PASS_40_V1_MATCHES", "revision": next(iter(revisions)),
                  "sourceFingerprint": next(iter(fingerprints)), "officialMatches": 40,
                  "additionalFullSeedOneReplays": 2, "totalOfficialSteps": sum(x["steps"] for x in groups),
                  "periods": groups, "matches": [records[key] for key in sorted(records)]}
        write_new(destination / "receipt.json", result)
    except Exception as error:
        write_new(destination / "receipt.json", {"status": "FAIL", "verifiedDistinctCases": len(records),
                                              "error": repr(error)})
        raise


if __name__ == "__main__":
    parser = ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("sources").add_argument("out", type=Path)
    a = sub.add_parser("artifact")
    a.add_argument("path", type=Path)
    a.add_argument("out", type=Path)
    s = sub.add_parser("summarize")
    s.add_argument("out", type=Path)
    s.add_argument("shards", type=Path, nargs="+")
    args = parser.parse_args()
    if args.action == "sources":
        sources(args.out)
    elif args.action == "artifact":
        artifact(args.path, args.out)
    else:
        summarize(args.out, args.shards)
