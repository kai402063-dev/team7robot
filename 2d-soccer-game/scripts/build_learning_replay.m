function file=build_learning_replay(name,outFolder)
%BUILD_LEARNING_REPLAY Build a replay harness with a locally editable core.
root=tdpSetup();if nargin<1,name='tdpLearningReplay';end
if nargin<2,outFolder=fullfile(root,'models');end
assert(isvarname(name),'TDP:LearningName','Use a valid model identifier');
file=fullfile(outFolder,[name '.slx']);
if ~strcmp(outFolder,fullfile(root,'models'))
 assert(~isfile(file),'TDP:ExistingLearningModel','Choose a new name to preserve your hand-built chart');
end
build_replay(name,outFolder);load_system(file);
set_param([name '/ControllerCore'],'LinkStatus','none');save_system(name,file);close_system(name,0);
end
