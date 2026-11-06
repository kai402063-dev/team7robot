"""Locate the first observable divergence of each one-team replay from default V1."""
import argparse
from pathlib import Path

import numpy as np
from scipy.io import loadmat

from v1_matrix_evidence import file_hash, read, require, write_new


def replay(folder, case):
    worker = read(folder / "receipt.json")
    game = read(folder / case / "receipt.json")
    hashes = read(folder / case / "artifact.json")
    path = Path(worker["executionRoot"]) / game["artifact"]
    require(file_hash(path) == hashes["sha256"], f"Artifact changed: {path}")
    return loadmat(path, variable_names=["trace", "tactics"])


def first_difference(default, mixed):
    require(default.shape == mixed.shape, "Matrix shape mismatch")
    rows = np.flatnonzero(np.any(default != mixed, axis=1))
    return int(rows[0]) if len(rows) else None


def inspect(run, reference, output):
    summary = {}
    for label, team in (("red-only", 1), ("blue-only", 0)):
        cases = []
        for period in (50, 40):
            for seed in range(1, 21):
                case = f"dt{period:02d}-seed{seed:02d}"
                base = replay(reference / "v1", case)
                mixed = replay(run / label, case)
                physical = first_difference(base["trace"], mixed["trace"])
                tactics = first_difference(base["tactics"], mixed["tactics"])
                steps = [k for k in (physical, tactics) if k is not None]
                row = {"case": case,
                       "firstPhysicalStep": None if physical is None else physical + 1,
                       "firstTacticalStep": None if tactics is None else tactics + 1}
                if not steps:
                    row["classification"] = "identical"
                else:
                    k = min(steps)
                    old, new = base["tactics"], mixed["tactics"]
                    require(np.array_equal(old[:, 0], new[:, 0]), f"Clock mismatch: {case}")
                    selected_return = (k > 0 and new[k-1, 167+team] == 1 and
                                       new[k, 167+team] == 0 and old[k, 167+team] == 1)
                    row.update(classification="selected-team handback" if selected_return else "other",
                               timeSeconds=float(new[k, 0]), sameFirstPhysicalAndTacticalStep=physical == tactics,
                               defaultOwners=old[k, 5:7].astype(int).tolist(),
                               mixedOwners=new[k, 5:7].astype(int).tolist(),
                               defaultTakeover=old[k, 167:169].astype(int).tolist(),
                               mixedTakeover=new[k, 167:169].astype(int).tolist())
                cases.append(row)
        summary[label] = {"counts": {key: sum(r["classification"] == key for r in cases)
                                     for key in ("identical", "selected-team handback", "other")},
                          "cases": cases}
    write_new(output, summary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("run", type=Path)
    parser.add_argument("--reference", type=Path, required=True)
    args = parser.parse_args()
    inspect(args.run, args.reference, args.run / "first-divergences.json")
