"""Audit the saved eight-robot model and its request/feedback delay paths."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
from xml.etree import ElementTree as ET
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]


def audit(output, recovery=False):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    model = ROOT / "models" / ("tdpRecoveryMatch.slx" if recovery else "tdpV1Match.slx")
    with ZipFile(model) as archive:
        system = ET.fromstring(archive.read("simulink/systems/system_root.xml"))
        config = json.loads(archive.read("simulink/configSet0.json"))
    blocks = {b.get("Name"): b for b in system.findall("Block")}
    ids = {b.get("SID"): name for name, b in blocks.items()}

    def port(value):
        sid, direction, index = re.fullmatch(r"(\d+)#(in|out):(\d+)", value).groups()
        return f"{ids[sid]}.{direction}{index}"

    wires = {}
    for line in system.findall("Line"):
        source = port(line.findtext("P[@Name='Src']"))
        for target in line.findall(".//P[@Name='Dst']"):
            dest = port(target.text)
            assert dest not in wires, f"Multiple sources for {dest}"
            wires[dest] = source
    cores = sorted(name for name, block in blocks.items()
                   if block.findtext("P[@Name='SourceBlock']") == "ControllerCore/Core")
    assert cores == [f"Robot{i}" for i in range(1, 9)]
    delays = sorted(name for name, block in blocks.items() if block.get("BlockType") == "UnitDelay")
    expected_delays = ["RequestMemory", "FeedbackMemory", "WorldMemory", "Team1Memory", "Team2Memory"]
    if recovery:
        expected_delays.extend(["HealthMemory", "DeviceHealthMemory"])
    assert delays == sorted(expected_delays)
    expected = {
        "Plant2D.in2": "AuthorizeRequests.out1", "RequestMemory.in1": "AuthorizeRequests.out1",
        "FeedbackMemory.in1": "Plant2D.out2", "WorldMemory.in1": "Plant2D.out1",
        "AuthorizeRequests.in1": "JoinRequests.out1", "TacticsRecords.in1": "TacticsRecord.out1",
        "Records.in1": "Record.out1",
    }
    for team in ("Team1", "Team2"):
        expected.update({f"{team}Memory.in1": f"{team}.out2", f"{team}.in2": f"{team}Memory.out1",
                         f"{team}.in3": "RequestMemory.out1", f"{team}.in4": "FeedbackMemory.out1"})
    if recovery:
        expected.update({
            "Team1.in5": "HealthMemory.out1", "Team2.in5": "HealthMemory.out1",
            "HealthMemory.in1": "RecoveryFeedback.out1", "FeedbackMemory.in1": "RecoveryFeedback.out2",
            "DeviceHealthMemory.in1": "Plant2D.out4", "Plant2D.in5": "DeviceHealthMemory.out1",
            "RecoveryFeedback.in1": "Plant2D.out4", "RecoveryFeedback.in2": "Plant2D.out2",
            "RecoveryFeedback.in3": "HealthMemory.out1", "RecoveryFeedback.in4": "FeedbackMemory.out1",
            "RecoveryRecord.in2": "RecoveryFeedback.out1", "RecoveryRecords.in1": "RecoveryRecord.out1",
        })
    for target, source in expected.items():
        assert wires[target] == source, f"{target} received {wires[target]}, expected {source}"

    def settings(obj):
        if isinstance(obj, dict):
            yield from obj.get("_properties", {}).items()
            for v in obj.values():
                yield from settings(v)
        elif isinstance(obj, list):
            for v in obj:
                yield from settings(v)

    parameters = {key: str(value) for key, value in settings(config)
                  if key in ("AlgebraicLoopMsg", "FixedStep", "SolverName")}
    assert parameters == {"AlgebraicLoopMsg": "error", "FixedStep": "P.dt", "SolverName": "FixedStepDiscrete"}
    result = {"status": "PASS", "modelSha256": sha256(model.read_bytes()).hexdigest(),
              "cores": cores, "unitDelays": delays, "configuration": parameters, "verifiedWires": expected}
    (output / "receipt.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--recovery", action="store_true")
    args = parser.parse_args()
    audit(args.output, args.recovery)
