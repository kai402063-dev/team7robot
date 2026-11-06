#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ROS_DOMAIN_ID="${TDP_ROS_DOMAIN:-97}"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export ROS_LOG_DIR="$PWD/build/ros-logs"
export ROS_HOME="$PWD/build/ros-home"
export PYTHONPATH="$PWD/ros2/tdp_webots_bridge:${PYTHONPATH:-}"
mkdir -p "$ROS_LOG_DIR" "$ROS_HOME"
set +u
source /opt/ros/jazzy/setup.bash
set -u
exec "$@"
