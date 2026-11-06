#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
pdftoppm -f 3 -l 3 -scale-to 1200 -singlefile -png \
  'reference/course/ENG5325 Robotics TDP M -Spec Doc 2026 2027.pdf' docs/generated/course_pitch
