# ROS 2 and Webots Development Guide

This guide covers the ROS 2 and Webots simulation environment for the Team 7 Robot Soccer project.

## Project Overview

The project currently includes a MATLAB/Simulink robot soccer starter simulation.

This section introduces a separate ROS 2 and Webots workflow for developing robot behaviours.

## Development Environment

- Ubuntu 24.04
- ROS 2 Jazzy
- Webots
- Python
- VS Code

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/kai402063-dev/team7robot.git
cd team7robot
```

### 2. Create a ROS 2 workspace

```bash
mkdir -p ros2_ws/src
cd ros2_ws/src
```

### 3. Create a ROS 2 Python package

```bash
ros2 pkg create nao6_behaviour_template \
  --build-type ament_python \
  --dependencies rclpy geometry_msgs
```

## Behaviour Development

The shared behaviour package will contain:

- Walking
- Turning
- Getting up
- Soccer behaviour

Each behaviour should be developed and tested independently before integration.

## Collaboration

- Develop features on separate Git branches.
- Test changes in Webots before integration.
- Document behaviour parameters and assumptions.
- Commit changes regularly.
- Merge tested changes into the main project.

## Current Status

ROS 2 and Webots environment setup is in progress.