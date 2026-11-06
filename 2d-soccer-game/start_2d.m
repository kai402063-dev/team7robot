function app=start_2d(P,speed)
%START_2D Open and immediately run the live 4v4 simulation.
% Use the Run button in this file, or type start_2d in MATLAB.
visibility=get(groot,'DefaultFigureVisible');restore=onCleanup(@()set(groot,'DefaultFigureVisible',visibility));
tdpSetup;
experimentalEntry=nargin>=1 && isequal(P,'recovery');
if nargin<1 || experimentalEntry
 if experimentalEntry || strcmp(getenv('TDP_2D_STRATEGY'),'recovery')
     P=tdp.recoveryConfig();
 else
     P=tdp.v1Config();
 end
 duration=getenv('TDP_2D_DURATION');
 if ~isempty(duration),P.Tmatch=str2double(duration);end
end
if nargin<2
 speed=1;value=getenv('TDP_2D_SPEED');
 if ~isempty(value),speed=str2double(value);end
end
tdp.validateConfig(P);
app=LiveViewer2D(P,'on',speed);
clear restore
drawnow;app.start();
end
