% Run from project root in a fresh MATLAB process with a private display.
set(groot,'DefaultFigureVisible','on');
before=char(get(groot,'DefaultFigureVisible'));
assert(isempty(which('tdp.recoveryConfig')),'Unexpected path initialization before the editor entry');
app=start_2d_recovery;
after=char(get(groot,'DefaultFigureVisible'));
assert(strcmp(before,after),'The editor entry changed figure visibility');
if ~isempty(app.LastError),rethrow(app.LastError);end
r=jsondecode(fileread(fullfile(app.RunDirectory,'receipt.json')));
data=load(fullfile(app.RunDirectory,'trace.mat'),'trace','tactics','recovery');
assert(app.Parameters.v1AutoRecovery && r.parameters.v1AutoRecovery && strcmp(r.status,'COMPLETED'));
assert(isequal(size(data.trace),[100 98]) && isequal(size(data.tactics),[100 171]));
assert(isequal(size(data.recovery),[100 53]) && isequal(data.recovery(:,1),data.trace(:,61)));
assert(all(isfinite(data.recovery),'all') && any(data.tactics(:,15)~=0));
assert(isgraphics(app.Figure) && strcmp(app.Figure.Visible,'on'));
close(app.Figure);drawnow;
assert(~isgraphics(app.Figure));
writeJson('evidence/recovery-v1/editor-window-01/matlab-checks.json',struct( ...
    'status','PASS','entry','start_2d_recovery','defaultFigureVisibleBefore',before, ...
    'defaultFigureVisibleAfter',after,'visibleFigureClosed',true, ...
    'inheritedEnvironmentStrategy',getenv('TDP_2D_STRATEGY'), ...
    'v1AutoRecovery',logical(r.parameters.v1AutoRecovery),'actuatedKickCount',sum(data.tactics(:,15)~=0), ...
    'traceShape',size(data.trace),'tacticsShape',size(data.tactics), ...
    'recoveryShape',size(data.recovery),'recoverySimTimeEqualsTrace',true, ...
    'matchReceipt',fullfile(app.RunDirectory,'receipt.json')));
