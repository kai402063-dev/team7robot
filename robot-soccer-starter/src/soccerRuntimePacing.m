function value = soccerRuntimePacing(setting)
%SOCCERRUNTIMEPACING Session-only soft wall-clock rate for the soccer example.
% soccerRuntimePacing(3) targets 3 simulation seconds per real second.
% soccerRuntimePacing(0) runs without either pacing mechanism.
% soccerRuntimePacing('status') reads configuration and statistics.
% soccerRuntimePacing('restore') restores the pre-enable built-in setting.
% Never saves an SLX or changes solver, strategy, dynamics, or graphics device.
key = 'SoccerRuntimePacingConfig';
statsKey = 'SoccerRuntimePacingStats';
generationKey = 'SoccerRuntimePacingGeneration';
if nargin==0,setting='status';end
if ischar(setting) || isstring(setting)
    action = char(setting);
    if strcmp(action,'status')
        value = struct('Enabled',false);
        if isappdata(groot,key),value=getappdata(groot,key);end
        if isappdata(groot,statsKey),value.Stats=getappdata(groot,statsKey);end
        return;
    elseif strcmp(action,'restore')
        value = struct('Enabled',false);
        if isappdata(groot,key)
            cfg = getappdata(groot,key);
            if bdIsLoaded(cfg.ModelName) && ...
                    strcmp(get_param(cfg.ModelName,'FileName'),cfg.ModelFile)
                set_param(cfg.ModelName,'EnablePacing',cfg.BuiltinBefore.Enabled, ...
                    'PacingRate',num2str(cfg.BuiltinBefore.Rate));
            end
            rmappdata(groot,key);
        end
        if isappdata(groot,statsKey),rmappdata(groot,statsKey);end
        return;
    else
        error('SoccerRuntimePacing:Action','Use a numeric rate, status, or restore.');
    end
end
validateattributes(setting,{'numeric'},{'scalar','real','finite','nonnegative'});
setting = double(setting);
model = 'multiRobotSoccer';
if ~bdIsLoaded(model)
    error('SoccerRuntimePacing:Model','Open the soccer model before enabling runtime pacing.');
end
% Use the soccer model bundled with this project.
repo = fileparts(fileparts(mfilename('fullpath')));
expected = fullfile(repo,'examples','soccer','multiRobotSoccer.slx');
actual = get_param(model,'FileName');
if ~strcmp(actual,expected)
    error('SoccerRuntimePacing:WrongCopy','Open the model from %s.',repo);
end
epoch = 1;
if isappdata(groot,generationKey)
    epoch = getappdata(groot,generationKey)+1;
end
before = struct('Enabled',get_param(model,'EnablePacing'), ...
    'Rate',get_param(model,'PacingRate'));
if isappdata(groot,key)
    old = getappdata(groot,key);
    if strcmp(old.ModelFile,actual),before=old.BuiltinBefore;end
end
cfg = struct('Enabled',setting>0,'ModelName',model,'ModelFile',actual, ...
    'Rate',setting,'Epoch',epoch,'BuiltinBefore',before);
set_param(model,'EnablePacing','off');
setappdata(groot,generationKey,epoch);
setappdata(groot,key,cfg);
if isappdata(groot,statsKey),rmappdata(groot,statsKey);end
value = cfg;
end
