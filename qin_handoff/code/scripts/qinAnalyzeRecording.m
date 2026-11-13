function m=qinAnalyzeRecording(inputFile,outDir,options)
%QINANALYZERECORDING Read a saved trace; write portable offline evidence only.
assert(~isfolder(outDir),'Qin:ExistingOutput','Use a fresh output directory.');
if nargin<3,options=struct();end
d=load(inputFile,'trace','tactics','P');
assert(isfield(d,'trace')&&isfield(d,'P'),'Qin:Recording','Recording needs trace and P.');
if ~isfield(d,'tactics'),d.tactics=[];end
m=qinBehaviourMetrics(d.trace,d.tactics,d.P,options);
mkdir(outDir);writeJson(fullfile(outDir,'metrics.json'),m);
names=m.robotLabels;
T=array2table([(1:8)' m.robotSeconds],'VariableNames',[{'robot'} names]);
writetable(T,fullfile(outDir,'robot_seconds.csv'));
T=table(string(m.halfLabels(:)),m.halfSeconds(:),'VariableNames',{'category','seconds'});
writetable(T,fullfile(outDir,'half_seconds.csv'));
T=table(string(m.possessionLabels(:)),m.possessionSeconds(:),'VariableNames',{'category','seconds'});
writetable(T,fullfile(outDir,'possession_seconds.csv'));
T=table((1:2)',m.defendSeconds(:),m.defendNoChaserSeconds(:),m.defendNoChaserRatio(:), ...
    'VariableNames',{'team','defendSeconds','noChaserSeconds','ratio'});
writetable(T,fullfile(outDir,'defend_seconds.csv'));
T=array2table([(1:8)' m.chasingIncludingKickSeconds(:) m.stationarySeconds], ...
    'VariableNames',[{'robot','chasingIncludingKick'} m.stationaryLabels]);
writetable(T,fullfile(outDir,'handoff_robot_seconds.csv'));
provenance=struct('sourceFile',char(inputFile),'matlabVersion',version,'parameters',d.P, ...
    'analysisFunction','qinBehaviourMetrics','analysisOptions',options,'analysedAt',char(datetime('now','TimeZone','UTC')));
writeJson(fullfile(outDir,'provenance.json'),provenance);
end
