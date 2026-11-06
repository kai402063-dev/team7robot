#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_matlab_prefs="${TDP_MATLAB_PREFDIR:-$PWD/build/matlab-prefs}"
mkdir -p "$task_matlab_prefs"
exec env -u LD_LIBRARY_PATH -u LD_PRELOAD -u DISPLAY -u MATLAB_JAVA \
  MATLAB_PREFDIR="$task_matlab_prefs" \
  /home/fayne/Applications/MATLAB/R2026b/bin/matlab -batch "$1"
