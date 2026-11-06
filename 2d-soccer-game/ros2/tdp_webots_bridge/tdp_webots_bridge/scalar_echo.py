"""Minimal scalar tutorial: each input x produces x + 1."""
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64


def main():
    rclpy.init()
    node = Node('tdp_scalar_echo')
    output = node.create_publisher(Float64, '/tdp/scalar_out', 10)
    node.create_subscription(Float64, '/tdp/scalar_in',
                             lambda msg: output.publish(Float64(data=msg.data + 1.0)), 10)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
