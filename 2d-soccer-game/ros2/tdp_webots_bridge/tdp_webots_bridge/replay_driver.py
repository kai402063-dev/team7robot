"""Publish an immutable recording and its synthetic simulation clock."""
import argparse
import json
import subprocess
import time
from pathlib import Path
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64MultiArray, Float64
from rosgraph_msgs.msg import Clock


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--frames', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()
    out = Path(args.output)
    frames = json.loads(Path(args.frames).read_text())
    rclpy.init()
    node = Node('tdp_replay_source')
    obs = node.create_publisher(Float64MultiArray, '/tdp/observation', 10)
    clock = node.create_publisher(Clock, '/clock', 10)
    replies, ages = [], []
    node.create_subscription(Float64MultiArray, '/tdp/request', lambda msg: replies.append(list(msg.data)), 10)
    node.create_subscription(Float64, '/tdp/diagnostics/action_age', lambda msg: ages.append(msg.data), 10)
    deadline = time.monotonic() + 180
    while obs.get_subscription_count() < 1 or node.count_publishers('/tdp/request') < 1:
        rclpy.spin_once(node, timeout_sec=0.1)
        if time.monotonic() > deadline:
            raise TimeoutError('Proxy discovery failed')
    for topic in ['/clock', '/tdp/observation', '/tdp/request', '/tdp/diagnostics/action_age']:
        for attempt in range(3):
            result = subprocess.run(['ros2', 'topic', 'info', topic, '--verbose', '--no-daemon', '--spin-time', '3'], text=True, capture_output=True, timeout=20)
            (out / (topic.strip('/').replace('/', '-') + f'-info-attempt-{attempt}.txt')).write_text(result.stdout + result.stderr)
            if result.returncode == 0:break
        (out / (topic.strip('/').replace('/', '-') + '-info.txt')).write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError('ros2 topic info failed')
    result = subprocess.run(['ros2', 'topic', 'list', '--no-daemon'], text=True, capture_output=True, timeout=20)
    (out / 'topic-list.txt').write_text(result.stdout + result.stderr)
    assert node.count_publishers('/clock') == 1
    for index, frame in enumerate(frames):
        ns = round(frame[1] * 1_000_000_000)
        msg = Clock();msg.clock.sec, msg.clock.nanosec = divmod(ns, 1_000_000_000)
        clock.publish(msg)
        obs.publish(Float64MultiArray(data=[float(x) for x in frame]))
        deadline = time.monotonic() + 30
        while len(replies) <= index or len(ages) <= index:
            rclpy.spin_once(node, timeout_sec=0.05)
            if time.monotonic() > deadline:
                raise TimeoutError(f'Missing action/diagnostic for frame {index}')
    (out / 'ros-actions.json').write_text(json.dumps(replies, indent=2) + '\n')
    (out / 'action-age.json').write_text(json.dumps(ages) + '\n')
    assert ages == [f[1] - f[2] for f in frames]
    node.destroy_node();rclpy.shutdown()


if __name__ == '__main__':
    main()
