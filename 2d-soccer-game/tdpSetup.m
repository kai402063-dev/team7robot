function root = tdpSetup()
%TDPSETUP Configure only this MATLAB process; never save paths/preferences.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'algorithms'),fullfile(root,'baseline'), ...
    fullfile(root,'interfaces'),fullfile(root,'controllers'), ...
    fullfile(root,'environment'),fullfile(root,'scripts'),fullfile(root,'tests'),fullfile(root,'models'));
if ~isfolder(fullfile(root,'build')), mkdir(fullfile(root,'build')); end
cacheId=getenv('TDP_CACHE_ID');if isempty(cacheId),cacheId='main';end
assert(~isempty(regexp(cacheId,'^[A-Za-z0-9_-]+$','once')),'Invalid cache ID');
Simulink.fileGenControl('set','CacheFolder',fullfile(root,'build','cache',cacheId), ...
    'CodeGenFolder',fullfile(root,'build','codegen',cacheId),'createDir',true);
set(groot,'DefaultFigureVisible','off');
end
