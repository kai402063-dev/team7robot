"""Webots entry point; ROS package owns the implementation."""
from pathlib import Path
import os
import sys
root=Path(__file__).resolve().parents[3]
os.environ['TDP_PROJECT_ROOT']=str(root)
sys.path.insert(0,str(root/'ros2/tdp_webots_bridge'))
from tdp_webots_bridge.webots_controller import main
main()
