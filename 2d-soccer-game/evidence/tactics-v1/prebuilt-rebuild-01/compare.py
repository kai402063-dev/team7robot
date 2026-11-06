"""Compare saved complete shipped and rebuilt simulation outputs from fixed sources."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import subprocess

import numpy as np
from scipy.io import loadmat


def read(path):
    return json.loads(path.read_text())


def main(shipped, rebuilt_evidence):
    command = read(shipped / "command.json")
    assert command["status"] == "PASS" and command["exitCode"] == 0 and not command["rebuild"]
    root = Path(command["executionRoot"])
    worker = read(rebuilt_evidence / "matches/receipt.json")
    assert worker["status"] == "PASS_SHARD" and worker["revision"] == command["commit"]
    assert read(rebuilt_evidence / "receipt.json")["rebuild"]
    original = read(shipped / "source-before.json")
    assert original == read(shipped / "source-after.json")
    rebuilt = read(rebuilt_evidence / "matches/source-before.json")
    assert rebuilt == read(rebuilt_evidence / "matches/source-after.json")
    assert original["revision"] == rebuilt["revision"] == worker["revision"]
    assert original["files"].keys() == rebuilt["files"].keys()
    assert not subprocess.check_output(["git","status","--porcelain","--untracked-files=no"],cwd=root).strip()
    generated = {}
    for path, digest in original["files"].items():
        blob = subprocess.check_output(["git","show",f"{worker['revision']}:{path}"],cwd=root)
        assert sha256(blob).hexdigest() == digest
        if path.endswith((".slx",".sldd")):
            generated[path] = {"shipped":digest,"rebuilt":rebuilt["files"][path]}
        else:
            assert digest == rebuilt["files"][path], path
    rows = []
    for ms in (50,40):
        info = read(shipped / f"run-{ms}ms.json")
        formal = rebuilt_evidence / "matches" / f"dt{ms}-seed01"
        match = read(formal / "receipt.json")
        assert info["parameters"] == match["parameters"] and info["metrics"]["passed"] and not info["violations"]
        files = [shipped / f"prebuilt-{ms}ms.mat", Path(worker["executionRoot"]) / match["artifact"]]
        hashes = [read(shipped / f"prebuilt-{ms}ms.json"), read(formal / "artifact.json")]
        for i in range(2):
            assert sha256(files[i].read_bytes()).hexdigest() == hashes[i]["sha256"]
        saved = [loadmat(path,variable_names=["trace","tactics"]) for path in files]
        arrays = {}
        for name in ("trace","tactics"):
            left, right = [x[name] for x in saved]
            assert left.shape == right.shape and left.dtype == right.dtype == np.float64
            assert left.shape[0] == round(600/(ms/1000))
            assert hashes[0]["arrays"][name] == hashes[1]["arrays"][name]
            eq = bool(np.array_equal(left,right))
            max_abs = float(np.max(np.abs(left-right)))
            assert eq and max_abs == 0
            arrays[name] = {"shape":list(left.shape),"arrayEqual":eq,"maxAbsDifference":max_abs,
                            "commonSha256":hashes[0]["arrays"][name]["sha256LittleEndianDoublesRowMajor"]}
        rows.append({"seed":info["seed"],"periodSeconds":ms/1000,"matchSeconds":info["seconds"],
                     "arrays":arrays,"shippedMatSha256":hashes[0]["sha256"],"rebuiltMatSha256":hashes[1]["sha256"]})
    return {"status":"PASS","revision":worker["revision"],"additionalMatchesOutsideOfficialMatrix":len(rows),
            "shippedSourceFingerprint":original["fingerprint"],"rebuiltSourceFingerprint":rebuilt["fingerprint"],
            "bothSourceFingerprintsStableDuringRuns":True,"shippedRuntimeSourcesMatchGitByteForByte":True,
            "identicalNonModelSources":True,"shippedTrackedWorktreeCleanAfterRuns":True,
            "generatedBinaries":generated,"matches":rows,
            "scope":"Two actual 600-second, seed-1 runs using committed binaries were compared with the rebuilt model. The earlier source-drift preflight remains failed."}


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("shipped", type=Path)
    parser.add_argument("rebuilt_evidence",type=Path)
    args=parser.parse_args()
    print(json.dumps(main(args.shipped,args.rebuilt_evidence),indent=2))
