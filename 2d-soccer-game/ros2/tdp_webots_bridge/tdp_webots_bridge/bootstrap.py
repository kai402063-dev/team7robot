"""Wait for first-frame evidence without advancing simulation time."""
import time


def wait_for_graph_evidence(ready, spin, publish_clock, publish_camera, clock, image,
                            timeout=90.0, retry_interval=0.25, monotonic=time.monotonic):
    """Repeat the frozen first frame on wall time until its evidence is ready.

    Volatile DDS readers may miss the initial publication before discovery.
    The callbacks only publish the same objects or service ROS; they must not
    step physics or rewrite acquisition stamps. This is not a control clock.
    """
    if timeout<=0 or retry_interval<=0:
        raise ValueError('Bootstrap timeout and retry interval must be positive')
    next_publish=monotonic();deadline=next_publish+timeout;repeats=0
    while not ready():
        now=monotonic()
        if now>=deadline:
            raise TimeoutError('No ROS graph evidence receipt')
        if now>=next_publish:
            publish_clock(clock)
            publish_camera(image)
            repeats+=1;next_publish=now+retry_interval
        spin(min(0.05,deadline-now))
    return repeats
