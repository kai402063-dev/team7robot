#!/usr/bin/env bash
set -euo pipefail
d=evidence/tactics-v1/release-matrix-01
old=../../evidence/tactics-v1/matrix-final-01
prior=../../evidence/tactics-v1/prebuilt-rebuild-01
command_dir=build/release-command-01
mkdir "$d/command"
cp "$command_dir"/{compare.py,launch.py,finish.sh} "$d/command/"
for period in 40 50; do
  mkdir "$d/command/$period"
  cp "$command_dir/$period"/{command.json,matlab.log} "$d/command/$period/"
done
python3 scripts/v1_matrix_evidence.py summarize "$d/summary" "$d/matches-50ms" "$d/matches-40ms"
python3 "$command_dir/compare.py" "$d" "$old" "$prior" "$command_dir" "$d/receipt.json"
python3 scripts/collect_evidence.py "$d" "../../$d"
