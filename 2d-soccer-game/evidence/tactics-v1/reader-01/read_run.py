"""Cross-read the public 98/171-column records of a saved ten-second run."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(array):
    packed = np.ascontiguousarray(array, dtype="<f8")
    return sha256(memoryview(packed).cast("B"))


mat_path, columns_path = map(Path, sys.argv[1:])
saved = loadmat(mat_path, variable_names=["trace", "tactics"])
t, v = saved["trace"], saved["tactics"]
columns = json.loads(columns_path.read_text())
c = {key: np.asarray(value) - 1 for key, value in columns.items()}
receipt = json.loads(mat_path.with_name("receipt.json").read_text())
p = receipt["parameters"]
frames = round(p["Tmatch"] / p["dt"])
assert receipt["status"] == "COMPLETED" and p["Tmatch"] == 10 and p["v1Enabled"]
assert (t.shape, v.shape) == ((frames, 98), (frames, 171))
assert np.isfinite(t).all() and np.isfinite(v).all()
np.testing.assert_array_equal(t[:, 60], v[:, c["time"]])
np.testing.assert_allclose(t[:, 60], np.arange(1, frames + 1) * p["dt"], atol=1e-12, rtol=0)
roles = [1, 3, 5, 2, 1, 3, 5, 2]
np.testing.assert_array_equal(t[:, 48:56], [roles] * frames)
chasers = v[:, c["chaser"]].astype(int)
np.testing.assert_array_equal(t[:, 70:72], np.where(chasers, (chasers - 1) % 4 + 1, 0))
hits = np.flatnonzero(v[:, c["kicker"]] > 0)
np.testing.assert_array_equal(hits, np.flatnonzero(t[:, 96]))
assert len(hits) > 0
for i in hits:
    actor = int(v[i, c["kicker"]])
    assert actor == chasers[i, (actor - 1) // 4]
    assert v[i, c["status"][actor - 1]] == 2
    assert v[i, c["requestId"][actor - 1]] == v[i, c["feedbackId"][actor - 1]]
    assert v[i, c["kind"][actor - 1]] in (2, 4)

# Show the first physical kick, just as the reader command does.
first = hits[0]
actor = int(v[first, c["kicker"]]); team = (actor - 1) // 4
rid = v[first, c["requestId"][actor - 1]]
prior = np.flatnonzero((v[:first, c["status"][actor - 1]] == 1) &
                       (v[:first, c["feedbackId"][actor - 1]] == rid) &
                       (v[:first, c["kind"][actor - 1]] == v[first, c["kind"][actor - 1]]))
assert len(prior)
detail = []
for i in sorted(set([int(prior[0]), int(first - 1), int(first)])):
    row = {"row1": i + 1, "time": t[i, 60], "teamPhase": int(v[i, c["phase"][team]]),
           "globalChaser": int(chasers[i, team]), "localChaserTrace": int(t[i, 70 + team]),
           "role": int(t[i, 48 + actor - 1]), "kicker": int(v[i, c["kicker"]]),
           "actualKickTrace": int(t[i, 96]), "ballXYm": t[i, 56:58].tolist(),
           "ballVxyMps": t[i, 58:60].tolist(), "scores": t[i, 61:63].astype(int).tolist(),
           "ballSpeedMps": float(np.linalg.norm(t[i, 58:60]))}
    for key in ("intent", "rawKind", "kind", "skill", "status", "requestId", "feedbackId", "speed"):
        row[key] = float(v[i, c[key][actor - 1]])
    detail.append(row)
result = {
    "status": "PASS_READER_TEN_SECOND_HEADLESS", "seed": p["seed"], "dt": p["dt"],
    "tMatch": p["Tmatch"], "mat": str(mat_path), "matSha256": sha256(mat_path.read_bytes()),
    "traceShape": list(t.shape), "tacticsShape": list(v.shape),
    "traceNumericSha256": fingerprint(t), "tacticsNumericSha256": fingerprint(v),
    "numericEncoding": "row-major little-endian IEEE754 float64",
    "timeBoundsSeconds": [t[0, 60], t[-1, 60]], "fixedRolesEachRow": roles,
    "actualEventsCount": len(hits), "events": [[t[i, 60], int(v[i, c["kicker"]])] for i in hits],
    "exampleActorGlobal": actor, "exampleTimeline": detail,
}
print(json.dumps(result, indent=2, allow_nan=False))
