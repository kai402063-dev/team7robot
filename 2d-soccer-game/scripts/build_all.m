function build_all()
%BUILD_ALL Recreate every new SLX from a blank model.
tdpSetup;build_controller;build_replay;build_single;build_match;build_v1_match;build_recovery_match;build_lessons;build_learning_replay;build_ros_adapter;
end
