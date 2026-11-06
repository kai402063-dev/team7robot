"""Forward atomic ROS observations into the unchanged Simulink Core wrapper."""
import argparse
import json
import math
import socket
import time
from collections import deque
from pathlib import Path
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64MultiArray, Float64
from rosgraph_msgs.msg import Clock


def valid_frame(values):
    return len(values) == 20 and all(math.isfinite(v) for v in values)


class Proxy(Node):
    def __init__(self, stream):
        super().__init__('tdp_matlab_proxy')
        self.stream = stream
        self.clock_ns = -1
        self.pending = deque()
        self.records = []
        self.create_subscription(Clock, '/clock', self.clock, 10)
        self.create_subscription(Float64MultiArray, '/tdp/observation', self.observation, 10)
        self.publisher = self.create_publisher(Float64MultiArray, '/tdp/request', 10)
        self.age = self.create_publisher(Float64, '/tdp/diagnostics/action_age', 10)

    def clock(self, msg):
        now = msg.clock.sec * 1_000_000_000 + msg.clock.nanosec
        if now < self.clock_ns:
            raise RuntimeError('Clock rewind requires a new controller session')
        self.clock_ns = now

    def observation(self, msg):
        values = list(msg.data)
        if not valid_frame(values):
            raise ValueError('Expected 20 finite doubles')
        self.pending.append(values)

    def exchange(self):
        if not self.pending:
            return False
        frame = self.pending[0]
        expected = round(frame[1] * 1_000_000_000)
        if self.clock_ns < expected:
            return False
        if self.clock_ns != expected:
            raise RuntimeError('Observation and /clock are not synchronized')
        self.pending.popleft()
        self.stream.write((json.dumps(frame, allow_nan=False) + '\n').encode())
        self.stream.flush()
        line = self.stream.readline()
        if not line:
            raise EOFError('MATLAB transport closed')
        action = json.loads(line)
        if len(action) != 11 or not all(math.isfinite(x) for x in action):
            raise ValueError('Expected 11 finite action values')
        self.publisher.publish(Float64MultiArray(data=[float(x) for x in action]))
        self.age.publish(Float64(data=float(frame[1] - frame[2])))
        self.records.append({'frame': frame, 'action': action, 'clock_ns': self.clock_ns})
        return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--port', type=int, default=29741)
    p.add_argument('--count', type=int, required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()
    deadline = time.monotonic() + 180
    while True:
        try:
            connection = socket.create_connection(('127.0.0.1', args.port), timeout=2)
            break
        except OSError:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.2)
    connection.settimeout(120)
    rclpy.init()
    node = Proxy(connection.makefile('rwb'))
    try:
        while len(node.records) < args.count:
            rclpy.spin_once(node, timeout_sec=0.05)
            node.exchange()
        Path(args.output).write_text(json.dumps(node.records, indent=2) + '\n')
    finally:
        node.destroy_node()
        rclpy.shutdown()
        connection.close()


if __name__ == '__main__':
    main()
