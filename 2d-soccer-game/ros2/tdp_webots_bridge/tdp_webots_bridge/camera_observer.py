"""Capture the first real ROS image and graph evidence without decoding it."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image

def main():
    p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('--mode',default='closed');a=p.parse_args();out=Path(a.output)
    rclpy.init();node=Node('tdp_camera_evidence');images=[]
    node.create_subscription(Image,'/tdp/camera/top/image_raw',images.append,10)
    deadline=time.monotonic()+180
    while not images:
        rclpy.spin_once(node,timeout_sec=.1)
        if time.monotonic()>deadline:raise TimeoutError('No actual ROS camera message')
    msg=images[0];data=bytes(msg.data);(out/'camera-ros.bgra').write_bytes(data)
    info={'width':msg.width,'height':msg.height,'encoding':msg.encoding,'step':msg.step,
          'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
          'stamp':msg.header.stamp.sec+msg.header.stamp.nanosec/1e9,'clockPublishers':node.count_publishers('/clock')}
    (out/'camera-ros.json').write_text(json.dumps(info,indent=2)+'\n')
    (out/'observer-graph.json').write_text(json.dumps(node.get_topic_names_and_types(),indent=2)+'\n')
    topics=['/clock','/tdp/camera/top/image_raw']
    if a.mode=='closed':topics+=['/tdp/observation','/tdp/request']
    for topic in topics:
        for attempt in range(3):
            result=subprocess.run(['ros2','topic','info',topic,'--verbose','--no-daemon','--spin-time','3'],capture_output=True,text=True,timeout=20)
            (out/(topic.strip('/').replace('/','-')+f'-info-attempt-{attempt}.txt')).write_text(result.stdout+result.stderr)
            if result.returncode==0:break
        (out/(topic.strip('/').replace('/','-')+'-info.txt')).write_text(result.stdout+result.stderr)
        assert result.returncode==0,result.stderr
        if topic=='/clock':assert 'Publisher count: 1' in result.stdout
    (out/'graph-ready.json').write_text(json.dumps({'status':'PASS','clockPublishers':1})+'\n')
    node.destroy_node();rclpy.shutdown()

if __name__=='__main__':main()
