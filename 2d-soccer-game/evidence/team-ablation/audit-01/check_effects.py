"""Cross-check red goals from referee receipts; omit both periods of one seed at a time."""
import json
import sys
from pathlib import Path

def read(path):
    return json.loads(path.read_text())

def effects(cases):
    default, red, blue, both = (sum(case[key] for case in cases) for key in ("D", "R", "B", "A"))
    return {
        "redGoalsDefaultRedOnlyBlueOnlyBoth": [default, red, blue, both],
        "redAlone": red-default, "blueAlone": blue-default,
        "redGivenAutomaticBlue": both-blue, "blueGivenAutomaticRed": both-red,
        "interaction": both-red-blue+default,
        "redOrderAverage": ((red-default)+(both-blue))/2,
        "blueOrderAverage": ((blue-default)+(both-red))/2,
    }

def check(run, reference):
    records = []
    policy_dirs = {"D": reference/"v1", "R": run/"red-only", "B": run/"blue-only", "A": reference/"recovery"}
    for seed in range(1,21):
        for ms in (50,40):
            name = f"dt{ms}-seed{seed:02d}"
            row = {"seed": seed, "periodMs": ms}
            for label, directory in policy_dirs.items():
                receipt = read(directory/name/"receipt.json")
                assert receipt["status"] == "PASS" and not receipt["violations"]
                row[label] = receipt["metrics"]["goals"][1]
            records.append(row)
    result = effects(records)
    other = read(run/"analysis.json")["all"]["redGoalEffects"]
    assert all(result[k] == other[k] for k in ("interaction","redOrderAverage","blueOrderAverage"))
    excluded = []
    for s in range(1,21):
        excluded.append({"omittedSeed":s, **effects([r for r in records if r["seed"]!=s])})
    return {"method":"All counts from the 160 individual referee receipts. Delete both periods for each omitted seed. Sensitivity within these conditions only.",
            "overall":result, "byPeriod":{ms:effects([r for r in records if r["periodMs"]==ms]) for ms in (50,40)},
            "leaveOneSeedOut":excluded}

if __name__ == "__main__":
    run, reference, output = map(Path, sys.argv[1:])
    with output.open("x") as stream:
        json.dump(check(run, reference),stream,indent=2);stream.write("\n")
