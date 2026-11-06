"""Unit checks complement, but do not replace, a physical Webots run."""
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'ros2/tdp_webots_bridge'),str(ROOT/'scripts')]
from tdp_webots_bridge.motion_executor import MotionExecutor,Status
from tdp_webots_bridge.bootstrap import wait_for_graph_evidence
from check_pitch import dimensions

class Motion:
    def __init__(self):self.plays=0;self.over=False;self.stops=0
    def setLoop(self,value):pass
    def setTime(self,value):self.over=False
    def play(self):self.plays+=1
    def stop(self):self.stops+=1
    def isOver(self):return self.over

def request(kind=2,rid=1,now=0,expiry=12):
    return [kind,rid,4,.1,0,0,4.5,0,1.8,now,expiry]

class VolatileDiscovery:
    """Deterministic transport: unmatched or deliberately lost samples disappear."""
    def __init__(self,subscriber_at=0.0,lost_matched_images=0):
        self.wall=0.0;self.subscriber_at=subscriber_at;self.lost=lost_matched_images
        self.received=False;self.clock_messages=[];self.images=[];self.delivered=[];self.image_wall_times=[]
    def monotonic(self):return self.wall
    def spin(self,delay):self.wall+=delay
    def publish_clock(self,message):self.clock_messages.append(message)
    def publish_camera(self,message):
        self.images.append(message);self.image_wall_times.append(self.wall)
        if self.wall<self.subscriber_at:return
        if self.lost:self.lost-=1;return
        self.received=True;self.delivered.append(message)

class BootstrapTests(unittest.TestCase):
    def bootstrap(self,transport):
        config=json.loads((ROOT/'config/webots.json').read_text())
        interval=config['graphBootstrapRepublishSeconds']
        clock={'sec':2,'nanosec':0};image={'stamp':clock.copy(),'data':b'fixed first image'}
        transport.publish_clock(clock);transport.publish_camera(image)
        completed=False;repeats=None
        try:
            repeats=wait_for_graph_evidence(lambda:transport.received,transport.spin,
                transport.publish_clock,transport.publish_camera,clock,image,
                timeout=1.0,retry_interval=interval,monotonic=transport.monotonic)
            completed=True
        except TimeoutError:
            pass
        self.assertTrue(completed,'The graph handshake must recover from a lost volatile first image')
        self.assertGreater(repeats,0)
        self.assertTrue(all(message is clock for message in transport.clock_messages))
        self.assertTrue(all(message is image for message in transport.images))
        self.assertEqual(clock,{'sec':2,'nanosec':0})
        self.assertEqual(image,{'stamp':{'sec':2,'nanosec':0},'data':b'fixed first image'})
        retry_times=transport.image_wall_times[1:]
        self.assertTrue(all(b-a>=interval-1e-12 for a,b in zip(retry_times,retry_times[1:])))
        self.assertLess(transport.wall,1.0)
    def test_bootstrap_delayed_discovery(self):
        self.bootstrap(VolatileDiscovery(subscriber_at=0.12))
    def test_bootstrap_lost_first_images(self):
        self.bootstrap(VolatileDiscovery(lost_matched_images=3))
    def test_bootstrap_timeout_is_bounded(self):
        transport=VolatileDiscovery(subscriber_at=10.0)
        with self.assertRaisesRegex(TimeoutError,'No ROS graph evidence receipt'):
            wait_for_graph_evidence(lambda:False,transport.spin,transport.publish_clock,
                transport.publish_camera,object(),object(),timeout=0.2,monotonic=transport.monotonic)
        self.assertGreaterEqual(transport.wall,0.2)
        self.assertLessEqual(transport.wall,0.25)
    def test_bootstrap_ready_does_not_publish(self):
        transport=VolatileDiscovery()
        repeats=wait_for_graph_evidence(lambda:True,transport.spin,transport.publish_clock,
            transport.publish_camera,object(),object(),monotonic=transport.monotonic)
        self.assertEqual(repeats,0);self.assertEqual(transport.wall,0.0)
        self.assertEqual(transport.images,[]);self.assertEqual(transport.clock_messages,[])

class WebotsTests(unittest.TestCase):
    def executor(self):return MotionExecutor({k:Motion() for k in ['Shoot','Forwards','Backwards','SideStepLeft','SideStepRight','TurnLeft40','TurnRight40']})
    def test_duplicate_and_ball_independent_completion(self):
        e=self.executor();r=request();e.receive(r,0);e.tick(0,[0,0])
        for k in range(10):e.receive(r,.04*k);e.tick(.04*k,[0,0])
        self.assertEqual(e.executions,1);self.assertEqual(e.motions['Shoot'].plays,1)
        e.current.over=True;e.tick(4.8,[0,0]);self.assertEqual(e.feedback[1],Status.DONE)
        e.receive(r,5);e.tick(5,[0,0]);self.assertEqual(e.executions,1)
        self.assertEqual(e.events[-1]['ball'],[0,0])
    def test_expiry_and_late(self):
        e=self.executor();e.receive(request(1,4,0,.1),0);e.tick(0,[0,0]);self.assertEqual(e.current_name,'Forwards')
        e.tick(.12,[0,0]);self.assertIsNone(e.current)
        e.receive(request(2,3,0,12),.12);self.assertEqual(e.feedback[1],Status.REJECTED);self.assertEqual(e.executions,0)
        e.receive(request(2,5,0,.1),.12);self.assertEqual(e.feedback[1],Status.REJECTED)
    def test_queue_failure_and_cancel(self):
        e=self.executor();e.receive(request(1,1),0);e.tick(0,[0,0]);e.receive(request(2,2),.04)
        e.tick(.04,[0,0]);self.assertEqual(e.executions,0)
        e.current.over=True;e.tick(2.6,[0,0]);self.assertEqual(e.executions,1)
        e.tick(3,[0,0],False);self.assertEqual(e.feedback,[2,Status.FAILED,3])
        e.receive(request(2,3,3),3);e.tick(3,[0,0]);e.receive(request(0,4,3.1),3.1)
        self.assertEqual(e.feedback[1],Status.FAILED);self.assertIsNone(e.current)
    def test_group_dimensions(self):
        a=dimensions(ROOT/'reference/kidsize_pitch.wbt');b=dimensions(ROOT/'webots/worlds/tdp_single.wbt')
        self.assertIsNone(a['basicTimeStepMs']);self.assertEqual(b['basicTimeStepMs'],20)
        self.assertEqual(a['pitchLength'],9);self.assertEqual(a['pitchWidth'],6)
    def test_motion_source_durations(self):
        source=json.loads((ROOT/'webots/motions/SOURCES.json').read_text())
        shoot=next(m for m in source if m['name']=='Shoot.motion');self.assertEqual(shoot['durationSeconds'],4.8)
        c=json.loads((ROOT/'config/webots.json').read_text());self.assertGreater(c['kickTimeoutSeconds'],7.4)

if __name__=='__main__':unittest.main()
