"""Single NAO V5 bridge. Supervisor reads truth; motors alone actuate the world."""
import hashlib
import json
import math
import os
from pathlib import Path
import time
import rclpy
from rclpy.node import Node
from std_msgs.msg import Float64MultiArray
from sensor_msgs.msg import Image
from rosgraph_msgs.msg import Clock
from controller import Supervisor,Motion
from .motion_executor import MotionExecutor
from .bootstrap import wait_for_graph_evidence


def main():
    root=Path(os.environ['TDP_PROJECT_ROOT'])
    out=Path(os.environ['TDP_WEBOTS_OUTPUT'])
    config=json.loads((root/'config/webots.json').read_text())
    mode=os.environ.get('TDP_WEBOTS_MODE','closed');probe=mode!='closed'
    robot=Supervisor();step=int(robot.getBasicTimeStep());assert step==20
    ball=robot.getFromDef('TDP_BALL');self_node=robot.getSelf()
    camera=robot.getDevice('CameraTop');camera.enable(40)
    motions={name:Motion(str(root/'webots/motions'/f'{name}.motion')) for name in
             ['Forwards','Backwards','SideStepLeft','SideStepRight','TurnLeft40','TurnRight40','Shoot']}
    executor=MotionExecutor(motions,config['walkSelectionReference'])
    # Set motor targets to the first prerecorded pose before settling.
    rows=(root/'webots/motions/Shoot.motion').read_text().splitlines()
    for name,value in zip(rows[0].split(',')[2:],rows[1].split(',')[2:]):
        robot.getDevice(name).setPosition(float(value))
    rclpy.init();node=Node('tdp_webots_bridge')
    pub_clock=node.create_publisher(Clock,'/clock',10)
    pub_obs=node.create_publisher(Float64MultiArray,'/tdp/observation',10)
    pub_camera=node.create_publisher(Image,'/tdp/camera/top/image_raw',10)
    requests=[]
    node.create_subscription(Float64MultiArray,'/tdp/request',lambda msg:requests.append(list(msg.data)),10)
    records=[];camera_info=None;sequence=0;first_end=None;duplicates=0;publisher_counts=[]
    total=config['controlFrames'] if not probe else (201 if mode=='motion' else 101)
    wall_start=time.monotonic()
    status='RUNNING';error=None;motion_action=None;bootstrap_republishes=None
    try:
        # Let the proxy and an evidence observer discover the robot before time advances.
        if not probe:
            deadline=time.monotonic()+180
            while pub_obs.get_subscription_count()<1:
                rclpy.spin_once(node,timeout_sec=.1)
                if time.monotonic()>deadline:raise TimeoutError('No observation subscriber')
        while robot.step(step)!=-1:
            now=robot.getTime();ns=round(now*1e9)
            clock=Clock();clock.clock.sec,clock.clock.nanosec=divmod(ns,1_000_000_000);pub_clock.publish(clock)
            position=self_node.getPosition();orientation=self_node.getOrientation();bp=ball.getPosition();bv=ball.getVelocity()
            upright=position[2]>config['uprightMinimumZMetres'] and orientation[8]>config['uprightMinimumUpZ']
            executor.tick(now,bp[:2],upright)
            if now<config['settleSeconds'] or round(now*1000)%40!=0:continue
            sequence+=1
            yaw=math.atan2(orientation[3],orientation[0])
            ended=[e for e in executor.events if e['event']=='motion_end']
            if ended and first_end is None:first_end=now
            playing=first_end is None
            frame=[1,now,now,position[0],position[1],yaw,float(upright),bp[0],bp[1],bv[0],bv[1],1,now,
                   float(playing),float(executor.feedback[0]),float(executor.feedback[1]),executor.feedback[2],position[2],bp[2],sequence]
            pixels=camera.getImage();width=camera.getWidth();height=camera.getHeight()
            if pixels is None or len(pixels)!=width*height*4:raise RuntimeError('Invalid camera buffer')
            image=Image();image.header.stamp=clock.clock;image.header.frame_id='CameraTop';image.width=width;image.height=height
            image.encoding='bgra8';image.is_bigendian=0;image.step=width*4;image.data=bytes(pixels);pub_camera.publish(image)
            if camera_info is None:
                raw=bytes(pixels);(out/'camera.bgra').write_bytes(raw)
                camera_info={'width':width,'height':height,'encoding':'bgra8','step':image.step,'bytes':len(raw),
                             'stamp':now,'sha256':hashlib.sha256(raw).hexdigest(),'source':'actual Webots CameraTop buffer'}
                (out/'camera.json').write_text(json.dumps(camera_info,indent=2)+'\n')
            if sequence==1:
                # Retry frozen first-frame transport without another robot.step.
                bootstrap_republishes=wait_for_graph_evidence(
                    lambda:(out/'graph-ready.json').is_file(),
                    lambda delay:rclpy.spin_once(node,timeout_sec=delay),
                    pub_clock.publish,pub_camera.publish,clock,image,
                    timeout=config['graphBootstrapTimeoutSeconds'],
                    retry_interval=config['graphBootstrapRepublishSeconds'])
            publisher_counts.append(node.count_publishers('/clock'))
            if probe:
                action=None
                if mode=='motion':
                    if motion_action is None:motion_action=[2,1,4,0,0,0,4.5,0,1.8,now,now+config['kickTimeoutSeconds']]
                    action=motion_action
                    executor.receive(action,now);duplicates+=int(sequence>1)
            else:
                pub_obs.publish(Float64MultiArray(data=[float(v) for v in frame]))
                deadline=time.monotonic()+90
                while not requests:
                    rclpy.spin_once(node,timeout_sec=.02)
                    if time.monotonic()>deadline:raise TimeoutError('No controller action')
                action=requests.pop(0)
                executor.receive(action,now)
                if action[0]==2:
                    # Inject the identical real request twice at the physical executor boundary.
                    executor.receive(action,now);duplicates+=1
            records.append({'time':now,'robot':position,'yaw':yaw,'ball':bp,'ballVelocity':bv[:3],
                            'upright':upright,'action':action,'feedback':list(executor.feedback),
                            'executions':executor.executions,'clockPublishers':publisher_counts[-1]})
            if sequence%100==0:print(f'TDP_WEBOTS frame={sequence} t={now:.2f} executions={executor.executions} upright={upright}',flush=True)
            if sequence>=total:break
        status=('MOTION_RUN_COMPLETE' if mode=='motion' else 'PASS_CAMERA_PROBE') if probe else 'RUN_COMPLETE'
    except Exception as exc:
        status='FAIL';error=repr(exc)
        raise
    finally:
        (out/'webots-records.json').write_text(json.dumps(records,indent=2)+'\n')
        starts=[e for e in executor.events if e['event']=='motion_start'];ends=[e for e in executor.events if e['event']=='motion_end']
        kick_results=[]
        for start in starts:
            end=next((e for e in ends if e['requestId']==start['requestId']),None)
            displacement=math.dist(start['ball'],end['ball']) if end else None
            kick_results.append({'requestId':start['requestId'],'motionEnded':end is not None,
                                 'ballDisplacementAtMotionEnd':displacement,
                                 'ballMoved':displacement is not None and displacement>config['ballDisplacementThresholdMetres']})
        receipt={'status':status,'error':error,'frames':len(records),'elapsedWallSeconds':time.monotonic()-wall_start,
                 'events':executor.events,'kickResults':kick_results,'executions':executor.executions,
                 'duplicateDeliveries':duplicates,'camera':camera_info,'clockPublisherCounts':sorted(set(publisher_counts)),
                 'bootstrapRepublishes':bootstrap_republishes,
                 'localization':config['localization'],'robotModel':config['robotModel'],
                 'modelValidation':'NOT_ESTABLISHED: V5 simulation with uncalibrated teaching parameters'}
        (out/'webots-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        node.destroy_node();rclpy.shutdown();robot.simulationQuit(0 if error is None else 1)


if __name__=='__main__':main()
