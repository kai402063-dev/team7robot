#!/usr/bin/env bash
# Launch a separate, task-local MATLAB session with the live 2D pitch.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./start_2d.sh [--recovery | --help]

Open the live 2D football animation in a new MATLAB process.
Use --recovery to select the experimental striker handback policy.
Close the pitch window to stop the simulation and exit that process.

Optional environment variables:
  MATLAB_BIN       MATLAB executable (default: local MATLAB R2026b)
  TDP_2D_DURATION  Simulated match duration in seconds (default: 600)
  TDP_2D_SPEED     Initial wall-clock speed factor (default: 1)

The MATLAB entry point validates duration and speed. Values are passed as
environment data, never inserted into executable MATLAB or shell code.
Run this command from a graphical desktop with an accessible DISPLAY.
Preferences, generated caches and the launch log remain under build/.
EOF
}

task_strategy=v1
if [[ $# -eq 1 && $1 == --recovery ]]; then
  task_strategy=recovery
elif [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
    usage
    exit 0
  fi
  printf 'Unknown arguments. Use --help for usage.\n' >&2
  exit 2
fi

task_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd -- "$task_root"

if [[ -z ${DISPLAY:-} ]]; then
  printf 'No DISPLAY is available. Run start_2d.sh from the graphical desktop.\n' >&2
  printf 'For a MATLAB session already open on that desktop, run start_2d instead.\n' >&2
  exit 2
fi

# Probe X11 before MATLAB can silently fall back to a hidden display.
if command -v xdpyinfo >/dev/null 2>&1; then
  if ! env -u LD_LIBRARY_PATH -u LD_PRELOAD timeout 8 xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    printf 'Cannot connect to DISPLAY=%s. Check the graphical session and X11 access.\n' "$DISPLAY" >&2
    exit 2
  fi
elif command -v xset >/dev/null 2>&1; then
  if ! env -u LD_LIBRARY_PATH -u LD_PRELOAD timeout 8 xset -display "$DISPLAY" q >/dev/null 2>&1; then
    printf 'Cannot connect to DISPLAY=%s. Check the graphical session and X11 access.\n' "$DISPLAY" >&2
    exit 2
  fi
else
  printf 'Cannot verify graphical display access: xdpyinfo or xset is required.\n' >&2
  exit 2
fi

task_matlab_bin=${MATLAB_BIN:-/home/fayne/Applications/MATLAB/R2026b/bin/matlab}
if [[ $task_matlab_bin != */* ]]; then
  task_matlab_bin=$(command -v -- "$task_matlab_bin" || true)
fi
if [[ -z $task_matlab_bin || ! -x $task_matlab_bin ]]; then
  printf 'MATLAB executable is unavailable. Set MATLAB_BIN to its executable path.\n' >&2
  exit 2
fi

task_cache_id="animation_$(date -u +%Y%m%dT%H%M%S)_$$"
task_session_dir="$task_root/build/animation-launcher/$task_cache_id"
task_preferences="$task_session_dir/preferences"
mkdir -p -- "$task_preferences"
printf 'Starting live 2D football. First compilation can take a moment.\n'
printf 'Launch log: %s\n' "$task_session_dir/matlab.log"

task_matlab_code="app=start_2d; if isgraphics(app.Figure),waitfor(app.Figure);end; if isprop(app,'LastError') && ~isempty(app.LastError),rethrow(app.LastError);end"
exec env -u LD_LIBRARY_PATH -u LD_PRELOAD -u MATLAB_JAVA \
  MATLAB_PREFDIR="$task_preferences" TDP_MATLAB_PREFDIR="$task_preferences" \
  TDP_CACHE_ID="$task_cache_id" TDP_2D_STRATEGY="$task_strategy" \
  "$task_matlab_bin" -logfile "$task_session_dir/matlab.log" -batch "$task_matlab_code"
