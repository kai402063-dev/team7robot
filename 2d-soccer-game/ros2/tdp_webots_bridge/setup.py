from setuptools import setup
setup(name='tdp_webots_bridge', version='0.1.0', packages=['tdp_webots_bridge'],
      data_files=[('share/ament_index/resource_index/packages', ['resource/tdp_webots_bridge']),
                  ('share/tdp_webots_bridge', ['package.xml'])],
      install_requires=['setuptools'], zip_safe=True,
      maintainer='TDP team', maintainer_email='tdp@example.invalid',
      description='Standard ROS messages and Webots V5 motion adapter', license='MIT',
      entry_points={'console_scripts': [
          'tdp_ros_proxy = tdp_webots_bridge.proxy:main',
          'tdp_scalar_echo = tdp_webots_bridge.scalar_echo:main',
          'tdp_replay_driver = tdp_webots_bridge.replay_driver:main']})
