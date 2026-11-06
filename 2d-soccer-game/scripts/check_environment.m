function report = check_environment(outDir)
%CHECK_ENVIRONMENT Inspect installed products separately from licenses.
report=struct('matlab',version,'release',version('-release'),'root',matlabroot, ...
 'products',ver,'installAllowed',false,'pushAllowed',false);
features={'MATLAB','Simulink','Stateflow','ROS_Toolbox','Real-Time_Workshop','MATLAB_Coder'};
for i=1:numel(features)
 report.licenses.(matlab.lang.makeValidName(features{i}))=license('test',features{i});
end
report.ros2=which('ros2node');report.screener=which('coder.screener');
report.rosOnline='BLOCKED_ROS_TOOLBOX_NOT_INSTALLED';
report.standalone='BLOCKED_CODERS_NOT_INSTALLED';
writeJson(fullfile(outDir,'environment.json'),report);disp(report);
end
